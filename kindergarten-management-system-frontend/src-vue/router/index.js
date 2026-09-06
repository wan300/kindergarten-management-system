import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "../stores/auth";
import HomeView from "../views/HomeView.vue";
import LoginView from "../views/LoginView.vue";
import SignupView from "../views/SignupView.vue";
import ParentSignupView from "../views/ParentSignupView.vue";
import RoleLayout from "../layouts/RoleLayout.vue";
import OverviewView from "../views/OverviewView.vue";
import ResourceView from "../views/ResourceView.vue";
import ChildGrowthView from "../views/ChildGrowthView.vue";
import ParentKidsView from "../views/ParentKidsView.vue";
import ParentKidDetailView from "../views/ParentKidDetailView.vue";
import ParentChatView from "../views/ParentChatView.vue";
import ProfileView from "../views/ProfileView.vue";
import ChildDashboardView from "../views/ChildDashboardView.vue";
import ParentingAdviceView from "../views/ParentingAdviceView.vue";
import EducationalVideosView from "../views/EducationalVideosView.vue";
import AttendanceView from "../views/AttendanceView.vue";
import ChildChatAdminView from "../views/ChildChatAdminView.vue";
import StudentDetailView from "../views/StudentDetailView.vue";
import AttendanceDetailView from "../views/AttendanceDetailView.vue";
import AdminUsersView from "../views/AdminUsersView.vue";
import GrowthJournalView from "../views/GrowthJournalView.vue";
import DeviceManagementView from "../views/DeviceManagementView.vue";

const adminResources = {
  teachers: { title: "教师档案", endpoint: "/admin/teachers", fields: ["first_name", "last_name", "career_name", "email", "phone_number", "gender", "password"] },
  classrooms: { title: "班级矩阵", endpoint: "/admin/classrooms", fields: ["name", "teacher_id"] },
  students: { title: "学生档案", endpoint: "/admin/students", fields: ["first_name", "second_name", "surname", "admission_number", "age", "description", "classroom_id"] },
  parents: { title: "家长档案", endpoint: "/admin/parents", fields: ["first_name", "last_name", "phone_number", "email", "password"] },
  parent_students: { title: "绑定审批", endpoint: "/admin/parent_students", fields: [], approval: true },
  attendances: { title: "全园考勤", endpoint: "/admin/attendances", fields: [], readOnly: true },
  disciplines: { title: "纪律记录", endpoint: "/admin/disciplines", fields: ["student_id", "title", "description", "date"] },
  educational_videos: { title: "早教视频库", endpoint: "/admin/educational_videos", fields: ["title", "description", "stage", "level", "subject", "min_age", "max_age", "status"], upload: true },
  child_chat_sessions: { title: "儿童聊天观测", endpoint: "/admin/child_chat_sessions", fields: [], readOnly: true, sessions: true },
  parenting_advice: { title: "育儿建议推送", endpoint: "/admin/parenting_advice_schedules", fields: ["source_type", "title", "body", "recurrence", "scheduled_at", "send_time", "weekday"], schedules: true },
};

const teacherResources = {
  kids_list: { title: "本班学生", endpoint: "/students", fields: ["first_name", "second_name", "surname", "admission_number", "age", "description"] },
  attendance: { title: "考勤工作台", endpoint: "/attendances", fields: ["date", "student_id", "status"] },
  discipline: { title: "纪律记录", endpoint: "/disciplines", fields: ["student_id", "title", "description", "date"] },
  classes: { title: "我的班级", endpoint: "/classrooms", fields: [], readOnly: true },
  parents: { title: "家长通讯录", endpoint: "/teacher/parent", fields: [], readOnly: true },
};

function resourceRoute(path, role, config) {
  return { path, component: ResourceView, props: { role, config }, meta: { role, theme: role === "parent" || role === "child" ? "light" : "dark" } };
}

const routes = [
  { path: "/", component: HomeView, meta: { theme: "light" } },
  { path: "/login", component: LoginView, props: { role: "teacher" }, meta: { theme: "dark" } },
  { path: "/admin_login", component: LoginView, props: { role: "admin" }, meta: { theme: "dark" } },
  { path: "/parent_login", component: LoginView, props: { role: "parent" }, meta: { theme: "light" } },
  { path: "/child_login", component: LoginView, props: { role: "child" }, meta: { theme: "light" } },
  { path: "/parent_signup", component: ParentSignupView, meta: { theme: "light" } },
  { path: "/signup", component: SignupView, meta: { theme: "dark" } },
  {
    path: "/admin_dashboard",
    component: RoleLayout,
    props: { role: "admin" },
    meta: { role: "admin", theme: "dark" },
    children: [
      { path: "", component: OverviewView, props: { role: "admin" }, meta: { role: "admin" } },
      { path: "users", redirect: "/admin_dashboard/users/students", meta: { role: "admin", theme: "dark" } },
      { path: "users/:userType", component: AdminUsersView, props: (route) => ({ userType: route.params.userType }), meta: { role: "admin", theme: "dark" } },
      { path: "teachers", component: AdminUsersView, props: { userType: "teachers" }, meta: { role: "admin", theme: "dark" } },
      { path: "students", component: AdminUsersView, props: { userType: "students" }, meta: { role: "admin", theme: "dark" } },
      { path: "parents", component: AdminUsersView, props: { userType: "parents" }, meta: { role: "admin", theme: "dark" } },
      ...Object.entries(adminResources).filter(([path]) => !["teachers", "students", "parents", "educational_videos", "parenting_advice", "child_chat_sessions", "attendances"].includes(path)).map(([path, config]) => resourceRoute(path, "admin", config)),
      { path: "educational_videos", component: EducationalVideosView, meta: { role: "admin", theme: "dark" } },
      { path: "parenting_advice", component: ParentingAdviceView, meta: { role: "admin", theme: "dark" } },
      { path: "child_chat_sessions", component: ChildChatAdminView, meta: { role: "admin", theme: "dark" } },
      { path: "child_devices", component: DeviceManagementView, meta: { role: "admin", theme: "dark" } },
      { path: "attendances", component: AttendanceView, props: { role: "admin" }, meta: { role: "admin", theme: "dark" } },
      { path: "child_growth", component: ChildGrowthView, meta: { role: "admin", theme: "dark" } },
    ],
  },
  {
    path: "/dashboard",
    component: RoleLayout,
    props: { role: "teacher" },
    meta: { role: "teacher", theme: "dark" },
    children: [
      { path: "", component: OverviewView, props: { role: "teacher" }, meta: { role: "teacher" } },
      ...Object.entries(teacherResources).filter(([path]) => path !== "attendance").map(([path, config]) => resourceRoute(path, "teacher", config)),
      { path: "attendance", component: AttendanceView, props: { role: "teacher" }, meta: { role: "teacher", theme: "dark" } },
      { path: "add_kid", component: ResourceView, props: { role: "teacher", config: { ...teacherResources.kids_list, title: "新增学生", createOnly: true } }, meta: { role: "teacher" } },
      { path: "addcase", component: ResourceView, props: { role: "teacher", config: { ...teacherResources.discipline, title: "新增纪律记录", createOnly: true } }, meta: { role: "teacher" } },
      { path: "kids_list/:id", component: StudentDetailView, meta: { role: "teacher" } },
      { path: "kids_list/:id/growth", component: GrowthJournalView, props: { role: "teacher" }, meta: { role: "teacher" } },
      { path: "attendance/:date", component: AttendanceDetailView, meta: { role: "teacher" } },
      { path: "profile", component: ProfileView, props: { role: "teacher" }, meta: { role: "teacher" } },
    ],
  },
  {
    path: "/parent_dashboard",
    component: RoleLayout,
    props: { role: "parent" },
    meta: { role: "parent", theme: "light" },
    children: [
      { path: "", component: OverviewView, props: { role: "parent" }, meta: { role: "parent", theme: "light" } },
      { path: "my_kids", component: ParentKidsView, meta: { role: "parent", theme: "light" } },
      { path: "my_kids/:id", component: ParentKidDetailView, meta: { role: "parent", theme: "light" } },
      { path: "my_kids/:id/growth", component: GrowthJournalView, props: { role: "parent" }, meta: { role: "parent", theme: "light" } },
      { path: "chat_records", component: ParentChatView, meta: { role: "parent", theme: "light" } },
      { path: "profile", component: ProfileView, props: { role: "parent" }, meta: { role: "parent", theme: "light" } },
    ],
  },
  { path: "/child_dashboard", component: ChildDashboardView, meta: { role: "child", theme: "light" } },
  { path: "/:pathMatch(.*)*", redirect: "/" },
];

const router = createRouter({ history: createWebHistory(), routes, scrollBehavior: () => ({ top: 0 }) });

router.beforeEach((to) => {
  const role = to.meta?.role;
  if (!role) return true;
  const auth = useAuthStore();
  if (!auth.isAuthenticatedFor(role)) {
    return role === "admin" ? "/admin_login" : role === "teacher" ? "/login" : role === "parent" ? "/parent_login" : "/child_login";
  }
  auth.hydrate(role);
  return true;
});

export default router;
