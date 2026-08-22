import { createMemoryHistory } from "vue-router";
import { createAdminRouter } from "./router";

describe("admin router", () => {
  it("redirects unauthenticated admin routes to login", async () => {
    const router = createAdminRouter(createMemoryHistory(), async () => null);
    await router.push("/coins");
    await router.isReady();
    expect(router.currentRoute.value.fullPath).toBe("/login");
  });

  it("removes auth callback fragments after an authenticated session is read", async () => {
    window.history.replaceState(null, "", "/coins?x=1#access_token=redacted");
    const router = createAdminRouter(createMemoryHistory(), async () => ({}));

    await router.push("/coins?x=1");
    await router.isReady();

    expect(`${window.location.pathname}${window.location.search}${window.location.hash}`).toBe(
      "/coins?x=1",
    );
  });

  it("keeps ordinary page fragments after an authenticated session is read", async () => {
    window.history.replaceState(null, "", "/coins?x=1#details");
    const router = createAdminRouter(createMemoryHistory(), async () => ({}));

    await router.push("/coins?x=1");
    await router.isReady();

    expect(`${window.location.pathname}${window.location.search}${window.location.hash}`).toBe(
      "/coins?x=1#details",
    );
  });
});
