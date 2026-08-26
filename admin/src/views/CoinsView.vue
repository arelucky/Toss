<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { getSupabaseClient } from "../lib/supabase";
import {
  activeVersion,
  assetState,
  assetStateLabel,
  coinStatusLabel,
  publicPreviewURL,
} from "../presentation/coinPresentation";
import { adminCoins, AdminCoinsError, type AdminCoin, validateCoinSlug } from "../services/adminCoins";

type CoinStatusFilter = "all" | "draft" | "published" | "hidden";

const props = withDefaults(defineProps<{
  loadCoins?: () => Promise<AdminCoin[]>;
  makePublicPreviewURL?: (path: string) => string;
}>(), { loadCoins: undefined, makePublicPreviewURL: undefined });

const router = useRouter();
const coins = ref<AdminCoin[]>([]);
const loading = ref(true);
const errorMessage = ref("");
const creating = ref(false);
const createOpen = ref(false);
const actionCoinID = ref<string>();
const selectedStatus = ref<CoinStatusFilter>("all");
const slug = ref("");
const displayName = ref("");

const filters: Array<{ value: CoinStatusFilter; label: string }> = [
  { value: "all", label: "全部" },
  { value: "draft", label: "草稿" },
  { value: "published", label: "已发布" },
  { value: "hidden", label: "已隐藏" },
];

const filteredCoins = computed(() => selectedStatus.value === "all"
  ? coins.value
  : coins.value.filter((coin) => coin.status === selectedStatus.value));

function defaultPublicPreviewURL(path: string): string {
  return getSupabaseClient().storage.from("coin-previews").getPublicUrl(path).data.publicUrl;
}

function previewURL(coin: AdminCoin): string | undefined {
  return publicPreviewURL(
    activeVersion(coin)?.previewPath,
    props.makePublicPreviewURL ?? defaultPublicPreviewURL,
  );
}

async function load(options: { preserveCatalog?: boolean } = {}) {
  const preserveCatalog = options.preserveCatalog ?? false;
  if (!preserveCatalog) loading.value = true;
  errorMessage.value = "";
  try {
    coins.value = await (props.loadCoins ?? adminCoins.listDrafts)();
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法加载硬币。";
  } finally {
    if (!preserveCatalog) loading.value = false;
  }
}

async function createCoin() {
  if (creating.value) return;
  if (!validateCoinSlug(slug.value)) {
    window.alert("硬币标识只能使用 3–64 个小写字母、数字或连字符。");
    return;
  }

  creating.value = true;
  errorMessage.value = "";
  try {
    const coin = await adminCoins.action<AdminCoin>({ action: "createCoin", slug: slug.value, displayName: displayName.value });
    await router.push(`/coins/${coin.id}`);
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法创建硬币。";
  } finally {
    creating.value = false;
  }
}

async function hideCoin(coinID: string) {
  if (actionCoinID.value === coinID || !window.confirm("确定要隐藏此硬币吗？现有资源将会保留。")) return;
  actionCoinID.value = coinID;
  errorMessage.value = "";
  try {
    await adminCoins.action({ action: "hideCoin", coinID });
    await load({ preserveCatalog: true });
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法隐藏硬币。";
  } finally {
    actionCoinID.value = undefined;
  }
}

async function restoreCoin(coinID: string) {
  if (actionCoinID.value === coinID || !window.confirm("确定要恢复此硬币吗？")) return;
  actionCoinID.value = coinID;
  errorMessage.value = "";
  try {
    await adminCoins.action({ action: "restoreCoin", coinID });
    await load({ preserveCatalog: true });
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法恢复硬币。";
  } finally {
    actionCoinID.value = undefined;
  }
}

onMounted(load);
</script>

<template>
  <main class="admin-shell catalog-page">
    <header class="catalog-header">
      <div>
        <p class="eyebrow">Toss 管理后台</p>
        <h1>硬币目录</h1>
        <p class="muted intro">管理发布状态、版本与展示顺序。</p>
      </div>
      <div class="header-actions">
        <button class="secondary-button" data-test="reload-coins" :disabled="loading" @click="load({ preserveCatalog: coins.length > 0 })">
          {{ errorMessage ? "重试" : "刷新" }}
        </button>
        <button class="primary-button" data-test="create-toggle" :aria-expanded="createOpen" @click="createOpen = !createOpen">
          {{ createOpen ? "收起创建" : "新建硬币" }}
        </button>
      </div>
    </header>

    <section v-if="createOpen" class="panel create-panel" aria-labelledby="create-heading">
      <div><h2 id="create-heading">创建硬币</h2><p class="muted">创建后将在编辑页补充版本与资源。</p></div>
      <form @submit.prevent="createCoin">
        <label>硬币标识<input v-model.trim="slug" placeholder="例如：classic-coin" aria-label="硬币标识" required /></label>
        <label>硬币名称<input v-model.trim="displayName" placeholder="硬币名称" aria-label="硬币名称" required /></label>
        <button class="primary-button" type="submit" :disabled="creating">{{ creating ? "正在创建…" : "创建硬币" }}</button>
      </form>
    </section>

    <section class="catalog-toolbar" aria-label="状态筛选">
      <div class="status-filters" role="group" aria-label="硬币状态">
        <button
          v-for="filter in filters"
          :key="filter.value"
          class="filter-button"
          :class="{ active: selectedStatus === filter.value }"
          :aria-pressed="selectedStatus === filter.value"
          :data-test="`status-filter-${filter.value}`"
          @click="selectedStatus = filter.value"
        >{{ filter.label }}</button>
      </div>
      <p class="muted">{{ filteredCoins.length }} 枚硬币</p>
    </section>

    <p v-if="errorMessage" class="panel error" role="alert">{{ errorMessage }}</p>

    <section class="panel catalog-panel" aria-live="polite">
      <div v-if="loading" class="catalog-skeleton" aria-label="正在加载硬币目录">
        <div v-for="index in 5" :key="index" class="skeleton-row"><span /><span /><span /><span /></div>
      </div>
      <template v-else-if="filteredCoins.length">
        <div class="table-scroll">
          <table>
            <caption>硬币目录</caption>
            <thead><tr><th>预览</th><th>名称 / 标识</th><th>状态</th><th>当前版本</th><th>资源</th><th>排序</th><th>精选</th><th>操作</th></tr></thead>
            <tbody>
              <tr v-for="coin in filteredCoins" :key="coin.id" :class="{ 'catalog-row--hidden': coin.status === 'hidden' }">
                <td><div class="coin-preview"><img v-if="previewURL(coin)" :src="previewURL(coin)" alt="" /><span v-else>—</span></div></td>
                <td><strong>{{ coin.displayName }}</strong><code>{{ coin.slug ?? "—" }}</code></td>
                <td><span class="status-badge" :class="`status-${coin.status ?? 'unknown'}`">{{ coinStatusLabel(coin.status) }}</span></td>
                <td>{{ activeVersion(coin) ? `v${activeVersion(coin)?.versionNumber}` : "—" }}</td>
                <td><span class="asset-state" :class="assetState(coin)">{{ assetStateLabel(assetState(coin)) }}</span></td>
                <td class="number">{{ coin.sortOrder }}</td>
                <td>{{ coin.isFeatured ? "是" : "否" }}</td>
                <td class="row-actions">
                  <button class="text-button" @click="router.push(`/coins/${coin.id}`)">编辑</button>
                  <button v-if="coin.status === 'published'" class="text-button" :disabled="actionCoinID === coin.id" @click="hideCoin(coin.id)">{{ actionCoinID === coin.id ? "处理中…" : "隐藏" }}</button>
                  <button v-else-if="coin.status === 'hidden'" class="text-button" :disabled="actionCoinID === coin.id" @click="restoreCoin(coin.id)">{{ actionCoinID === coin.id ? "处理中…" : "恢复" }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="catalog-cards">
          <article v-for="coin in filteredCoins" :key="coin.id" class="catalog-card" :class="{ 'catalog-row--hidden': coin.status === 'hidden' }">
            <div class="coin-preview"><img v-if="previewURL(coin)" :src="previewURL(coin)" alt="" /><span v-else>—</span></div>
            <div class="card-primary"><strong>{{ coin.displayName }}</strong><span class="status-badge" :class="`status-${coin.status ?? 'unknown'}`">{{ coinStatusLabel(coin.status) }}</span><code>{{ coin.slug ?? "—" }}</code></div>
            <div class="card-meta"><span>{{ activeVersion(coin) ? `当前 v${activeVersion(coin)?.versionNumber}` : "无当前版本" }}</span><span :class="assetState(coin)">{{ assetStateLabel(assetState(coin)) }}</span><span>排序 {{ coin.sortOrder }}</span><span>精选 {{ coin.isFeatured ? "是" : "否" }}</span></div>
            <div class="row-actions">
              <button class="text-button" @click="router.push(`/coins/${coin.id}`)">编辑</button>
              <button v-if="coin.status === 'published'" class="text-button" :disabled="actionCoinID === coin.id" @click="hideCoin(coin.id)">{{ actionCoinID === coin.id ? "处理中…" : "隐藏" }}</button>
              <button v-else-if="coin.status === 'hidden'" class="text-button" :disabled="actionCoinID === coin.id" @click="restoreCoin(coin.id)">{{ actionCoinID === coin.id ? "处理中…" : "恢复" }}</button>
            </div>
          </article>
        </div>
      </template>
      <div v-else class="empty-state">
        <h2>{{ coins.length ? "此状态下暂无硬币。" : "尚无硬币。" }}</h2>
        <p class="muted">{{ coins.length ? "切换筛选条件，或创建一枚新的硬币。" : "创建第一枚硬币即可开始。" }}</p>
      </div>
    </section>
  </main>
</template>

<style scoped>
.catalog-page { padding-bottom: 56px; }
.catalog-header, .catalog-toolbar, .header-actions, .status-filters, .row-actions { display: flex; align-items: center; }
.catalog-header { justify-content: space-between; gap: 24px; margin-bottom: 24px; }
.eyebrow { margin: 0 0 8px; color: var(--admin-gold); font-size: 12px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }
h1, h2, p { margin-top: 0; }
h1 { margin-bottom: 8px; font-size: clamp(28px, 4vw, 38px); letter-spacing: -.03em; }
.intro { margin-bottom: 0; }
.header-actions, .row-actions { gap: 8px; }
button { min-height: 36px; border-radius: 8px; padding: 8px 12px; cursor: pointer; }
button:disabled { cursor: default; opacity: .52; }
.primary-button { border: 1px solid var(--admin-gold); background: var(--admin-gold); color: #18140d; font-weight: 700; }
.secondary-button, .filter-button, .text-button { border: 1px solid var(--admin-line); background: transparent; }
.text-button { padding-inline: 8px; }
.create-panel { display: grid; grid-template-columns: minmax(200px, .7fr) minmax(0, 1.3fr); gap: 28px; margin-bottom: 18px; }
.create-panel h2 { margin-bottom: 6px; font-size: 18px; }
.create-panel p { margin-bottom: 0; }
.create-panel form { display: grid; grid-template-columns: 1fr 1fr auto; align-items: end; gap: 12px; }
label { display: grid; gap: 7px; color: var(--admin-muted); font-size: 13px; }
input { min-width: 0; height: 40px; border-radius: 8px; padding: 0 11px; }
.catalog-toolbar { justify-content: space-between; gap: 16px; margin: 18px 0 12px; }
.catalog-toolbar > p { margin: 0; font-size: 13px; }
.status-filters { gap: 6px; overflow-x: auto; padding-bottom: 2px; }
.filter-button { white-space: nowrap; color: var(--admin-muted); }
.filter-button.active { border-color: var(--admin-gold); color: var(--admin-ivory); box-shadow: inset 0 0 0 1px rgba(207, 172, 105, .22); }
.error { margin: 0 0 12px; border-color: rgba(230, 170, 160, .4); }
.catalog-panel { padding: 0; overflow: hidden; }
.table-scroll { overflow-x: auto; }
table { width: 100%; min-width: 890px; border-collapse: collapse; }
caption { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
th, td { border-bottom: 1px solid var(--admin-line); padding: 12px 14px; text-align: left; vertical-align: middle; }
th { color: var(--admin-muted); font-size: 12px; font-weight: 600; letter-spacing: .04em; white-space: nowrap; }
tbody tr:last-child td { border-bottom: 0; }
td strong, td code { display: block; }
td strong { font-size: 14px; }
code { margin-top: 4px; color: var(--admin-muted); font-size: 12px; }
.coin-preview { display: grid; width: 40px; height: 40px; place-items: center; overflow: hidden; border: 1px solid var(--admin-line); border-radius: 50%; color: var(--admin-muted); background: #121210; }
.coin-preview img { width: 100%; height: 100%; object-fit: cover; }
.status-badge, .asset-state { display: inline-flex; align-items: center; min-height: 24px; border: 1px solid var(--admin-line); border-radius: 999px; padding: 2px 8px; font-size: 12px; white-space: nowrap; }
.status-published, .asset-state.ready { border-color: rgba(207, 172, 105, .55); color: var(--admin-ivory); }
.status-hidden { color: var(--admin-muted); }
.status-draft, .asset-state.incomplete { color: var(--admin-muted); }
.catalog-row--hidden { opacity: .68; }
.number { font-variant-numeric: tabular-nums; }
.row-actions { justify-content: flex-end; white-space: nowrap; }
.catalog-cards { display: none; }
.catalog-skeleton { padding: 8px 0; }
.skeleton-row { display: grid; grid-template-columns: 48px 2fr 1fr 1fr; gap: 16px; align-items: center; min-height: 58px; padding: 0 14px; border-bottom: 1px solid var(--admin-line); }
.skeleton-row span { height: 13px; border-radius: 999px; background: linear-gradient(90deg, #20201d, #292822, #20201d); }
.skeleton-row span:first-child { width: 40px; height: 40px; border-radius: 50%; }
.empty-state { padding: 56px 24px; text-align: center; }
.empty-state h2 { margin-bottom: 8px; font-size: 17px; }
.empty-state p { margin-bottom: 0; }

@media (max-width: 760px) {
  .catalog-header { align-items: flex-start; flex-direction: column; }
  .header-actions { width: 100%; }
  .header-actions button { flex: 1; }
  .create-panel { grid-template-columns: 1fr; gap: 18px; }
  .create-panel form { grid-template-columns: 1fr; }
  .create-panel form button { width: 100%; }
  .catalog-toolbar { align-items: flex-start; flex-direction: column; }
  .table-scroll { display: none; }
  .catalog-cards { display: grid; }
  .catalog-card { display: grid; grid-template-columns: 48px minmax(0, 1fr); gap: 10px 12px; padding: 16px; border-bottom: 1px solid var(--admin-line); }
  .catalog-card:last-child { border-bottom: 0; }
  .catalog-card .coin-preview { width: 48px; height: 48px; grid-row: span 2; }
  .card-primary { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: start; gap: 4px 8px; }
  .card-primary code { grid-column: 1 / -1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .card-meta { display: flex; flex-wrap: wrap; gap: 5px 10px; color: var(--admin-muted); font-size: 12px; }
  .card-meta .ready { color: var(--admin-ivory); }
  .catalog-card .row-actions { grid-column: 1 / -1; justify-content: flex-start; margin-top: 2px; }
}
</style>
