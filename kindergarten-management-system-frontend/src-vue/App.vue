<script setup>
import { RouterView } from "vue-router";
import Toast from "./components/Toast.vue";

</script>

<template>
  <div class="app-root" data-theme="light">
    <RouterView v-slot="{ Component }">
      <Transition name="page" mode="out-in">
        <component :is="Component" />
      </Transition>
    </RouterView>
    <Toast />
  </div>
</template>
