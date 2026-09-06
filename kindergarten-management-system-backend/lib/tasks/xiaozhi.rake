namespace :xiaozhi do
  desc "Bind a Xiaozhi device (requires DEVICE_ID and STUDENT_ID)"
  task bind: :environment do
    device_id = ENV["DEVICE_ID"].to_s.strip
    student_id = ENV["STUDENT_ID"].to_s.strip
    abort "DEVICE_ID is required" if device_id.blank?
    abort "STUDENT_ID is required" if student_id.blank?
    abort "STUDENT_ID must be a positive integer" unless student_id.match?(/\A[1-9]\d*\z/)

    student = Student.find_by(id: student_id)
    abort "Student not found" unless student

    device = ChildDevice.bind!(device_id: device_id, student: student)
    puts "Bound device #{device.device_id} to student #{student.id} (binding epoch #{device.binding_epoch})."
  end

  desc "Disable a Xiaozhi device (requires DEVICE_ID)"
  task disable: :environment do
    device_id = ENV["DEVICE_ID"].to_s.strip
    abort "DEVICE_ID is required" if device_id.blank?

    device = ChildDevice.find_by(device_id: ChildDevice.normalize_id(device_id))
    abort "Device not found" unless device

    device.update!(enabled: false)
    puts "Disabled device #{device.device_id}."
  end
end
