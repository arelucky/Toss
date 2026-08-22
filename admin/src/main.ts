import { createApp } from "vue";
import ElementPlus from "element-plus";
import "element-plus/dist/index.css";
import App from "./App.vue";
import { router, subscribeToAuthCallbackFragmentCleanup } from "./router";
import { getSupabaseClient } from "./lib/supabase";

const supabaseClient = getSupabaseClient();
subscribeToAuthCallbackFragmentCleanup((listener) => supabaseClient.auth.onAuthStateChange(listener));
createApp(App).use(ElementPlus).use(router).mount("#app");
