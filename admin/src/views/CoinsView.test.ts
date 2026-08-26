import { flushPromises, mount } from "@vue/test-utils";
import { nextTick } from "vue";
import CoinsView from "./CoinsView.vue";
import { adminCoins, AdminCoinsError, type AdminCoin } from "../services/adminCoins";

const publishedCoin: AdminCoin = {
  id: "published-coin-id",
  displayName: "发布硬币",
  slug: "published-coin",
  sortOrder: 10,
  isFeatured: true,
  status: "published",
  activeVersionID: "published-version-id",
  versions: [{
    id: "published-version-id",
    versionNumber: 2,
    status: "published",
    modelPath: "coins/published-coin/v2/model.usdz",
    previewPath: "coins/published-coin/v2/preview.webp",
  }],
};

const draftCoin: AdminCoin = {
  id: "draft-coin-id",
  displayName: "草稿硬币",
  slug: "draft-coin",
  sortOrder: 20,
  isFeatured: false,
  status: "draft",
  versions: [{ id: "draft-version-id", versionNumber: 1, status: "draft" }],
};

const hiddenCoin: AdminCoin = {
  id: "hidden-coin-id",
  displayName: "隐藏硬币",
  slug: "hidden-coin",
  sortOrder: 30,
  isFeatured: false,
  status: "hidden",
};

async function finishInitialLoad() {
  await nextTick();
  await flushPromises();
  await nextTick();
}

describe("CoinsView", () => {
  it("shows a safe access denied state for 403", async () => {
    const wrapper = mount(CoinsView, {
      props: { loadCoins: vi.fn().mockRejectedValue(new AdminCoinsError(403, "您无权访问此管理后台。")) },
    });
    await finishInitialLoad();
    expect(wrapper.text()).toContain("您无权访问此管理后台。");
    expect(wrapper.text()).not.toMatch(/uuid|sql|service.role/i);
  });

  it("does not render commercial or user-management fields", async () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await finishInitialLoad();
    expect(wrapper.text()).not.toMatch(/price|premium|purchase|transaction|entitlement|users/i);
  });

  it("expands Chinese creation controls with accessible labels", async () => {
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await finishInitialLoad();

    expect(wrapper.text()).toContain("尚无硬币。");
    expect(wrapper.find('input[aria-label="硬币标识"]').exists()).toBe(false);
    await wrapper.get('[data-test="create-toggle"]').trigger("click");
    expect(wrapper.text()).toContain("创建硬币");
    expect(wrapper.find('input[aria-label="硬币标识"]').exists()).toBe(true);
    expect(wrapper.find('input[aria-label="硬币名称"]').exists()).toBe(true);
  });

  it("alerts and skips createCoin for an uppercase slug", async () => {
    const createCoin = vi.spyOn(adminCoins, "action");
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([]) } });
    await finishInitialLoad();
    await wrapper.get('[data-test="create-toggle"]').trigger("click");

    await wrapper.get('[aria-label="硬币标识"]').setValue("Hosted-Coin");
    await wrapper.get('[aria-label="硬币名称"]').setValue("Hosted Coin");
    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("硬币标识只能使用 3–64 个小写字母、数字或连字符。");
    expect(createCoin).not.toHaveBeenCalled();
    createCoin.mockRestore();
    alert.mockRestore();
  });

  it("filters all four loaded catalog states locally", async () => {
    const wrapper = mount(CoinsView, {
      props: {
        loadCoins: vi.fn().mockResolvedValue([publishedCoin, draftCoin, hiddenCoin]),
        makePublicPreviewURL: (path: string) => `https://example.test/${path}`,
      },
    });
    await finishInitialLoad();

    await wrapper.get('[data-test="status-filter-all"]').trigger("click");
    expect(wrapper.text()).toContain("发布硬币");
    expect(wrapper.text()).toContain("草稿硬币");
    expect(wrapper.text()).toContain("隐藏硬币");

    await wrapper.get('[data-test="status-filter-draft"]').trigger("click");
    expect(wrapper.text()).toContain("草稿硬币");
    expect(wrapper.text()).not.toContain("发布硬币");

    await wrapper.get('[data-test="status-filter-published"]').trigger("click");
    expect(wrapper.text()).toContain("发布硬币");
    expect(wrapper.text()).not.toContain("隐藏硬币");

    await wrapper.get('[data-test="status-filter-hidden"]').trigger("click");
    expect(wrapper.text()).toContain("隐藏硬币");
    expect(wrapper.text()).not.toContain("草稿硬币");
  });

  it("renders only honest ready and incomplete asset states", async () => {
    const wrapper = mount(CoinsView, {
      props: {
        loadCoins: vi.fn().mockResolvedValue([publishedCoin, draftCoin]),
        makePublicPreviewURL: (path: string) => `https://example.test/${path}`,
      },
    });
    await finishInitialLoad();

    expect(wrapper.text()).toContain("已就绪");
    expect(wrapper.text()).toContain("待上传");
    expect(wrapper.text()).not.toMatch(/模型缺失|预览缺失/);
  });

  it("keeps the loaded catalog visible when refresh fails", async () => {
    const loadCoins = vi.fn()
      .mockResolvedValueOnce([publishedCoin])
      .mockRejectedValueOnce(new AdminCoinsError(500, "管理服务暂时无法完成此操作。"));
    const wrapper = mount(CoinsView, {
      props: { loadCoins, makePublicPreviewURL: (path: string) => `https://example.test/${path}` },
    });
    await finishInitialLoad();

    await wrapper.get('[data-test="reload-coins"]').trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("发布硬币");
    expect(wrapper.text()).toContain("管理服务暂时无法完成此操作。");
  });

  it("shows restore rather than hide for hidden coins and refreshes after confirmation", async () => {
    const action = vi.spyOn(adminCoins, "action").mockResolvedValue({});
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(true);
    const loadCoins = vi.fn().mockResolvedValue([hiddenCoin]);
    const wrapper = mount(CoinsView, { props: { loadCoins } });
    await finishInitialLoad();

    expect(wrapper.text()).toContain("已隐藏");
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
