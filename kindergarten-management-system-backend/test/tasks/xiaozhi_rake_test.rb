require "test_helper"
require "rake"

class XiaozhiRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("xiaozhi:bind")
    @old_device_id = ENV["DEVICE_ID"]
    @old_student_id = ENV["STUDENT_ID"]
  end

  teardown do
    ENV["DEVICE_ID"] = @old_device_id
    ENV["STUDENT_ID"] = @old_student_id
    Rake::Task["xiaozhi:bind"].reenable
  end

  test "bind rejects a student id that is not a strict positive integer" do
    ENV["DEVICE_ID"] = "test-device"
    ENV["STUDENT_ID"] = "1abc"

    _stdout, stderr = capture_io do
      error = assert_raises(SystemExit) { Rake::Task["xiaozhi:bind"].invoke }
      assert_equal 1, error.status
    end
    assert_match(/STUDENT_ID must be a positive integer/, stderr)
  end
end
