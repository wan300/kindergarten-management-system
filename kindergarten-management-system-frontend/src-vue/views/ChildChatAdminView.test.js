import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";
import ChildChatAdminView from "./ChildChatAdminView.vue";

const { get } = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock("../api/client", () => ({ api: { get } }));

describe("ChildChatAdminView", () => {
  beforeEach(() => get.mockReset());

  it("shows whether a session came from a Xiaozhi device or the child web UI", async () => {
    get.mockResolvedValue([
      { id: 1, student_name: "Noah", source: "device", device_id: "test-device", messages: [] },
      { id: 2, student_name: "Lily", source: "web", messages: [] },
    ]);
    const wrapper = mount(ChildChatAdminView);
    await flushPromises();

    expect(wrapper.text()).toContain("小智设备 · test-device");
    expect(wrapper.text()).toContain("儿童网页");
  });
});
