require "json"
require "net/http"
require "uri"

class DeepseekClient
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  def initialize(
    api_key: ENV["DEEPSEEK_API_KEY"].presence || ENV["LLM_API_KEY"],
    base_url: ENV["DEEPSEEK_BASE_URL"].presence || ENV.fetch("LLM_BASE_URL", "https://api.deepseek.com"),
    model: ENV["DEEPSEEK_MODEL"].presence || ENV.fetch("CHAT_MODEL", "deepseek-v4-flash"),
    max_tokens: ENV.fetch("DEEPSEEK_MAX_TOKENS", "500").to_i,
    thinking: { type: "disabled" }
  )
    @api_key = api_key
    @base_url = base_url
    @model = model
    @max_tokens = max_tokens
    @thinking = thinking
  end

  def chat(messages:)
    raise ConfigurationError, "DeepSeek API key is not configured" if @api_key.blank?

    response = perform_request(messages)
    parsed = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, parsed.dig("error", "message").presence || "DeepSeek request failed"
    end

    content = parsed.dig("choices", 0, "message", "content").to_s.strip
    raise ApiError, "DeepSeek returned an empty response" if content.blank?

    {
      content: content,
      model: parsed["model"].presence || @model,
      usage: parsed["usage"] || {}
    }
  rescue JSON::ParserError
    raise ApiError, "DeepSeek returned an invalid response"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise ApiError, "DeepSeek request failed: #{e.message}"
  end

  private

  def perform_request(messages)
    uri = URI.join("#{@base_url.chomp("/")}/", "chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"
    request.body = JSON.dump(
      model: @model,
      messages: messages,
      stream: false,
      max_tokens: @max_tokens,
      thinking: @thinking
    )

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.proxy_from_env = false
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 60
    http.start { http.request(request) }
  end

end
