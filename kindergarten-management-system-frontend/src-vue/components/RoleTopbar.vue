<script setup>
import { Menu, X } from "lucide-vue-next";

defineProps({
  meta: { type: Object, required: true },
  open: { type: Boolean, default: false },
});

const emit = defineEmits(["toggle"]);
</script>

<template>
  <header class="shell-topbar">
    <div style="display:flex; align-items:center; gap:12px">
      <button class="icon-button mobile-menu" type="button" :title="open ? '关闭导航' : '打开导航'" :aria-label="open ? '关闭导航' : '打开导航'" :aria-expanded="open" @click="emit('toggle')"><Menu v-if="!open" :size="18" /><X v-else :size="18" /></button>
      <span class="topbar-title"><component :is="meta.icon" :size="15" style="vertical-align:-3px; margin-right:6px" />{{ meta.title }}</span>
    </div>
    <div class="topbar-meta"><time>{{ new Date().toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' }) }}</time></div>
  </header>
</template>
