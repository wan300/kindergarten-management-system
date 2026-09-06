// @vitest-environment jsdom
import { mount } from "@vue/test-utils";
import { createPinia } from "pinia";
import { createMemoryHistory, createRouter } from "vue-router";
import { describe, expect, it } from "vitest";
import RoleLayout from "./RoleLayout.vue";

async function mountRole(role) {
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: "/:pathMatch(.*)*", component: { template: "<div />" } }] });
  await router.push("/");
  await router.isReady();
  return mount(RoleLayout, { props: { role }, global: { plugins: [createPinia(), router] } });
}

describe("RoleLayout device navigation", () => {
  it("shows device management only to administrators", async () => {
    expect((await mountRole("admin")).text()).toContain("设备管理");
    expect((await mountRole("teacher")).text()).not.toContain("设备管理");
    expect((await mountRole("parent")).text()).not.toContain("设备管理");
  });
});
