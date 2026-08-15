<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import AssetUploadPanel from "../components/AssetUploadPanel.vue";
import { adminCoins, AdminCoinsError, type AdminCoin } from "../services/adminCoins";

const props = withDefaults(defineProps<{
  coin?: AdminCoin;
  saveCoin?: (coin: AdminCoin) => Promise<void>;
  confirmAction?: (action: "publish" | "rollback") => Promise<boolean>;
  performAction?: (action: "publish" | "rollback") => Promise<void>;
}>(), { coin: undefined, saveCoin: undefined, confirmAction: undefined, performAction: undefined });
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
    if (!loadedCoin.value) errorMessage.value = "Coin could not be found.";
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "Could not load this coin.";
  }
}

async function save() {
  if (busy.value || !currentCoin.value) return;
  busy.value = true;
  errorMessage.value = "";
  const edited = { ...currentCoin.value, displayName: displayName.value, description: description.value, sortOrder: sortOrder.value, isFeatured: isFeatured.value };
  try {
    if (props.saveCoin) await props.saveCoin(edited);
    else await adminCoins.action({ action: "updateCoin", coinID: edited.id, displayName: edited.displayName, description: edited.description, sortOrder: edited.sortOrder, isFeatured: edited.isFeatured });
  } catch {
    errorMessage.value = "Could not save changes.";
  } finally { busy.value = false; }
}

async function transition(action: "publish" | "rollback") {
  if (busy.value || !currentCoin.value) return;
  const version = currentCoin.value.versions?.[0];
  if (!version) { errorMessage.value = "Create a version first."; return; }
  const confirmed = props.confirmAction ? await props.confirmAction(action) : window.confirm(`${action === "publish" ? "Publish" : "Roll back to"} this version?`);
  if (!confirmed) return;
  busy.value = true;
  errorMessage.value = "";
  try {
    if (props.performAction) await props.performAction(action);
    else await adminCoins.action({ action: action === "publish" ? "publishVersion" : "rollbackVersion", coinID: currentCoin.value.id, versionID: version.id });
    await load();
  } catch (error) {
    errorMessage.value = error instanceof AdminCoinsError ? error.message : "Could not update the version.";
  } finally { busy.value = false; }
}

void load();
</script>

<template>
  <main class="admin-shell">
    <button class="back" @click="router.push('/coins')">← Coins</button>
    <h1>{{ currentCoin?.displayName || "Coin editor" }}</h1>
    <p v-if="errorMessage" class="panel error">{{ errorMessage }}</p>
    <template v-if="currentCoin">
      <section class="panel">
        <h2>Details</h2>
        <form @submit.prevent="save">
          <label>Display name<input v-model="displayName" data-test="display-name" required /></label>
          <label>Description<textarea v-model="description" rows="4" /></label>
          <label>Sort order<input v-model.number="sortOrder" type="number" required /></label>
          <label class="checkbox"><input v-model="isFeatured" type="checkbox" /> Featured</label>
          <button type="submit" :disabled="busy">Save changes</button>
        </form>
      </section>
      <section class="panel versions">
        <h2>Versions</h2>
        <div class="version-controls">
          <label>Next version<input v-model.number="versionNumber" type="number" min="1" /></label>
          <label>Minimum app version<input v-model="minAppVersion" /></label>
        </div>
        <AssetUploadPanel :coin-i-d="currentCoin.id" :version-number="versionNumber" :min-app-version="minAppVersion" @completed="load" />
        <div class="actions">
          <button data-test="publish" :disabled="busy" @click="transition('publish')">Publish</button>
          <button data-test="rollback" :disabled="busy" @click="transition('rollback')">Rollback</button>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.back { border: 0; background: transparent; color: #535b66; padding: 0; cursor: pointer; }
h1 { margin: 14px 0 24px; }
h2 { margin-top: 0; font-size: 18px; }
.panel + .panel { margin-top: 18px; }
form, .version-controls { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
label { display: grid; gap: 7px; color: #535b66; }
label:nth-child(2) { grid-column: 1 / -1; }
input, textarea { border: 1px solid #d5d9de; border-radius: 7px; padding: 10px; }
.checkbox { display: flex; align-items: center; gap: 8px; }
form button, .actions button { justify-self: start; border: 0; border-radius: 7px; background: #25282d; color: white; padding: 10px 14px; }
.versions > :deep(section) { margin-top: 24px; border-top: 1px solid #eceef0; padding-top: 20px; }
.actions { display: flex; gap: 10px; margin-top: 22px; }
</style>
