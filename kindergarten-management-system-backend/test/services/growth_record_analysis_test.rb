require "test_helper"

class GrowthRecordAnalysisTest < ActiveSupport::TestCase
  FakeRecord = Struct.new(:note, :media)
  FakeBlob = Struct.new(:data) do
    def download
      data
    end
  end
  FakeAttachment = Struct.new(:content_type, :blob)

  class FakeClient
    attr_reader :messages

    def initialize(content)
      @content = content
    end

    def chat(messages:)
      @messages = messages
      { content: @content, model: "deepseek-v4-flash", usage: {} }
    end
  end

  test "parses evidence-backed positive and watch observations" do
    client = FakeClient.new(JSON.generate(
      has_effective_content: true,
      positive_observations: ["主动邀请同伴一起搭建积木"],
      watch_observations: ["午餐时明确表示不吃"],
      summary: "记录显示孩子主动参与同伴活动，同时午餐行为值得继续观察。"
    ))

    result = GrowthRecordAnalysis.new(FakeRecord.new("今天搭积木并说不吃午饭", []), client: client).call

    assert_equal ["主动邀请同伴一起搭建积木"], result[:positive_tags]
    assert_equal ["午餐时明确表示不吃"], result[:watch_tags]
    assert_equal "deepseek-v4-flash", result[:model]
    assert_equal "system", client.messages.first[:role]
  end

  test "does not invent tags when the model reports no effective content" do
    client = FakeClient.new(JSON.generate(
      has_effective_content: false,
      positive_observations: ["看起来很开心"],
      watch_observations: ["可能焦虑"],
      summary: ""
    ))

    result = GrowthRecordAnalysis.new(FakeRecord.new("一张模糊照片", []), client: client).call

    assert_equal [], result[:positive_tags]
    assert_equal [], result[:watch_tags]
    assert_equal "未识别到足够清晰、可用于成长分析的内容。", result[:analysis]
  end

  test "passes image attachments as multimodal image urls" do
    client = FakeClient.new(JSON.generate(
      has_effective_content: true,
      positive_observations: ["完成了绘画作品"],
      watch_observations: [],
      summary: "图片中可以明确看到孩子完成了一幅绘画作品。"
    ))
    image = FakeAttachment.new("image/png", FakeBlob.new("image-bytes"))

    GrowthRecordAnalysis.new(FakeRecord.new("", [image]), client: client).call

    content = client.messages.last[:content]
    assert_equal "text", content.first[:type]
    assert_equal "image_url", content.last[:type]
    assert_match(/data:image\/png;base64,/, content.last.dig(:image_url, :url))
  end
end
