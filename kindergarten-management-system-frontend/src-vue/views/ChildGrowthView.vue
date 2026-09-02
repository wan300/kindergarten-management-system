<script setup>
import { ExternalLink, Maximize2 } from "lucide-vue-next";

// The deployed child application is exposed through the same public origin by Nginx.
const appUrl = (import.meta.env.VITE_CHILD_DEV2_URL || "/child-growth/").trim();
</script>

<template>
  <div class="digital-human-view">
    <div class="page-heading digital-human-heading">
      <div>
        <span class="mono-label">ADMIN / DIGITAL HUMAN</span>
        <h1>数字人</h1>
        <p>在管理中枢内访问数字人应用，开展成长观察与智能交互。</p>
      </div>
      <div class="row-actions">
        <a class="button button-light" :href="appUrl" target="_blank" rel="noreferrer">
          <ExternalLink :size="15" />
          新窗口打开
        </a>
        <button class="button button-dark" type="button" @click="$refs.frame?.requestFullscreen?.()">
          <Maximize2 :size="15" />
          全屏
        </button>
      </div>
    </div>
    <iframe ref="frame" :src="appUrl" title="数字人" class="surface digital-human-frame" />
  </div>
</template>

<style scoped>
.digital-human-view {
  display: flex;
  min-height: 620px;
  height: calc(100vh - 130px);
  flex-direction: column;
  gap: 14px;
}

.digital-human-heading {
  margin-bottom: 0;
}

.digital-human-frame {
  width: 100%;
  min-height: 0;
  flex: 1;
  border: 1px solid var(--line-dark);
  background: #fff;
}

@media (max-width: 600px) {
  .digital-human-view {
    min-height: 560px;
    height: calc(100vh - 100px);
  }
}
</style>
