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

  it("shows hide only for published coins and confirms in Chinese", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    const wrapper = mount(CoinsView, {
      props: {
        loadCoins: vi.fn().mockResolvedValue([{
          id: "coin-id",
          displayName: "测试硬币",
          sortOrder: 0,
          isFeatured: false,
          status: "published",
        }]),
      },
    });
    await flushPromises();

    const hideButton = wrapper.findAll("button").find((button) => button.text() === "隐藏");
    await hideButton?.trigger("click");

    expect(confirm).toHaveBeenCalledWith("确定要隐藏此硬币吗？现有资源将会保留。");
    confirm.mockRestore();
  });

  it("shows restore for hidden coins and refreshes after confirmation", async () => {
    const action = vi.spyOn(adminCoins, "action").mockResolvedValue({});
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(true);
    const loadCoins = vi.fn().mockResolvedValue([{
      id: "hidden-coin-id",
      displayName: "测试硬币",
      sortOrder: 0,
      isFeatured: false,
      status: "hidden",
    }]);
    const wrapper = mount(CoinsView, { props: { loadCoins } });
    await flushPromises();

    expect(wrapper.text()).toContain("已隐藏");
    expect(wrapper.text()).toContain("恢复");
    const actionButtons = wrapper.findAll("button");
    expect(actionButtons.some((button) => button.text() === "隐藏")).toBe(false);
    const restoreButton = actionButtons.find((button) => button.text() === "恢复");
    expect(restoreButton).toBeDefined();
    await restoreButton?.trigger("click");
    await flushPromises();

    expect(confirm).toHaveBeenCalledWith("确定要恢复此硬币吗？");
    expect(action).toHaveBeenCalledWith({ action: "restoreCoin", coinID: "hidden-coin-id" });
    expect(loadCoins).toHaveBeenCalledTimes(2);
    action.mockRestore();
    confirm.mockRestore();
  });
});
