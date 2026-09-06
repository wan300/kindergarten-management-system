// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import router from "./index";

describe("Vue route compatibility", () => {
  beforeEach(async () => {
    setActivePinia(createPinia());
    window.scrollTo = () => {};
    localStorage.clear();
    await router.push("/");
  });

  it("keeps all role login paths public", async () => {
    for (const path of ["/admin_login", "/login", "/parent_login", "/parent_signup", "/child_login"]) {
      await router.push(path);
      expect(router.currentRoute.value.path).toBe(path);
    }
  });

  it("redirects protected dashboard paths to their matching login page", async () => {
    await router.push("/admin_dashboard/students");
    expect(router.currentRoute.value.path).toBe("/admin_login");
    await router.push("/parent_dashboard/my_kids");
    expect(router.currentRoute.value.path).toBe("/parent_login");
    await router.push("/child_dashboard");
    expect(router.currentRoute.value.path).toBe("/child_login");
  });

  it("preserves nested dashboard routes after authentication", async () => {
    localStorage.setItem("teacherToken", "teacher-token");
    await router.push("/dashboard/kids_list");
    expect(router.currentRoute.value.path).toBe("/dashboard/kids_list");
  });

  it("keeps the legacy business URL surface resolvable", async () => {
    localStorage.setItem("adminToken", "admin-token");
    localStorage.setItem("teacherToken", "teacher-token");
    localStorage.setItem("jwt", "parent-token");
    localStorage.setItem("childToken", "child-token");
    const paths = [
      "/admin_dashboard/users/students",
      "/admin_dashboard/users/parents",
      "/admin_dashboard/users/teachers",
      "/admin_dashboard/teachers",
      "/admin_dashboard/classrooms",
      "/admin_dashboard/students",
      "/admin_dashboard/parents",
      "/admin_dashboard/parent_students",
      "/admin_dashboard/attendances",
      "/admin_dashboard/disciplines",
      "/admin_dashboard/educational_videos",
      "/admin_dashboard/child_chat_sessions",
      "/admin_dashboard/child_devices",
      "/admin_dashboard/child_growth",
      "/admin_dashboard/parenting_advice",
      "/dashboard/add_kid",
      "/dashboard/addcase",
      "/dashboard/attendance/2026-01-01",
      "/parent_dashboard/my_kids/4",
      "/parent_dashboard/chat_records",
      "/child_dashboard",
    ];
    for (const path of paths) {
      await router.push(path);
      expect(router.currentRoute.value.path).toBe(path);
    }
  });

  it("opens the unified user module on the requested user type", async () => {
    localStorage.setItem("adminToken", "admin-token");
    await router.push("/admin_dashboard/users");
    expect(router.currentRoute.value.fullPath).toBe("/admin_dashboard/users/students");
    await router.push("/admin_dashboard/parents");
    expect(router.currentRoute.value.path).toBe("/admin_dashboard/parents");
    expect(router.currentRoute.value.matched.at(-1)?.components?.default).toBeTruthy();
  });
});
