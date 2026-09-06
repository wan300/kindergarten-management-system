<script setup>
import { computed, ref } from "vue";
import { RouterView, useRouter } from "vue-router";
import { Activity, Building2, CalendarCheck, ClipboardList, FileText, HeartHandshake, Home, LayoutDashboard, MessageCircle, School, Settings2, ShieldCheck, Sparkles, TabletSmartphone, UserRound, Users, Video } from "lucide-vue-next";
import { useAuthStore } from "../stores/auth";
import RoleSidebar from "../components/RoleSidebar.vue";
import RoleTopbar from "../components/RoleTopbar.vue";

const props = defineProps({ role: { type: String, required: true } });
const router = useRouter();
const auth = useAuthStore();
const sidebarOpen = ref(false);

const roleMeta = {
  admin: { title: "园所管理", label: "管理员端", icon: ShieldCheck, nav: [
    ["概览", "/admin_dashboard", LayoutDashboard], ["用户管理", "/admin_dashboard/users", Users], ["班级", "/admin_dashboard/classrooms", Building2], ["绑定审批", "/admin_dashboard/parent_students", ClipboardList], ["考勤", "/admin_dashboard/attendances", CalendarCheck], ["纪律", "/admin_dashboard/disciplines", FileText], ["早教视频", "/admin_dashboard/educational_videos", Video], ["设备管理", "/admin_dashboard/child_devices", TabletSmartphone], ["儿童聊天", "/admin_dashboard/child_chat_sessions", MessageCircle], ["数字人", "/admin_dashboard/child_growth", Sparkles], ["育儿建议推送", "/admin_dashboard/parenting_advice", Activity],
  ] },
  teacher: { title: "教师工作台", label: "教师端", icon: School, nav: [
    ["概览", "/dashboard", LayoutDashboard], ["本班学生", "/dashboard/kids_list", Users], ["新增学生", "/dashboard/add_kid", UserRound], ["考勤", "/dashboard/attendance", CalendarCheck], ["纪律", "/dashboard/discipline", FileText], ["我的班级", "/dashboard/classes", Building2], ["家长通讯录", "/dashboard/parents", HeartHandshake], ["个人资料", "/dashboard/profile", Settings2],
  ] },
  parent: { title: "家长空间", label: "家长端", icon: HeartHandshake, nav: [
    ["概览", "/parent_dashboard", Home], ["我的孩子", "/parent_dashboard/my_kids", Users], ["聊天记录", "/parent_dashboard/chat_records", MessageCircle], ["个人资料", "/parent_dashboard/profile", Settings2],
  ] },
};

const meta = computed(() => roleMeta[props.role] || roleMeta.parent);
const displayName = computed(() => {
  const data = auth.profile || {};
  return data.career_name || data.first_name || data.name || meta.value.label;
});
const initials = computed(() => String(displayName.value).slice(0, 1).toUpperCase());
const isLight = computed(() => props.role === "parent");

function logout() {
  auth.logout(props.role);
  router.push(meta.value.nav[0][1]);
}

function closeOnMobile() {
  sidebarOpen.value = false;
}
</script>

<template>
  <div class="shell" :class="{ 'light-shell': isLight }">
    <button v-if="sidebarOpen" class="nav-backdrop" type="button" aria-label="关闭导航" @click="closeOnMobile" />
    <RoleSidebar :meta="meta" :display-name="displayName" :initials="initials" :open="sidebarOpen" @close="closeOnMobile" @logout="logout" />
    <main class="shell-main">
      <RoleTopbar :meta="meta" :open="sidebarOpen" @toggle="sidebarOpen = !sidebarOpen" />
      <div class="main-content"><RouterView /></div>
    </main>
  </div>
</template>
