import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { createMemoryHistory, createRouter } from "vue-router";
import ChildChatAdminView from "./ChildChatAdminView.vue";

const { get } = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock("../api/client", () => ({ api: { get } }));

describe("ChildChatAdminView", () => {
  beforeEach(() => get.mockReset());

  async function mountView(query = {}) {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: "/admin_dashboard/child_chat_sessions", component: ChildChatAdminView }],
    });
    await router.push({ path: "/admin_dashboard/child_chat_sessions", query });
    await router.isReady();
    return mount(ChildChatAdminView, { global: { plugins: [router] } });
  }

  it("shows whether a session came from a Xiaozhi device or the child web UI", async () => {
    get.mockResolvedValue([
      { id: 1, student_name: "Noah", source: "device", device_id: "test-device", messages: [] },
      { id: 2, student_name: "Lily", source: "web", messages: [] },
    ]);
    const wrapper = await mountView();
    await flushPromises();

    expect(wrapper.text()).toContain("小智设备 · test-device");
    expect(wrapper.text()).toContain("儿童网页");
  });

  it("requests and displays a device filter from the route", async () => {
    get.mockResolvedValue([]);
    const wrapper = await mountView({ device_id: "aa:bb" });
    await flushPromises();

    expect(get).toHaveBeenCalledWith("/admin/child_chat_sessions?device_id=aa%3Abb", "admin");
    expect(wrapper.text()).toContain("aa:bb");
    expect(wrapper.text()).toContain("清除筛选");
  });
});
