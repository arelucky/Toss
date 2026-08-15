<script setup lang="ts">
import { RouterView } from "vue-router";
</script>

<template>
  <RouterView />
</template>

<style>
:root {
  color: #20242a;
  background: #f4f5f7;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

* { box-sizing: border-box; }
body { margin: 0; min-width: 960px; }
button, input, textarea { font: inherit; }
.admin-shell { width: min(1120px, calc(100% - 64px)); margin: 0 auto; padding: 40px 0; }
.panel { background: white; border: 1px solid #e2e5e9; border-radius: 12px; padding: 24px; }
.muted { color: #68707b; }
.error { color: #b42318; }
</style>
