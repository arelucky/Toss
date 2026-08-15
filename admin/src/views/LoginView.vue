<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import { getSupabaseClient } from "../lib/supabase";

const props = withDefaults(defineProps<{ sendOtp?: (email: string) => Promise<void> }>(), {
  sendOtp: undefined,
});
const router = useRouter();
const email = ref("");
const submitting = ref(false);
const sent = ref(false);
const errorMessage = ref("");

async function submit() {
  if (submitting.value) return;
  submitting.value = true;
  errorMessage.value = "";
  try {
    if (props.sendOtp) await props.sendOtp(email.value);
    else {
      const { error } = await getSupabaseClient().auth.signInWithOtp({
        email: email.value,
        options: { emailRedirectTo: `${window.location.origin}/coins` },
      });
      if (error) throw error;
    }
    sent.value = true;
    if (!props.sendOtp) await router.replace("/coins");
  } catch {
    errorMessage.value = "Could not send the sign-in link.";
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <main class="login-page">
    <section class="panel login-panel">
      <p class="eyebrow">Toss</p>
      <h1>Coin administration</h1>
      <p class="muted">Enter the administrator email to receive a one-time sign-in link.</p>
      <form @submit.prevent="submit">
        <label for="email">Email</label>
        <input id="email" v-model.trim="email" type="email" autocomplete="email" required />
        <button type="submit" :disabled="submitting">{{ submitting ? "Sending…" : "Send sign-in link" }}</button>
      </form>
      <p v-if="sent" class="success">Check your inbox for the sign-in link.</p>
      <p v-if="errorMessage" class="error">{{ errorMessage }}</p>
    </section>
  </main>
</template>

<style scoped>
.login-page { min-height: 100vh; display: grid; place-items: center; }
.login-panel { width: 420px; }
.eyebrow { margin: 0; color: #9a7616; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
h1 { margin: 8px 0; }
form { display: grid; gap: 10px; margin-top: 24px; }
input { height: 42px; border: 1px solid #cfd4da; border-radius: 8px; padding: 0 12px; }
button { height: 42px; border: 0; border-radius: 8px; color: white; background: #24272c; cursor: pointer; }
button:disabled { opacity: .55; cursor: default; }
.success { color: #28764a; }
</style>
