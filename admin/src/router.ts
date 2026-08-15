import {
  createRouter,
  createWebHistory,
  type RouterHistory,
} from "vue-router";
import { getSupabaseClient } from "./lib/supabase";
import LoginView from "./views/LoginView.vue";
import CoinsView from "./views/CoinsView.vue";
import CoinEditorView from "./views/CoinEditorView.vue";

type SessionReader = () => Promise<unknown | null>;

export function createAdminRouter(history: RouterHistory, getSession: SessionReader) {
  const adminRouter = createRouter({
    history,
    routes: [
      { path: "/", redirect: "/coins" },
      { path: "/login", component: LoginView },
      { path: "/coins", component: CoinsView, meta: { requiresAuth: true } },
      { path: "/coins/:id", component: CoinEditorView, meta: { requiresAuth: true } },
    ],
  });

  adminRouter.beforeEach(async (to) => {
    if (!to.meta.requiresAuth) return true;
    return (await getSession()) ? true : "/login";
  });
  return adminRouter;
}

export const router = createAdminRouter(createWebHistory(), async () => {
  const { data } = await getSupabaseClient().auth.getSession();
  return data.session;
});
