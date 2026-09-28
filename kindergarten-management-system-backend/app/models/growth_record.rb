class GrowthRecord < ApplicationRecord
  belongs_to :student
  has_many_attached :media

  validates :recorded_on, :author_role, presence: true
  validates :author_role, inclusion: { in: %w[parent teacher admin] }
  validate :has_observation

  def self.summary_for(records)
    recent = records.where("recorded_on >= ?", 14.days.ago.to_date).to_a
    watch = recent.flat_map { |record| record.watch_tags.to_s.split(",") }.reject(&:blank?).uniq
    positive = recent.flat_map { |record| record.positive_tags.to_s.split(",") }.reject(&:blank?).uniq

    {
      record_count: recent.size,
      period: "近14天",
      watch_tags: watch,
      positive_tags: positive,
      status: watch.any? ? "建议关注" : (recent.any? ? "状态平稳" : "暂无足够记录"),
      suggestion: if watch.any?
                    "建议家长与老师围绕“#{watch.first(3).join('、')}”保持沟通；若持续出现身体不适或明显情绪变化，请及时咨询专业人士。"
                  elsif recent.any?
                    "近期观察整体平稳，可继续记录孩子的兴趣、同伴互动和作息变化。"
                  else
                    "请补充日常观察记录，系统将在积累更多信息后提供趋势提示。"
                  end,
      disclaimer: "本摘要基于上传文字中的关键词自动整理，仅供家园沟通与日常观察参考，不构成医疗、心理或教育诊断。"
    }
  end

  def has_observation
    errors.add(:base, "请填写文字说明或至少上传一份照片/视频") if note.to_s.strip.blank? && media.empty?
  end
end
