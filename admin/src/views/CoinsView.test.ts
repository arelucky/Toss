import { mount } from "@vue/test-utils";
import CoinsView from "./CoinsView.vue";
import { adminCoins, AdminCoinsError } from "../services/adminCoins";

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

  it("labels the coin creation inputs for assistive technology", () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });

    expect(wrapper.find('input[aria-label="Coin slug"]').exists()).toBe(true);
    expect(wrapper.find('input[aria-label="Display name"]').exists()).toBe(true);
  });

  it("alerts and skips createCoin for an uppercase slug", async () => {
    const createCoin = vi.spyOn(adminCoins, "action");
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });

    await wrapper.get('[aria-label="Coin slug"]').setValue("Hosted-Coin");
    await wrapper.get('[aria-label="Display name"]').setValue("Hosted Coin");
    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("Slug must use 3–64 lowercase letters, numbers, or hyphens.");
    expect(createCoin).not.toHaveBeenCalled();
    createCoin.mockRestore();
    alert.mockRestore();
  });
});
