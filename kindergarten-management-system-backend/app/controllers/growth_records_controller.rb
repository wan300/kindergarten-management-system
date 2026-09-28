class GrowthRecordsController < ApplicationController
  MAX_FILE_SIZE = 100.megabytes
  MAX_FILES = 5
  ALLOWED_MEDIA_TYPES = /\A(image|video)\//.freeze

  before_action :require_parent_or_teacher
  before_action :load_student, only: [:index, :create]
  before_action :load_record_for_update, only: [:update]

  rescue_from ActiveRecord::RecordInvalid, with: :invalid_response
  rescue_from ActiveRecord::RecordNotFound, with: :not_found_response

  def index
    records = @student.growth_records.with_attached_media.order(recorded_on: :desc, created_at: :desc)
    render json: { records: records.map { |record| record_payload(record) }, summary: GrowthRecord.summary_for(records) }
  end

  def create
    validate_media!
    return if performed?

    record = @student.growth_records.build(growth_record_params.merge(author_role: author_role, author_id: author.id))
    prepare_for_analysis(record)
    record.media.attach(media_files) if media_files.any?
    record.save!
    analyze_record(record)
    render json: record_payload(record), status: :created
  end

  def update
    validate_media!
    return if performed?

    should_analyze = params.key?(:note) || media_files.any?
    @record.assign_attributes(growth_record_params)
    prepare_for_analysis(@record) if should_analyze
    @record.media.attach(media_files) if media_files.any?
    @record.save!
    analyze_record(@record) if should_analyze
    render json: record_payload(@record)
  end

  private

  def require_parent_or_teacher
    return if current_parent || current_user

    render json: { error: "Parent or teacher access required" }, status: :forbidden
  end

  def load_student
    @student = if current_parent
                 current_parent.approved_students.find(params[:student_id])
               else
                 teacher_students.find(params[:student_id])
               end
  end

  def load_record_for_update
    record = GrowthRecord.find(params[:id])
    accessible = if current_parent
                   current_parent.approved_students.exists?(id: record.student_id)
                 else
                   teacher_students.exists?(id: record.student_id)
                 end
    editable = record.author_role == author_role && record.author_id.to_i == author.id
    raise ActiveRecord::RecordNotFound unless accessible && editable

    @record = record
  end

  def author
    current_parent || current_user
  end

  def author_role
    current_parent ? "parent" : "teacher"
  end

  def growth_record_params
    params.permit(:recorded_on, :note)
  end

  def media_files
    Array(params[:media]).compact
  end

  def validate_media!
    if media_files.size > MAX_FILES
      render json: { errors: ["每条记录最多上传#{MAX_FILES}个文件"] }, status: :unprocessable_entity
      return
    end

    invalid_file = media_files.find do |file|
      !file.respond_to?(:content_type) || file.content_type.to_s !~ ALLOWED_MEDIA_TYPES || file.size.to_i > MAX_FILE_SIZE
    end
    return unless invalid_file

    render json: { errors: ["只支持单个不超过100MB的图片或视频文件"] }, status: :unprocessable_entity
  end

  def record_payload(record)
    {
      id: record.id,
      student_id: record.student_id,
      recorded_on: record.recorded_on,
      author_role: record.author_role,
      note: record.note,
      analysis: record.analysis,
      positive_tags: record.positive_tags.to_s.split(",").reject(&:blank?),
      watch_tags: record.watch_tags.to_s.split(",").reject(&:blank?),
      analysis_status: record.analysis_status,
      analysis_model: record.analysis_model,
      analysis_generated_at: record.analysis_generated_at,
      created_at: record.created_at,
      media: record.media.map do |file|
        { id: file.id, filename: file.filename.to_s, content_type: file.content_type, byte_size: file.byte_size, url: rails_blob_path(file, only_path: true) }
      end
    }
  end

  def invalid_response(invalid)
    render json: { errors: invalid.record.errors.full_messages }, status: :unprocessable_entity
  end

  def prepare_for_analysis(record)
    record.analysis_status = "pending"
    record.analysis_error = nil
    record.analysis_model = nil
    record.analysis_generated_at = nil
    record.analysis = nil
    record.positive_tags = ""
    record.watch_tags = ""
  end

  def analyze_record(record)
    result = GrowthRecordAnalysis.new(record).call
    record.update_columns(
      analysis: result.fetch(:analysis),
      positive_tags: result.fetch(:positive_tags).join(","),
      watch_tags: result.fetch(:watch_tags).join(","),
      analysis_status: "completed",
      analysis_model: result[:model],
      analysis_generated_at: Time.current,
      analysis_error: nil,
      updated_at: Time.current
    )
  rescue GrowthRecordAnalysis::Error, DeepseekClient::Error => error
    Rails.logger.warn("[GrowthRecordAnalysis] record=#{record.id} failed: #{error.class}: #{error.message}")
    record.update_columns(analysis_status: "failed", analysis_error: error.message.to_s.truncate(500), updated_at: Time.current)
  end

  def not_found_response
    render json: { error: "Child not found" }, status: :not_found
  end
end
