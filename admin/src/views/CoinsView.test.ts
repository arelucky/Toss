import { mount } from "@vue/test-utils";
import CoinsView from "./CoinsView.vue";
import { AdminCoinsError } from "../services/adminCoins";

describe("CoinsView", () => {
  it("shows a safe access denied state for 403", async () => {
    const wrapper = mount(CoinsView, {
      props: { loadCoins: vi.fn().mockRejectedValue(new AdminCoinsError(403, "You do not have access to this console.")) },
    });
    await Promise.resolve();
    await Promise.resolve();
    expect(wrapper.text()).toContain("You do not have access to this console.");
    expect(wrapper.text()).not.toMatch(/uuid|sql|service.role/i);
  });

  it("does not render commercial or user-management fields", async () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await Promise.resolve();
    expect(wrapper.text()).not.toMatch(/price|premium|purchase|transaction|entitlement|users/i);
  });
});
