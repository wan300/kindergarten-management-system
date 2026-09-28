require "base64"
require "fileutils"
require "json"
require "open3"
require "tempfile"
require "tmpdir"
require "timeout"

class GrowthRecordAnalysis
  class Error < StandardError; end

  MAX_VIDEO_FRAMES = 3
  MAX_MEDIA_PARTS = 8
  MAX_DIRECT_IMAGE_BYTES = 6.megabytes
  MAX_FRAME_WIDTH = 1280
  FFMPEG_TIMEOUT = 45

  SYSTEM_PROMPT = <<~PROMPT.squish.freeze
    你是幼儿园儿童成长观察分析助手。请只根据用户提供的文字、照片和视频画面中明确可见或明确描述的内容进行分析。
    重点关注儿童的具体行为、作品、互动、情绪表达、身体状态和活动参与情况。不得根据外貌、环境或单一模糊画面臆测年龄、疾病、心理状态、家庭情况或意图。
    如果材料中没有足够清晰、与儿童成长有关的有效信息，必须返回 has_effective_content=false，positive_observations=[]，watch_observations=[]，并明确说明未识别到足够内容，不能为了填满字段而猜测。
    需关注线索只是观察提醒，不是医疗、心理或教育诊断；遇到持续或明显异常时，请建议家长和老师继续观察并咨询专业人士。
  PROMPT

  OUTPUT_PROMPT = <<~PROMPT.squish.freeze
    请只输出严格 JSON，不要 Markdown、解释或代码围栏，字段必须完整：
    {
      "has_effective_content": true,
      "positive_observations": ["明确、简短、基于证据的积极表现"],
      "watch_observations": ["明确、简短、需要后续观察的线索"],
      "summary": "面向教师和家长的简短观察摘要"
    }
    positive_observations 和 watch_observations 最多各 5 条；没有对应内容时返回空数组。summary 控制在 30-180 个中文字符。
  PROMPT

  def initialize(record, client: DeepseekClient.new(max_tokens: 700))
    @record = record
    @client = client
  end

  def call
    response = @client.chat(messages: messages)
    result = parse_response(response.fetch(:content))
    result.merge(model: response[:model], usage: response[:usage] || {})
  rescue KeyError, JSON::ParserError => e
    raise Error, "AI 返回的成长观察格式无效：#{e.message}"
  end

  private

  def messages
    content = [{ type: "text", text: prompt_text }]
    media_parts.each { |part| content << { type: "image_url", image_url: { url: part } } }

    [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: content }
    ]
  end

  def prompt_text
    note = @record.note.to_s.strip
    text = [OUTPUT_PROMPT, "记录文字：#{note.presence || '（未提供文字）'}"].join("\n\n")
    text + "\n\n附件说明：图片和视频附件已经作为图像输入提供；视频附件只提供抽取的代表性画面。"
  end

  def media_parts
    parts = []
    @record.media.each do |attachment|
      break if parts.length >= MAX_MEDIA_PARTS

      if attachment.content_type.to_s.start_with?("video/")
        parts.concat(video_frames(attachment, MAX_MEDIA_PARTS - parts.length))
      elsif attachment.content_type.to_s.start_with?("image/")
        parts << image_data_uri(attachment)
      end
    end
    parts.compact.first(MAX_MEDIA_PARTS)
  end

  def image_data_uri(attachment)
    data = attachment.blob.download
    if data.bytesize <= MAX_DIRECT_IMAGE_BYTES
      return "data:#{attachment.content_type};base64,#{Base64.strict_encode64(data)}"
    end

    transcode_image(data, attachment.filename.extension_with_delimiter, 1).first
  end

  def video_frames(attachment, limit)
    source = Tempfile.new(["growth-record-video", attachment.filename.extension_with_delimiter])
    source.binmode
    source.write(attachment.blob.download)
    source.close
    output_dir = Dir.mktmpdir("growth-record-frames")
    output_pattern = File.join(output_dir, "frame-%02d.jpg")
    command = [ffmpeg_path, "-hide_banner", "-loglevel", "error", "-i", source.path,
               "-vf", "fps=1/2,scale=#{MAX_FRAME_WIDTH}:-2", "-frames:v", limit.to_s, output_pattern]
    _stdout, stderr, status = run_ffmpeg(command)
    raise Error, "视频画面提取失败" unless status.success?

    Dir[File.join(output_dir, "frame-*.jpg")].sort.first(limit).map do |path|
      "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(path))}"
    end
  ensure
    source&.unlink
    FileUtils.remove_entry(output_dir) if output_dir && Dir.exist?(output_dir)
  end

  def transcode_image(data, extension, limit)
    source = Tempfile.new(["growth-record-image", extension.presence || ".img"])
    source.binmode
    source.write(data)
    source.close
    output_dir = Dir.mktmpdir("growth-record-image")
    output_pattern = File.join(output_dir, "image-%02d.jpg")
    command = [ffmpeg_path, "-hide_banner", "-loglevel", "error", "-i", source.path,
               "-vf", "scale=#{MAX_FRAME_WIDTH}:-2", "-frames:v", limit.to_s, output_pattern]
    _stdout, stderr, status = run_ffmpeg(command)
    raise Error, "图片处理失败" unless status.success?

    Dir[File.join(output_dir, "image-*.jpg")].sort.first(limit).map do |path|
      "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(path))}"
    end
  ensure
    source&.unlink
    FileUtils.remove_entry(output_dir) if output_dir && Dir.exist?(output_dir)
  end

  def run_ffmpeg(command)
    Timeout.timeout(FFMPEG_TIMEOUT) { Open3.capture3(*command) }
  rescue Errno::ENOENT, Timeout::Error => e
    raise Error, "视频/图片分析需要可用的 ffmpeg：#{e.message}"
  end

  def ffmpeg_path
    ENV.fetch("FFMPEG_PATH", "ffmpeg")
  end

  def parse_response(content)
    parsed = JSON.parse(strip_json_fence(content))
    positive = normalize_observations(parsed["positive_observations"])
    watch = normalize_observations(parsed["watch_observations"])
    effective = parsed["has_effective_content"] == true && (positive.any? || watch.any? || parsed["summary"].to_s.strip.present?)
    summary = parsed["summary"].to_s.squish
    summary = effective ? "已识别到成长观察内容。" : "未识别到足够清晰、可用于成长分析的内容。" if summary.blank?

    {
      has_effective_content: effective,
      positive_tags: effective ? positive : [],
      watch_tags: effective ? watch : [],
      analysis: summary
    }
  end

  def normalize_observations(value)
    Array(value).filter_map { |item| item.to_s.squish.presence }.first(5)
  end

  def strip_json_fence(content)
    content.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
  end
end
