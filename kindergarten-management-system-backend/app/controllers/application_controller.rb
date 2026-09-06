class ApplicationController < ActionController::API
    before_action :authorize
    rescue_from Student::DeletionRestricted do |error|
      render json: { error: error.message }, status: :conflict
    end
    def encode_token(payload)
      now = Time.current.to_i
      claims = payload.merge(
        iat: now,
        exp: Time.current.advance(hours: jwt_expiration_hours).to_i
      )
      JWT.encode(claims, jwt_secret, 'HS256')
    end
  
    def auth_header
      # { Authorization: 'Bearer <token>' }
      request.headers['Authorization']
    end
  
    def decoded_token
      if auth_header
        token = auth_header.split(' ')[1]
        # header: { 'Authorization': 'Bearer <token>' }
        begin
          JWT.decode(token, jwt_secret, true, algorithm: 'HS256')
        rescue JWT::DecodeError, JWT::ExpiredSignature
          nil
        end
      end
    end
  
    def current_user
      return @current_teacher if defined?(@current_teacher)

      @current_teacher = nil
      if decoded_token
        teacher_id = decoded_token[0]['teacher_id']
        @current_teacher = Teacher.find_by(id: teacher_id)
        @teacher = @current_teacher
      end
      @current_teacher
    end

    def current_parent
      return @current_parent if defined?(@current_parent)

      @current_parent = nil
      if decoded_token
        parent_id = decoded_token[0]['parent_id']
        @current_parent = Parent.find_by(id: parent_id)
      end
      @current_parent
    end

    def current_admin
      return @current_admin if defined?(@current_admin)

      @current_admin = nil
      if decoded_token
        admin_id = decoded_token[0]['admin_id']
        @current_admin = Admin.find_by(id: admin_id)
      end
      @current_admin
    end

    def current_child_student
      return @current_child_student if defined?(@current_child_student)

      @current_child_student = nil
      if decoded_token
        student_id = decoded_token[0]['child_student_id']
        @current_child_student = Student.find_by(id: student_id)
      end
      @current_child_student
    end
  
    def logged_in?
      !!current_user || !!current_parent || !!current_admin || !!current_child_student
    end
  
    def authorize
      render json: { message: 'Please log in' }, status: :unauthorized unless logged_in?
    end

    def require_admin
      render json: { error: 'Admin access required' }, status: :forbidden unless current_admin
    end

    def require_teacher
      render json: { error: 'Teacher access required' }, status: :forbidden unless current_user
    end

    def require_parent
      render json: { error: 'Parent access required' }, status: :forbidden unless current_parent
    end

    def require_child
      render json: { error: 'Child access required' }, status: :forbidden unless current_child_student
    end

    def teacher_students
      return Student.none unless current_user&.classroom

      current_user.classroom.students
    end

    def parent_students
      return Student.none unless current_parent

      Student
        .joins(:parent_students)
        .where(parent_students: { parent_id: current_parent.id, status: ParentStudent::APPROVED })
        .distinct
    end

    private

    def jwt_secret
      ENV.fetch('JWT_SECRET') do
        if Rails.env.production?
          raise KeyError, 'JWT_SECRET is required in production'
        end

        'development-test-jwt-secret'
      end
    end

    def jwt_expiration_hours
      ENV.fetch('JWT_EXPIRATION_HOURS', '8').to_i
    end
end
