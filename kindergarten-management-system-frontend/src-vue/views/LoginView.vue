<script setup>
import { computed, reactive, ref } from "vue";
import { ArrowLeft, ArrowRight, LoaderCircle, LockKeyhole, Mail, Phone, Sparkles, UserRound } from "lucide-vue-next";
import { useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";

const props = defineProps({ role: { type: String, default: "teacher" } });
const router = useRouter();
const auth = useAuthStore();
const form = reactive({ email: "", phone_number: "", admission_number: "", password: "" });
const submitting = ref(false);

const meta = computed(() => ({
  admin: { title: "管理员登录", label: "园所管理", copy: "统一掌握园所的班级、教师、学生和家庭连接。", field: "email", placeholder: "管理员邮箱", icon: Mail, next: "/admin_dashboard" },
  teacher: { title: "教师登录", label: "教师工作台", copy: "从签到到课堂记录，把每个孩子的今天照顾好。", field: "email", placeholder: "教师邮箱", icon: Mail, next: "/dashboard" },
  parent: { title: "家长登录", label: "家长空间", copy: "看看孩子在园的日常，也分享在家的小小发现。", field: "phone_number", placeholder: "手机号码", icon: Phone, next: "/parent_dashboard" },
  child: { title: "儿童登录", label: "儿童学习空间", copy: "用学号进入你的学习空间，继续今天的探索。", field: "admission_number", placeholder: "学生学号", icon: UserRound, next: "/child_dashboard" },
}[props.role] || {}));

const fieldLabel = computed(() => props.role === "parent" ? "电话号码" : props.role === "child" ? "学生学号" : "邮箱地址");

async function submit() {
  submitting.value = true;
  try {
    const credentials = { [meta.value.field]: form[meta.value.field], password: form.password };
    await auth.login(props.role, credentials);
    router.push(meta.value.next);
  } catch {
    // The store exposes the normalized error for the form; keep the submit handler settled.
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <div class="login-shell" :class="{ 'light-login': role === 'parent' || role === 'child' }">
    <section class="login-card">
      <aside class="login-aside"><RouterLink class="brand-lockup" to="/"><img class="brand-mark" src="/assets/brand/para-kindergarten-logo.png" alt="ParaKindergarten" /><span><strong class="brand-name">ParaKindergarten</strong><small class="brand-subtitle">{{ meta.label }}</small></span></RouterLink><h1>{{ role === 'child' ? '开始你的探索。' : '让每一个日常，都有迹可循。' }}</h1><p>{{ meta.copy }}</p><div style="position:absolute; left:42px; bottom:38px; color:#78866b; font:10px var(--font-mono); letter-spacing:0">陪伴每一个小小的成长</div></aside>
      <div class="login-form-panel"><div style="display:flex; align-items:center; gap:8px; color:var(--cyan); font:10px var(--font-mono); letter-spacing:0"><Sparkles :size="14" /> 欢迎回来</div><h2 style="margin-top:20px">{{ meta.title }}</h2><p>请输入你的登录信息，登录后继续你的日常记录。</p><div v-if="auth.error" class="notice error" style="margin-bottom:14px">{{ auth.error }}</div><form class="login-form" @submit.prevent="submit"><div class="field"><label :for="`${role}-identity`">{{ fieldLabel }}</label><div style="position:relative"><component :is="meta.icon" :size="16" style="position:absolute; left:12px; top:12px; color:#6d8a9a" /><input :id="`${role}-identity`" v-model="form[meta.field]" :type="role === 'parent' || role === 'child' ? 'text' : 'email'" :autocomplete="role === 'parent' ? 'tel' : role === 'child' ? 'username' : 'email'" :placeholder="meta.placeholder" required style="padding-left:38px" /></div></div><div class="field"><label :for="`${role}-password`">密码</label><div style="position:relative"><LockKeyhole :size="16" style="position:absolute; left:12px; top:12px; color:#6d8a9a" /><input :id="`${role}-password`" v-model="form.password" type="password" autocomplete="current-password" placeholder="请输入密码" required style="padding-left:38px" /></div></div><button class="button button-primary" style="width:100%; margin-top:4px" type="submit" :disabled="submitting"><LoaderCircle v-if="submitting" :size="16" class="spin" />{{ submitting ? '验证中...' : '进入工作空间' }}<ArrowRight v-if="!submitting" :size="16" /></button></form><div class="login-links"><RouterLink to="/"><ArrowLeft :size="13" style="vertical-align:-2px" /> 返回首页</RouterLink><RouterLink v-if="role === 'parent'" class="text-link" to="/parent_signup">创建家长账号</RouterLink><RouterLink v-else-if="role === 'admin'" class="text-link" to="/login">教师入口</RouterLink><RouterLink v-else-if="role === 'teacher'" class="text-link" to="/admin_login">管理员入口</RouterLink><RouterLink v-else class="text-link" to="/parent_login">家长入口</RouterLink></div></div>
    </section>
  </div>
</template>

<style scoped>.spin { animation: spin 1s linear infinite; } @keyframes spin { to { transform:rotate(360deg); } }</style>
