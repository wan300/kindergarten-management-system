// @vitest-environment jsdom
import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";
import DeviceManagementView from "./DeviceManagementView.vue";

const { get, post, patch } = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn(), patch: vi.fn() }));
vi.mock("../api/client", () => ({ api: { get, post, patch } }));

const devices = [
  { id: null, device_id: "aa:bb", status: "pending", first_seen_at: "2026-09-06T10:00:00Z", last_seen_at: "2026-09-06T10:01:00Z", student: null, classroom: null },
  { id: 2, device_id: "cc:dd", status: "enabled", last_seen_at: "2026-09-06T10:02:00Z", student: { id: 7, name: "小明", admission_number: 7001 }, classroom: { id: 3, name: "向日葵班" } },
  { id: 4, device_id: "ee:ff", status: "disabled", last_seen_at: "2026-09-06T10:03:00Z", student: { id: 8, name: "小花", admission_number: 7002 }, classroom: { id: 3, name: "向日葵班" } },
];

function arrange() {
  get.mockImplementation((path) => {
    if (path === "/admin/child_devices") return Promise.resolve(devices);
    if (path === "/admin/students") return Promise.resolve([
      { id: 7, first_name: "小明", surname: "同学", admission_number: 7001, classroom_id: 3 },
      { id: 8, first_name: "小花", surname: "同学", admission_number: 7002, classroom_id: 3 },
    ]);
    if (path === "/admin/classrooms") return Promise.resolve([{ id: 3, name: "向日葵班" }]);
    return Promise.reject(new Error("unexpected path"));
  });
  post.mockResolvedValue(devices[1]);
  patch.mockResolvedValue(devices[2]);
}

describe("DeviceManagementView", () => {
  beforeEach(() => {
    get.mockReset(); post.mockReset(); patch.mockReset(); arrange();
  });

  it("shows status counts and device ownership", async () => {
    const wrapper = mount(DeviceManagementView, { global: { stubs: { RouterLink: { template: "<a><slot /></a>" } } } });
    await flushPromises();

    expect(wrapper.text()).toContain("待绑定");
    expect(wrapper.text()).toContain("使用中");
    expect(wrapper.text()).toContain("已停用");
    expect(wrapper.text()).toContain("aa:bb");
    expect(wrapper.text()).toContain("cc:dd");
    expect(wrapper.text()).toContain("小明");
    expect(wrapper.text()).toContain("向日葵班");
    expect(wrapper.findAll(".device-metric-value").map((node) => node.text())).toEqual(["1", "1", "1"]);
  });

  it("binds a pending device to a selected child", async () => {
    const wrapper = mount(DeviceManagementView, { global: { stubs: { RouterLink: { template: "<a><slot /></a>" } } } });
    await flushPromises();
    await wrapper.get('[data-action="bind-aa:bb"]').trigger("click");
    await wrapper.get("#device-classroom").setValue("3");
    await wrapper.get("#device-student").setValue("7");
    await wrapper.get(".device-dialog-confirm").trigger("click");
    await flushPromises();

    expect(post).toHaveBeenCalledWith("/admin/child_devices/bind", { device_id: "aa:bb", student_id: 7 }, "admin");
    expect(wrapper.text()).toContain("设备已绑定到小明 同学");
  });

  it("disables and enables with confirmation and reports failures", async () => {
    const wrapper = mount(DeviceManagementView, { global: { stubs: { RouterLink: { template: "<a><slot /></a>" } } } });
    await flushPromises();
    await wrapper.get('[data-action="disable-2"]').trigger("click");
    await wrapper.get(".device-dialog-confirm").trigger("click");
    await flushPromises();
    expect(patch).toHaveBeenCalledWith("/admin/child_devices/2/disable", {}, "admin");

    patch.mockRejectedValueOnce(new Error("恢复失败"));
    await wrapper.get('[data-action="enable-4"]').trigger("click");
    await flushPromises();
    expect(wrapper.text()).toContain("恢复失败");
  });
});
