<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AssetUploadPanel from "../components/AssetUploadPanel.vue";
import { getSupabaseClient } from "../lib/supabase";
import {
  activeVersion,
  assetState,
  assetStateLabel,
  coinStatusLabel,
  formatBytes,
  publicPreviewURL,
  versionStatusLabel,
  versionsDescending,
} from "../presentation/coinPresentation";
import { adminCoins, AdminCoinsError, type AdminCoin } from "../services/adminCoins";

const props = withDefaults(defineProps<{
  coin?: AdminCoin;
  saveCoin?: (coin: AdminCoin) => Promise<void>;
  confirmAction?: (action: "publish" | "rollback") => Promise<boolean>;
  performAction?: (action: "publish" | "rollback", versionID: string) => Promise<void>;
  makePublicPreviewURL?: (path: string) => string;
}>(), { coin: undefined, saveCoin: undefined, confirmAction: undefined, performAction: undefined, makePublicPreviewURL: undefined });
const route = useRoute();
const router = useRouter();
const loadedCoin = ref<AdminCoin>();
const currentCoin = computed(() => props.coin ?? loadedCoin.value);
const displayName = ref(props.coin?.displayName ?? "");
const description = ref(props.coin?.description ?? "");
const sortOrder = ref(props.coin?.sortOrder ?? 0);
const isFeatured = ref(props.coin?.isFeatured ?? false);
const versionNumber = ref(1);
const minAppVersion = ref("1.0.0");
const busy = ref(false);
const errorMessage = ref("");
const successMessage = ref("");
const saveState = ref("");
const currentVersion = computed(() => currentCoin.value ? activeVersion(currentCoin.value) : undefined);
const versionHistory = computed(() => currentCoin.value ? versionsDescending(currentCoin.value) : []);

watch(currentCoin, (coin) => {
  if (!coin) return;
  displayName.value = coin.displayName;
  description.value = coin.description ?? "";
  sortOrder.value = coin.sortOrder;
  isFeatured.value = coin.isFeatured;
  const maximum = Math.max(0, ...(coin.versions ?? []).map((version) => version.versionNumber));
  versionNumber.value = maximum + 1;
}, { immediate: true });

async function load() {
  if (props.coin) return;
  try {
    const coins = await adminCoins.listDrafts();
    loadedCoin.value = coins.find((coin) => coin.id === route.params.id);
    if (!loadedCoin.value) errorMessage.value = "未找到该硬币。";
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法加载该硬币。";
  }
}

async function save() {
  if (busy.value || !currentCoin.value) return;
  busy.value = true;
  errorMessage.value = "";
  successMessage.value = "";
  saveState.value = "正在保存…";
  const edited = { ...currentCoin.value, displayName: displayName.value, description: description.value, sortOrder: sortOrder.value, isFeatured: isFeatured.value };
  try {
    if (props.saveCoin) await props.saveCoin(edited);
    else await adminCoins.action({ action: "updateCoin", coinID: edited.id, displayName: edited.displayName, description: edited.description, sortOrder: edited.sortOrder, isFeatured: edited.isFeatured });
    saveState.value = "已保存";
  } catch {
    errorMessage.value = "无法保存更改。";
    saveState.value = "保存未完成";
  } finally { busy.value = false; }
}

function targetVersion(action: "publish" | "rollback", coin: AdminCoin) {
  const candidates = (coin.versions ?? []).filter((version) => {
    if (action === "publish") return version.status === "draft";
    return version.status === "published" && version.id !== coin.activeVersionID;
  });
  return candidates.sort((left, right) => right.versionNumber - left.versionNumber)[0];
}

async function transition(action: "publish" | "rollback") {
  if (busy.value || !currentCoin.value) return;
  successMessage.value = "";
  saveState.value = "";
  const version = targetVersion(action, currentCoin.value);
  if (!version) {
    errorMessage.value = action === "publish"
      ? "请先创建草稿版本再发布。"
      : "没有可回滚到的已发布旧版本。";
    return;
  }
  const confirmed = props.confirmAction ? await props.confirmAction(action) : window.confirm(action === "publish" ? "确定要发布此版本吗？" : "确定要回滚到此版本吗？");
  if (!confirmed) return;
  busy.value = true;
  errorMessage.value = "";
  saveState.value = "正在更新版本…";
  try {
    if (props.performAction) await props.performAction(action, version.id);
    else await adminCoins.action({ action: action === "publish" ? "publishVersion" : "rollbackVersion", coinID: currentCoin.value.id, versionID: version.id });
    await load();
    if (action === "publish") successMessage.value = "版本已发布。";
    saveState.value = "已保存";
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法更新版本。";
    saveState.value = "更新未完成";
  } finally { busy.value = false; }
}

function defaultPublicPreviewURL(path: string): string {
  return getSupabaseClient().storage.from("coin-previews").getPublicUrl(path).data.publicUrl;
}

function previewURL(path: string | undefined): string | undefined {
  return publicPreviewURL(path, props.makePublicPreviewURL ?? defaultPublicPreviewURL);
}

function fileName(path: string | undefined): string {
  return path?.split("/").at(-1) || "—";
}

function shortSHA(value: string | undefined): string {
  return value ? `${value.slice(0, 12)}…${value.slice(-8)}` : "—";
}

function storagePath(bucket: string, path: string | undefined): string {
  return path ? `${bucket}/${path}` : "—";
}

function publishedDate(value: string | null | undefined): string | undefined {
  if (!value || Number.isNaN(Date.parse(value))) return undefined;
  return new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium" }).format(new Date(value));
}

function handleUploadCompleted() {
  successMessage.value = "";
  saveState.value = "资源已更新";
  void load();
}

void load();
</script>

<template>
  <main class="admin-shell editor-page">
    <header class="editor-header">
      <button class="back" @click="router.push('/coins')">← 硬币</button>
      <div class="editor-heading"><p class="eyebrow">硬币编辑</p><h1>{{ currentCoin?.displayName || "硬币编辑" }}</h1><code>{{ currentCoin?.slug ?? "—" }}</code></div>
      <div class="header-status"><span v-if="currentCoin" class="status-badge" :class="`status-${currentCoin.status ?? 'unknown'}`">{{ coinStatusLabel(currentCoin.status) }}</span><span v-if="saveState" class="save-state">{{ saveState }}</span></div>
    </header>
    <p v-if="errorMessage" class="panel error" role="alert">{{ errorMessage }}</p>
    <p v-if="successMessage" class="panel success" role="status">{{ successMessage }}</p>
    <template v-if="currentCoin">
      <div class="editor-overview">
        <section class="panel basic-information">
          <div class="section-heading"><div><p class="eyebrow">基本信息</p><h2>展示与排序</h2></div><p class="muted">Slug 为固定标识，不能在此编辑。</p></div>
        <form @submit.prevent="save">
          <label>显示名称<input v-model="displayName" data-test="display-name" required /></label>
          <label>描述<textarea v-model="description" rows="4" /></label>
          <label>排序<input v-model.number="sortOrder" type="number" required /></label>
          <label class="checkbox"><input v-model="isFeatured" type="checkbox" /> 精选</label>
          <button class="primary-button" type="submit" :disabled="busy">{{ busy ? "正在保存…" : "保存更改" }}</button>
        </form>
        </section>

        <section class="panel current-version">
          <div class="section-heading"><div><p class="eyebrow">当前版本</p><h2>{{ currentVersion ? `v${currentVersion.versionNumber}` : "—" }}</h2></div><span class="asset-state" :class="assetState(currentCoin)">{{ assetStateLabel(assetState(currentCoin)) }}</span></div>
          <dl class="fact-list">
            <div><dt>状态</dt><dd>{{ currentVersion ? versionStatusLabel(currentVersion.status) : "—" }}</dd></div>
            <div v-if="publishedDate(currentVersion?.publishedAt)"><dt>发布日期</dt><dd>{{ publishedDate(currentVersion?.publishedAt) }}</dd></div>
            <div><dt>资源</dt><dd>{{ assetStateLabel(assetState(currentCoin)) }}</dd></div>
          </dl>
          <div class="actions">
            <button class="primary-button" data-test="publish" :disabled="busy" @click="transition('publish')">发布</button>
            <button class="secondary-button" data-test="rollback" :disabled="busy" @click="transition('rollback')">回滚</button>
          </div>
        </section>
      </div>

      <section class="panel assets-panel">
        <div class="section-heading"><div><p class="eyebrow">资源</p><h2>当前版本资源</h2></div><p class="muted">固定路径由服务端生成，只读。</p></div>
        <div class="assets-grid">
          <div class="preview-frame"><img v-if="previewURL(currentVersion?.previewPath)" :src="previewURL(currentVersion?.previewPath)" alt="当前版本预览" /><span v-else>预览不可用</span></div>
          <dl class="asset-facts">
            <div><dt>USDZ 模型</dt><dd>{{ fileName(currentVersion?.modelPath) }}</dd></div>
            <div><dt>WEBP 预览</dt><dd>{{ fileName(currentVersion?.previewPath) }}</dd></div>
            <div><dt>模型大小</dt><dd>{{ formatBytes(currentVersion?.modelByteSize) }}</dd></div>
            <div><dt>SHA-256</dt><dd><code>{{ shortSHA(currentVersion?.modelSHA256) }}</code></dd></div>
            <div><dt>最低 App 版本</dt><dd>{{ currentVersion?.minAppVersion ?? "—" }}</dd></div>
            <div><dt>资源 schema</dt><dd>{{ currentVersion?.assetSchemaVersion ?? "—" }}</dd></div>
            <div class="full-width"><dt>模型路径</dt><dd><code>{{ storagePath("coin-models-free", currentVersion?.modelPath) }}</code></dd></div>
            <div class="full-width"><dt>预览路径</dt><dd><code>{{ storagePath("coin-previews", currentVersion?.previewPath) }}</code></dd></div>
          </dl>
        </div>
        <div class="upload-section">
          <div><h3>创建下一个版本</h3><p class="muted">上传会创建新的不可变草稿版本，不会覆盖已发布资源。</p></div>
        <div class="version-controls">
          <label>下一个版本<input v-model.number="versionNumber" type="number" min="1" /></label>
          <label>最低应用版本<input v-model="minAppVersion" /></label>
        </div>
        <AssetUploadPanel :coin-i-d="currentCoin.id" :version-number="versionNumber" :min-app-version="minAppVersion" @completed="handleUploadCompleted" />
        </div>
      </section>

      <section class="panel version-history">
        <div class="section-heading"><div><p class="eyebrow">版本历史</p><h2>所有版本</h2></div><p class="muted">按版本号从新到旧排列。</p></div>
        <div class="history-scroll">
          <table>
            <caption>硬币版本历史</caption>
            <thead><tr><th>版本</th><th>状态</th><th>资源</th><th>模型大小</th><th>最低版本</th><th>发布日期</th><th>操作</th></tr></thead>
            <tbody><tr v-for="version in versionHistory" :key="version.id" data-test="version-history-row" :data-version="version.versionNumber" :class="{ active: version.id === currentCoin.activeVersionID }">
              <td><strong>v{{ version.versionNumber }}</strong><span v-if="version.id === currentCoin.activeVersionID" class="active-label">当前生效</span></td>
              <td><span class="status-badge" :class="`status-${version.status}`">{{ versionStatusLabel(version.status) }}</span></td>
              <td><code>{{ fileName(version.modelPath) }} · {{ fileName(version.previewPath) }}</code></td>
              <td>{{ formatBytes(version.modelByteSize) }}</td>
              <td>{{ version.minAppVersion ?? "—" }}</td>
              <td>{{ publishedDate(version.publishedAt) ?? "—" }}</td>
              <td class="row-actions">
                <button v-if="targetVersion('publish', currentCoin)?.id === version.id" class="text-button" :disabled="busy" @click="transition('publish')">发布此版本</button>
                <button v-else-if="targetVersion('rollback', currentCoin)?.id === version.id" class="text-button" :disabled="busy" @click="transition('rollback')">回滚到此版本</button>
                <span v-else>—</span>
              </td>
            </tr></tbody>
          </table>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.editor-page { padding-bottom: 56px; }
.editor-header { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; align-items: start; gap: 16px; margin-bottom: 24px; }
.back, .secondary-button, .text-button { border: 1px solid var(--admin-line); background: transparent; }
.back, button { min-height: 36px; border-radius: 8px; padding: 8px 12px; cursor: pointer; }
.back { color: var(--admin-muted); }
.editor-heading h1 { margin: 2px 0 5px; font-size: clamp(28px, 4vw, 36px); letter-spacing: -.03em; }
.editor-heading code { color: var(--admin-muted); }
.eyebrow { margin: 0 0 5px; color: var(--admin-gold); font-size: 12px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }
.header-status, .section-heading, .actions, .row-actions { display: flex; align-items: center; }
.header-status { justify-content: flex-end; flex-wrap: wrap; gap: 8px; }
.save-state { color: var(--admin-muted); font-size: 13px; }
.success, .error { margin-bottom: 14px; }
.success { border-color: rgba(207, 172, 105, .42); color: var(--admin-ivory); }
.editor-overview { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(280px, .8fr); gap: 18px; }
.panel + .panel, .editor-overview + .panel { margin-top: 18px; }
.section-heading { justify-content: space-between; gap: 18px; margin-bottom: 22px; }
.section-heading h2 { margin: 0; font-size: 19px; }
.section-heading > p { margin: 0; font-size: 13px; text-align: right; }
form, .version-controls { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
label { display: grid; gap: 7px; color: var(--admin-muted); font-size: 13px; }
form label:nth-child(2) { grid-column: 1 / -1; }
input, textarea { min-width: 0; border-radius: 8px; padding: 10px; }
.checkbox { display: flex; align-items: center; gap: 8px; }
.primary-button { border: 1px solid var(--admin-gold); background: var(--admin-gold); color: #18140d; font-weight: 700; }
.basic-information form > button { justify-self: start; }
.status-badge, .asset-state, .active-label { display: inline-flex; align-items: center; width: fit-content; min-height: 24px; border: 1px solid var(--admin-line); border-radius: 999px; padding: 2px 8px; font-size: 12px; white-space: nowrap; }
.status-published, .asset-state.ready, .active-label { border-color: rgba(207, 172, 105, .55); color: var(--admin-ivory); }
.status-draft, .asset-state.incomplete { color: var(--admin-muted); }
.status-hidden { color: var(--admin-muted); }
.fact-list, .asset-facts { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin: 0; }
.fact-list div, .asset-facts div { min-width: 0; }
dt { margin-bottom: 4px; color: var(--admin-muted); font-size: 12px; }
dd { margin: 0; overflow-wrap: anywhere; }
.actions { flex-wrap: wrap; gap: 8px; margin-top: 22px; }
.assets-grid { display: grid; grid-template-columns: 180px minmax(0, 1fr); gap: 24px; }
.preview-frame { display: grid; min-height: 180px; place-items: center; overflow: hidden; border: 1px solid var(--admin-line); border-radius: 12px; color: var(--admin-muted); background: #121210; }
.preview-frame img { width: 100%; height: 100%; object-fit: cover; }
.full-width { grid-column: 1 / -1; }
.upload-section { display: grid; grid-template-columns: minmax(200px, .7fr) minmax(0, 1.3fr); gap: 24px; margin-top: 28px; padding-top: 22px; border-top: 1px solid var(--admin-line); }
.upload-section h3 { margin: 0 0 6px; font-size: 16px; }
.upload-section p { margin: 0; font-size: 13px; }
.assets-panel :deep(.upload-panel) { margin-top: 20px; }
.history-scroll { overflow-x: auto; }
table { width: 100%; min-width: 820px; border-collapse: collapse; }
caption { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
th, td { padding: 12px 10px; border-bottom: 1px solid var(--admin-line); text-align: left; vertical-align: middle; }
th { color: var(--admin-muted); font-size: 12px; font-weight: 600; }
tbody tr:last-child td { border-bottom: 0; }
tbody tr.active { background: rgba(207, 172, 105, .06); }
td strong, td .active-label { display: block; }
td .active-label { margin-top: 5px; }
.row-actions { justify-content: flex-end; gap: 8px; white-space: nowrap; }
.text-button { min-height: 32px; padding: 6px 8px; }
button:disabled { cursor: default; opacity: .52; }

@media (max-width: 760px) {
  .editor-header { grid-template-columns: 1fr auto; }
  .editor-heading { grid-column: 1 / -1; grid-row: 2; }
  .header-status { align-items: flex-end; flex-direction: column; }
  .editor-overview, .assets-grid, .upload-section { grid-template-columns: 1fr; }
  .section-heading { align-items: flex-start; flex-direction: column; gap: 7px; }
  .section-heading > p { text-align: left; }
  .preview-frame { min-height: 220px; max-width: 320px; }
  .upload-section { gap: 18px; }
  .fact-list, .asset-facts, form, .version-controls { grid-template-columns: 1fr; }
  form label:nth-child(2), .full-width { grid-column: auto; }
}
</style>
