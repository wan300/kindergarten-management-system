<script setup>
import { RouterLink } from "vue-router";
import { useRoute } from "vue-router";
import { LogOut, X } from "lucide-vue-next";

const props = defineProps({
  meta: { type: Object, required: true },
  displayName: { type: String, required: true },
  initials: { type: String, required: true },
  open: { type: Boolean, default: false },
});

const emit = defineEmits(["close", "logout", "toggle"]);
const route = useRoute();

function isNavActive(to) {
  const overviewPath = props.meta.nav[0][1];
  return to === overviewPath ? route.path === to : route.path === to || route.path.startsWith(`${to}/`);
}
</script>

<template>
  <aside class="shell-sidebar" :class="{ open: props.open }">
    <div class="sidebar-brand">
      <button v-if="props.open" class="icon-button sidebar-close" type="button" title="关闭导航" aria-label="关闭导航" @click="emit('close')"><X :size="17" /></button>
      <RouterLink class="brand-lockup" :to="props.meta.nav[0][1]" @click="emit('close')">
        <img class="brand-mark" src="/assets/brand/para-kindergarten-logo.png" alt="ParaKindergarten" />
        <span><strong class="brand-name">ParaKindergarten</strong><small class="brand-subtitle">家园共育 · {{ props.meta.label }}</small></span>
      </RouterLink>
    </div>
    <nav class="shell-nav" aria-label="主导航">
      <span class="shell-nav-label">日常工作</span>
      <RouterLink v-for="[label, to, Icon] in props.meta.nav"
        :key="to"
        :to="to"
        active-class="router-link-auto-active"
        exact-active-class=""
        :class="{ 'router-link-active': isNavActive(to) }"
        @click="emit('close')"
      >
        <component :is="Icon" :size="16" :stroke-width="1.8" />
        <span>{{ label }}</span>
      </RouterLink>
    </nav>
    <div class="sidebar-spacer" />
    <div class="sidebar-user">
      <span class="avatar">{{ props.initials }}</span>
      <span style="min-width:0; flex:1"><strong style="display:block; color:inherit; overflow:hidden; text-overflow:ellipsis; white-space:nowrap">{{ props.displayName }}</strong><small style="display:block; margin-top:2px">{{ props.meta.label }}</small></span>
      <button class="icon-button" type="button" title="退出登录" aria-label="退出登录" @click="emit('logout')"><LogOut :size="15" /></button>
    </div>
  </aside>
</template>
