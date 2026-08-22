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
type AuthStateListener = (event: string, session: unknown | null) => void;
type AuthStateSubscriber = (listener: AuthStateListener) => unknown;

export function authCallbackFragmentReplacement(
  location: Pick<Location, "pathname" | "search" | "hash">,
): string | null {
  const fragment = location.hash.startsWith("#") ? location.hash.slice(1) : location.hash;
  const fragmentParameters = new URLSearchParams(fragment);

  if (!fragmentParameters.has("access_token") && !fragmentParameters.has("refresh_token")) {
    return null;
  }

  return `${location.pathname}${location.search}`;
}

export function subscribeToAuthCallbackFragmentCleanup(
  subscribe: AuthStateSubscriber,
  location: Pick<Location, "pathname" | "search" | "hash"> = window.location,
  history: Pick<History, "replaceState" | "state"> = window.history,
) {
  return subscribe((_event, session) => {
    if (!session) return;

    const replacement = authCallbackFragmentReplacement(location);
    if (replacement) {
      history.replaceState(history.state, "", replacement);
    }
  });
}

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
    const session = await getSession();
    if (!session) return "/login";

    const replacement = authCallbackFragmentReplacement(window.location);
    if (replacement) {
      window.history.replaceState(window.history.state, "", replacement);
    }

    return true;
  });
  return adminRouter;
}

export const router = createAdminRouter(createWebHistory(), async () => {
  const { data } = await getSupabaseClient().auth.getSession();
  return data.session;
});
