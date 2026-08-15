import { createMemoryHistory } from "vue-router";
import { createAdminRouter } from "./router";

describe("admin router", () => {
  it("redirects unauthenticated admin routes to login", async () => {
    const router = createAdminRouter(createMemoryHistory(), async () => null);
    await router.push("/coins");
    await router.isReady();
    expect(router.currentRoute.value.fullPath).toBe("/login");
  });
});
