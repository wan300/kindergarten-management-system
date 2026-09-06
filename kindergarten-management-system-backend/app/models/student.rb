class Student < ApplicationRecord
    class DeletionRestricted < StandardError; end

    DEFAULT_CHILD_PASSWORD = "123456"

    has_secure_password
    has_many :parent_students, dependent: :destroy
    has_many :parents, through: :parent_students
    belongs_to :classroom
    has_many :disciplines, dependent: :destroy
    has_many :attendances, dependent: :destroy
    has_many :child_chat_sessions, dependent: :destroy
    has_many :child_devices
    has_many :growth_records, dependent: :destroy

    before_validation :set_default_child_password, on: :create
    before_destroy :preserve_device_history, prepend: true

    validates :first_name, :surname, :age, :admission_number, presence: true
    validates :admission_number, uniqueness: true
    validates :age, numericality: { only_integer: true, greater_than: 0 }
    validates :password, length: { minimum: 5 }, allow_nil: true

    private

    def preserve_device_history
        if child_devices.exists?
            raise DeletionRestricted, "该学生仍绑定设备（含已停用设备），请先改绑或解绑后再删除。"
        end
        if child_chat_sessions.where(source: "device").exists?
            raise DeletionRestricted, "该学生存在设备聊天历史，为保留历史记录，不能删除学生档案。"
        end
    end

    def set_default_child_password
        self.password = DEFAULT_CHILD_PASSWORD if password_digest.blank? && password.blank?
    end
end
