<script setup lang="ts">
import { RouterView } from "vue-router";
</script>

<template>
  <RouterView />
</template>

<style>
:root {
  --admin-bg: #0d0d0c;
  --admin-surface: #171715;
  --admin-surface-raised: #22211e;
  --admin-ivory: #f2eee4;
  --admin-muted: #aaa49a;
  --admin-gold: #cfac69;
  --admin-line: rgba(242, 238, 228, .14);
  --admin-danger: #e6aaa0;
  --admin-focus: #e4c27c;
  color: var(--admin-ivory);
  background: var(--admin-bg);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color-scheme: dark;
}

* { box-sizing: border-box; }
body { margin: 0; min-width: 0; min-height: 100vh; background: var(--admin-bg); }
button, input, textarea { font: inherit; }
.admin-shell { width: min(1120px, calc(100% - 40px)); margin: 0 auto; padding: 40px 0; }
.panel { background: var(--admin-surface); border: 1px solid var(--admin-line); border-radius: 12px; padding: 24px; }
.muted { color: var(--admin-muted); }
.error { color: var(--admin-danger); }

input, textarea {
  color: var(--admin-ivory);
  background: #121210 !important;
  border-color: var(--admin-line) !important;
}

button {
  color: var(--admin-ivory);
  border-color: var(--admin-line);
  background: var(--admin-surface-raised);
}

:focus-visible {
  outline: 2px solid var(--admin-focus);
  outline-offset: 3px;
}

@media (max-width: 640px) {
  .admin-shell { width: min(100% - 32px, 1120px); padding: 24px 0; }
  .panel { padding: 18px; }
}
</style>
