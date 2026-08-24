<script setup lang="ts">
import { ref } from "vue";
import {
  uploadVersionAssets,
  adminCoins,
  putSignedFile,
  validateModelFile,
  validatePreviewFile,
} from "../services/adminCoins";

interface UploadPayload { model: File; preview: File }
const props = withDefaults(defineProps<{
  coinID?: string;
  versionNumber?: number;
  minAppVersion?: string;
  upload?: (payload: UploadPayload) => Promise<void>;
}>(), { coinID: "", versionNumber: 1, minAppVersion: "1.0.0", upload: undefined });
const emit = defineEmits<{ completed: [] }>();
const model = ref<File>();
const preview = ref<File>();
const uploading = ref(false);
const progress = ref(0);
const errorMessage = ref("");

function select(event: Event, target: "model" | "preview") {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (target === "model") model.value = file;
  else preview.value = file;
}

async function submit() {
  if (uploading.value) return;
  if (!model.value) {
    window.alert("USDZ 文件大小无效");
    return;
  }

  const modelValidation = validateModelFile(model.value);
  if (!modelValidation.ok) {
    window.alert(modelValidation.error);
    return;
  }

  if (!preview.value) {
    window.alert("WEBP 文件大小无效");
    return;
  }

  const previewValidation = validatePreviewFile(preview.value);
  if (!previewValidation.ok) {
    window.alert(previewValidation.error);
    return;
  }

  uploading.value = true;
  progress.value = 10;
  errorMessage.value = "";
  try {
    if (props.upload) await props.upload({ model: model.value, preview: preview.value });
    else {
      await uploadVersionAssets({
        coinID: props.coinID,
        versionNumber: props.versionNumber,
        minAppVersion: props.minAppVersion,
        model: model.value,
        preview: preview.value,
      }, { action: adminCoins.action, upload: putSignedFile });
    }
    progress.value = 100;
    emit("completed");
  } catch {
    errorMessage.value = "无法上传这些资源。";
  } finally { uploading.value = false; }
}
</script>

<template>
  <section>
    <h3>版本资源</h3>
    <form @submit.prevent="submit">
      <label>USDZ 模型<input data-test="model" type="file" accept=".usdz" :disabled="uploading" @change="select($event, 'model')" /></label>
      <label>WEBP 预览图<input data-test="preview" type="file" accept=".webp" :disabled="uploading" @change="select($event, 'preview')" /></label>
      <progress v-if="uploading || progress === 100" :value="progress" max="100" />
      <button type="submit" :disabled="uploading">{{ uploading ? "正在上传…" : "创建版本并上传" }}</button>
    </form>
    <p v-if="errorMessage" class="error">{{ errorMessage }}</p>
  </section>
</template>

<style scoped>
form { display: grid; gap: 12px; }
label { display: grid; gap: 7px; color: #525964; }
button { justify-self: start; border: 0; border-radius: 7px; background: #25282d; color: white; padding: 10px 14px; }
button:disabled { opacity: .5; }
</style>
