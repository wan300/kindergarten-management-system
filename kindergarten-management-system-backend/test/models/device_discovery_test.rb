require "test_helper"

class DeviceDiscoveryTest < ActiveSupport::TestCase
  test "observe normalizes and updates one discovery" do
    first_time = Time.zone.parse("2026-09-06 10:00:00")
    second_time = Time.zone.parse("2026-09-06 10:05:00")

    first = DeviceDiscovery.observe!(device_id: " AA:BB ", at: first_time)
    second = DeviceDiscovery.observe!(device_id: "aa:bb", at: second_time)

    assert_equal first.id, second.id
    assert_equal "aa:bb", second.device_id
    assert_equal first_time, second.first_seen_at
    assert_equal second_time, second.last_seen_at
    assert_equal 1, DeviceDiscovery.where(device_id: "aa:bb").count
  end

  test "observe rejects blank and oversized identifiers" do
    assert_raises(ActiveRecord::RecordInvalid) { DeviceDiscovery.observe!(device_id: " ") }
    assert_raises(ActiveRecord::RecordInvalid) { DeviceDiscovery.observe!(device_id: "x" * 129) }
  end
end
