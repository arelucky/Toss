import { flushPromises, mount } from "@vue/test-utils";
import { nextTick } from "vue";
import CoinsView from "./CoinsView.vue";
import { adminCoins, AdminCoinsError } from "../services/adminCoins";

describe("CoinsView", () => {
  it("shows a safe access denied state for 403", async () => {
    const wrapper = mount(CoinsView, {
      props: { loadCoins: vi.fn().mockRejectedValue(new AdminCoinsError(403, "您无权访问此管理后台。")) },
    });
    await Promise.resolve();
    await Promise.resolve();
    expect(wrapper.text()).toContain("您无权访问此管理后台。");
    expect(wrapper.text()).not.toMatch(/uuid|sql|service.role/i);
  });

  it("does not render commercial or user-management fields", async () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await Promise.resolve();
    expect(wrapper.text()).not.toMatch(/price|premium|purchase|transaction|entitlement|users/i);
  });

  it("renders Chinese creation controls, empty state, and accessible labels", async () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await nextTick();
    await flushPromises();
    await nextTick();

    expect(wrapper.text()).toContain("创建硬币");
    expect(wrapper.text()).toContain("尚无硬币。");
    expect(wrapper.find('input[aria-label="硬币标识"]').exists()).toBe(true);
    expect(wrapper.find('input[aria-label="硬币名称"]').exists()).toBe(true);
  });

  it("alerts and skips createCoin for an uppercase slug", async () => {
    const createCoin = vi.spyOn(adminCoins, "action");
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });

    await wrapper.get('[aria-label="硬币标识"]').setValue("Hosted-Coin");
    await wrapper.get('[aria-label="硬币名称"]').setValue("Hosted Coin");
    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("硬币标识只能使用 3–64 个小写字母、数字或连字符。");
    expect(createCoin).not.toHaveBeenCalled();
    createCoin.mockRestore();
    alert.mockRestore();
  });

  it("uses a Chinese confirmation before hiding a coin", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    const wrapper = mount(CoinsView, {
      props: {
        loadCoins: vi.fn().mockResolvedValue([{
          id: "coin-id",
          displayName: "测试硬币",
          sortOrder: 0,
          isFeatured: false,
          status: "draft",
        }]),
      },
    });
    await flushPromises();

    const hideButton = wrapper.findAll("button").find((button) => button.text() === "隐藏");
    await hideButton?.trigger("click");

    expect(confirm).toHaveBeenCalledWith("确定要隐藏此硬币吗？现有资源将会保留。");
    confirm.mockRestore();
  });
});
