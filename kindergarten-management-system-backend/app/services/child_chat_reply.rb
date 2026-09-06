class ChildChatReply
  SYSTEM_PROMPT = <<~PROMPT.squish.freeze
    你是幼儿园儿童端的早教陪伴助手。你陪伴 3-6 岁儿童聊天、学习和表达情绪。
    你必须使用简短、温柔、积极的中文回答，每次只讲一个小重点，并用提问鼓励孩子思考。
    你不能替代家长、老师、医生或心理咨询师。遇到身体不适、危险、伤害、隐私、成人内容或不适龄内容时，
    请停止展开细节，提醒孩子马上找家长或老师帮忙。
  PROMPT
  HISTORY_LIMIT = 12

  Result = Struct.new(:user_message, :assistant_message, keyword_init: true)

  def initialize(client: DeepseekClient.new)
    @client = client
  end

  def call(session:, content:, user_message: nil)
    user_message ||= session.child_chat_messages.create!(role: ChildChatMessage::USER, content: content)
    result = @client.chat(messages: messages_for(session))
    assistant = session.child_chat_messages.create!(
      role: ChildChatMessage::ASSISTANT, content: result[:content], model: result[:model],
      prompt_tokens: result.dig(:usage, "prompt_tokens"), completion_tokens: result.dig(:usage, "completion_tokens"),
      total_tokens: result.dig(:usage, "total_tokens")
    )
    session.touch
    Result.new(user_message: user_message, assistant_message: assistant)
  end

  def self.serialize(message)
    { id: message.id, role: message.role, content: message.content, model: message.model,
      prompt_tokens: message.prompt_tokens, completion_tokens: message.completion_tokens,
      total_tokens: message.total_tokens, created_at: message.created_at }
  end

  private

  def messages_for(session)
    student = session.student
    name = [student.first_name, student.second_name, student.surname].filter_map(&:presence).join(" ")
    system = { role: ChildChatMessage::SYSTEM, content: "#{SYSTEM_PROMPT} 当前正在陪伴的孩子是 #{name}，#{student.age} 岁。" }
    history = session.child_chat_messages.order(:created_at).last(HISTORY_LIMIT).map { |message| { role: message.role, content: message.content } }
    [system] + history
  end
end
