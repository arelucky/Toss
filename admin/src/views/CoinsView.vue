<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { adminCoins, AdminCoinsError, type AdminCoin, validateCoinSlug } from "../services/adminCoins";

const props = withDefaults(defineProps<{ loadCoins?: () => Promise<AdminCoin[]> }>(), { loadCoins: undefined });
const router = useRouter();
const coins = ref<AdminCoin[]>([]);
const loading = ref(true);
const errorMessage = ref("");
const creating = ref(false);
const slug = ref("");
const displayName = ref("");

async function load() {
  loading.value = true;
  errorMessage.value = "";
  try {
    coins.value = await (props.loadCoins ?? adminCoins.listDrafts)();
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法加载硬币。";
  } finally { loading.value = false; }
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
  } finally { creating.value = false; }
}

async function hideCoin(coinID: string) {
  if (!window.confirm("确定要隐藏此硬币吗？现有资源将会保留。")) return;
  try {
    await adminCoins.action({ action: "hideCoin", coinID });
    await load();
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "无法隐藏硬币。";
  }
}

function statusLabel(status?: string) {
  if (status === "draft") return "草稿";
  if (status === "published") return "已发布";
  if (status === "hidden") return "已隐藏";
  return "未知";
}

onMounted(load);
</script>

<template>
  <main class="admin-shell">
    <header><div><p class="muted">Toss 管理后台</p><h1>硬币</h1></div></header>
    <p v-if="errorMessage" class="panel error">{{ errorMessage }}</p>
    <section class="panel create-panel">
      <h2>创建硬币</h2>
      <form @submit.prevent="createCoin">
        <input v-model.trim="slug" placeholder="例如：classic-coin" aria-label="硬币标识" required />
        <input v-model.trim="displayName" placeholder="硬币名称" aria-label="硬币名称" required />
        <button type="submit" :disabled="creating">{{ creating ? "正在创建…" : "创建" }}</button>
      </form>
    </section>
    <section class="panel list-panel">
      <p v-if="loading" class="muted">正在加载…</p>
      <p v-else-if="coins.length === 0" class="muted">尚无硬币。</p>
      <table v-else>
        <thead><tr><th>名称</th><th>标识</th><th>状态</th><th></th></tr></thead>
        <tbody><tr v-for="coin in coins" :key="coin.id">
          <td>{{ coin.displayName }}</td><td>{{ coin.slug }}</td><td>{{ statusLabel(coin.status) }}</td>
          <td><button @click="router.push(`/coins/${coin.id}`)">编辑</button><button @click="hideCoin(coin.id)">隐藏</button></td>
        </tr></tbody>
      </table>
    </section>
  </main>
</template>

<style scoped>
header { display: flex; justify-content: space-between; align-items: end; margin-bottom: 24px; }
h1, header p { margin: 0; }
h2 { margin-top: 0; font-size: 17px; }
.create-panel form { display: grid; grid-template-columns: 1fr 1.5fr auto; gap: 12px; }
input { height: 40px; border: 1px solid #d5d9de; border-radius: 7px; padding: 0 11px; }
button { border: 1px solid #d5d9de; background: white; border-radius: 7px; padding: 9px 14px; cursor: pointer; }
.create-panel button { background: #25282d; color: white; }
.list-panel { margin-top: 18px; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: 14px 8px; border-bottom: 1px solid #eceef0; text-align: left; }
td:last-child { text-align: right; display: flex; justify-content: end; gap: 8px; }
</style>
