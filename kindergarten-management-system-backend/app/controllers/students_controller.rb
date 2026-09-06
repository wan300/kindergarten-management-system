class StudentsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found_message
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

    def index
        render json: accessible_students, status: :ok
    end
    
    def show
        student = accessible_students.find(params[:id])
        render json: student, serializer: SingleStudentSerializer, status: :ok
    end
    
    def create
        require_teacher
        return if performed?

        classroom = current_user.classroom
        if classroom.nil?
            render json: { errors: ['Please assign yourself to a classroom before adding students'] }, status: :unprocessable_entity
            return
        end

        student = Student.create!(student_params.merge(classroom_id: classroom.id))
        render json: student, serializer: SingleStudentSerializer, status: :created
    end

    def update
        require_teacher
        return if performed?

        student = teacher_students.find(params[:id])
        student.update!(teacher_student_params)
        render json: student, serializer: SingleStudentSerializer, status: :ok
    end
    
    def destroy
        require_teacher
        return if performed?

        student = teacher_students.find(params[:id])
        student.destroy!
        head :no_content
    end
    
    private
    def accessible_students
        if current_user
            teacher_students
        else
            parent_students
        end
    end

    def student_params
        params.permit(:first_name,:second_name,:surname,:classroom_id,:age, :description, :admission_number)
    end

    def teacher_student_params
        params.permit(:first_name,:second_name,:surname,:age, :description, :admission_number)
    end

    def not_found_message
        render json: {error: "Student Not Found"}, status: :not_found
    end

    def record_invalid invalid
        render json: {errors: invalid.record.errors.full_messages}, status: :unprocessable_entity
    end
end
