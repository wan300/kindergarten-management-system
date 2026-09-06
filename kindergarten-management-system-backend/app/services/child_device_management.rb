class ChildDeviceManagement
  class NotDiscovered < StandardError; end

  Result = Struct.new(:row, :created, keyword_init: true)
  STATUS_ORDER = { "pending" => 0, "enabled" => 1, "disabled" => 2 }.freeze

  class << self
    def list
      discoveries = DeviceDiscovery.all.index_by(&:device_id)
      devices = ChildDevice.includes(student: :classroom).all.index_by(&:device_id)

      (discoveries.keys | devices.keys)
        .map { |device_id| row_for(device_id, discoveries[device_id], devices[device_id]) }
        .sort_by do |row|
          [STATUS_ORDER.fetch(row[:status]), -(row[:last_seen_at]&.to_f || 0), row[:device_id]]
        end
    end

    def bind!(device_id:, student_id:)
      normalized = ChildDevice.normalize_id(device_id)
      discovery = DeviceDiscovery.find_by(device_id: normalized)
      raise NotDiscovered unless discovery

      student = Student.find(student_id)
      existing = ChildDevice.find_by(device_id: normalized)
      device = ChildDevice.bind!(device_id: normalized, student: student)
      Result.new(row: row_for(normalized, discovery, device), created: existing.nil?)
    end

    def disable!(id:)
      device = ChildDevice.find(id)
      device.with_lock { device.update!(enabled: false) }
      row_for(device.device_id, DeviceDiscovery.find_by(device_id: device.device_id), device)
    end

    def enable!(id:)
      device = ChildDevice.find(id)
      device.with_lock { device.update!(enabled: true) }
      row_for(device.device_id, DeviceDiscovery.find_by(device_id: device.device_id), device)
    end

    private

    def row_for(device_id, discovery, device)
      student = device&.student
      classroom = student&.classroom
      {
        id: device&.id,
        device_id: device_id,
        status: device.nil? ? "pending" : device.enabled? ? "enabled" : "disabled",
        first_seen_at: discovery&.first_seen_at,
        last_seen_at: discovery&.last_seen_at,
        bound_at: device&.updated_at,
        student: student && {
          id: student.id,
          name: [student.first_name, student.second_name, student.surname].filter_map(&:presence).join(" "),
          admission_number: student.admission_number
        },
        classroom: classroom && { id: classroom.id, name: classroom.name }
      }
    end
  end
end
