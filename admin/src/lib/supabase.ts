import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let cachedClient: SupabaseClient | undefined;

export function getSupabaseClient() {
  if (cachedClient) return cachedClient;

  const supabaseURL = import.meta.env.VITE_SUPABASE_URL?.trim();
  const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!supabaseURL || !publishableKey) {
    throw new Error("缺少 Supabase 管理后台配置。");
  }

  cachedClient = createClient(supabaseURL, publishableKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });
  return cachedClient;
}
