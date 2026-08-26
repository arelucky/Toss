import { flushPromises, mount } from "@vue/test-utils";
import CoinEditorView from "./CoinEditorView.vue";

const coin = {
  id: "coin-id",
  displayName: "Gold",
  description: "Original",
  sortOrder: 0,
  isFeatured: false,
  activeVersionID: "v2",
  versions: [
    { id: "v1", versionNumber: 1, status: "published" },
    { id: "v2", versionNumber: 2, status: "draft" },
  ],
};

const detailedCoin = {
  id: "detailed-coin-id",
  displayName: "美丽梦境",
  slug: "dream-coin",
  description: "有完整版本字段的硬币。",
  sortOrder: 10,
  isFeatured: true,
  status: "published",
  activeVersionID: "v2",
  versions: [
    {
      id: "v1",
      versionNumber: 1,
      status: "published",
      modelPath: "coins/dream-coin/v1/model.usdz",
      previewPath: "coins/dream-coin/v1/preview.webp",
      modelByteSize: 1_572_864,
      modelSHA256: "a".repeat(64),
      minAppVersion: "1.0.0",
      assetSchemaVersion: 1,
    },
    {
      id: "v3",
      versionNumber: 3,
      status: "draft",
      modelPath: "coins/dream-coin/v3/model.usdz",
      previewPath: "coins/dream-coin/v3/preview.webp",
      modelByteSize: 2_097_152,
      minAppVersion: "1.0.0",
      assetSchemaVersion: 1,
    },
    {
      id: "v2",
      versionNumber: 2,
      status: "published",
      modelPath: "coins/dream-coin/v2/model.usdz",
      previewPath: "coins/dream-coin/v2/preview.webp",
      modelByteSize: 1_572_864,
      modelSHA256: "b".repeat(64),
      minAppVersion: "1.0.0",
      assetSchemaVersion: 1,
      publishedAt: "2026-08-26T00:00:00Z",
    },
  ],
};

describe("CoinEditorView", () => {
  it("announces an in-progress save and disables version transitions while busy", async () => {
    let finish!: () => void;
    const wrapper = mount(CoinEditorView, {
      props: {
        coin,
        saveCoin: () => new Promise<void>((resolve) => { finish = resolve; }),
      },
    });

    await wrapper.get("form").trigger("submit");

    expect(wrapper.get("[data-test='publish']").attributes("disabled")).toBeDefined();
    expect(wrapper.get("[data-test='rollback']").attributes("disabled")).toBeDefined();
    expect(wrapper.get('[role="status"]').text()).toContain("正在保存");

    finish();
    await flushPromises();
  });

  it("announces a successful save with a status role", async () => {
    const wrapper = mount(CoinEditorView, {
      props: { coin, saveCoin: vi.fn().mockResolvedValue(undefined) },
    });

    await wrapper.get("form").trigger("submit");
    await flushPromises();

    expect(wrapper.get('[role="status"]').text()).toBe("已保存");
  });

  it("keeps publication success and safe errors in accessible regions", async () => {
    const wrapper = mount(CoinEditorView, {
      props: {
        coin,
        confirmAction: vi.fn().mockResolvedValue(true),
        performAction: vi.fn().mockRejectedValue(new Error("raw internal failure")),
      },
    });

    await wrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();

    expect(wrapper.get('[role="alert"]').text()).toBe("无法更新版本。");
    expect(wrapper.text()).not.toContain("raw internal failure");
  });

  it("renders only confirmed current-version and asset facts", () => {
    const wrapper = mount(CoinEditorView, {
      props: {
        coin: detailedCoin,
        makePublicPreviewURL: (path: string) => `https://example.test/${path}`,
      },
    });

    expect(wrapper.text()).toContain("当前版本");
    expect(wrapper.text()).toContain("v2");
    expect(wrapper.text()).toContain("已就绪");
    expect(wrapper.text()).toContain("model.usdz");
    expect(wrapper.text()).toContain("preview.webp");
    expect(wrapper.text()).toContain("1.5 MB");
    expect(wrapper.html()).not.toMatch(/signed|token/i);
  });

  it("lists version history in descending order without changing transition targets", () => {
    const wrapper = mount(CoinEditorView, {
      props: {
        coin: detailedCoin,
        makePublicPreviewURL: (path: string) => `https://preview.example/${path}`,
      },
    });

    expect(wrapper.findAll('[data-test="version-history-row"]')
      .map((row) => row.attributes("data-version")))
      .toEqual(["3", "2", "1"]);
  });

  it("renders Chinese upload, publish, and rollback controls", () => {
    const wrapper = mount(CoinEditorView, { props: { coin } });

    expect(wrapper.text()).toContain("版本资源");
    expect(wrapper.text()).toContain("最低应用版本");
    expect(wrapper.get("[data-test='publish']").text()).toBe("发布");
    expect(wrapper.get("[data-test='rollback']").text()).toBe("回滚");
  });

  it("requires confirmation before publish and rollback", async () => {
    const confirmAction = vi.fn().mockResolvedValue(true);
    const performAction = vi.fn().mockResolvedValue(undefined);
    const wrapper = mount(CoinEditorView, { props: { coin, saveCoin: vi.fn(), confirmAction, performAction } });
    await wrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();
    await wrapper.get("[data-test='rollback']").trigger("click");
    await flushPromises();
    expect(confirmAction).toHaveBeenCalledTimes(2);
    expect(performAction).toHaveBeenCalledTimes(2);
    expect(performAction.mock.calls.map(([action]) => action)).toEqual(["publish", "rollback"]);
  });

  it("announces a successful publication after the version refreshes", async () => {
    const wrapper = mount(CoinEditorView, {
      props: {
        coin,
        confirmAction: vi.fn().mockResolvedValue(true),
        performAction: vi.fn().mockResolvedValue(undefined),
      },
    });

    await wrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();

    expect(wrapper.get('[role="status"]').text()).toBe("版本已发布。");
  });

  it("does not announce publication after a rollback", async () => {
    const rollbackCoin = {
      ...coin,
      activeVersionID: "v2",
      versions: [
        { id: "v2", versionNumber: 2, status: "published" },
        { id: "v1", versionNumber: 1, status: "published" },
      ],
    };
    const wrapper = mount(CoinEditorView, {
      props: {
        coin: rollbackCoin,
        confirmAction: vi.fn().mockResolvedValue(true),
        performAction: vi.fn().mockResolvedValue(undefined),
      },
    });

    await wrapper.get("[data-test='rollback']").trigger("click");
    await flushPromises();

    expect(wrapper.find('[role="status"]').exists()).toBe(false);
  });

  it("does not announce publication when publishing fails", async () => {
    const wrapper = mount(CoinEditorView, {
      props: {
        coin,
        confirmAction: vi.fn().mockResolvedValue(true),
        performAction: vi.fn().mockRejectedValue(new Error("internal failure")),
      },
    });

    await wrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();

    expect(wrapper.find('[role="status"]').exists()).toBe(false);
  });

  it("targets the highest eligible version for publish and rollback regardless of array order", async () => {
    const confirmAction = vi.fn().mockResolvedValue(true);
    const publishAction = vi.fn().mockResolvedValue(undefined);
    const publishCoin = {
      ...coin,
      activeVersionID: "v1",
      versions: [
        { id: "v1", versionNumber: 1, status: "published" },
        { id: "v2", versionNumber: 2, status: "draft" },
      ],
    };
    const publishWrapper = mount(CoinEditorView, {
      props: { coin: publishCoin, confirmAction, performAction: publishAction },
    });

    await publishWrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();

    expect(publishAction).toHaveBeenCalledWith("publish", "v2");

    const rollbackAction = vi.fn().mockResolvedValue(undefined);
    const rollbackCoin = {
      ...coin,
      activeVersionID: "v2",
      versions: [
        { id: "v2", versionNumber: 2, status: "published" },
        { id: "v1", versionNumber: 1, status: "published" },
      ],
    };
    const rollbackWrapper = mount(CoinEditorView, {
      props: { coin: rollbackCoin, confirmAction, performAction: rollbackAction },
    });

    await rollbackWrapper.get("[data-test='rollback']").trigger("click");
    await flushPromises();

    expect(rollbackAction).toHaveBeenCalledWith("rollback", "v1");
  });

  it("shows safe messages without calling the API when no eligible version exists", async () => {
    const confirmAction = vi.fn().mockResolvedValue(true);
    const performAction = vi.fn().mockResolvedValue(undefined);
    const wrapper = mount(CoinEditorView, {
      props: {
        coin: { ...coin, activeVersionID: "v1", versions: [{ id: "v1", versionNumber: 1, status: "published" }] },
        confirmAction,
        performAction,
      },
    });

    await wrapper.get("[data-test='publish']").trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("请先创建草稿版本再发布。");
    expect(confirmAction).not.toHaveBeenCalled();
    expect(performAction).not.toHaveBeenCalled();

    await wrapper.get("[data-test='rollback']").trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("没有可回滚到的已发布旧版本。");
    expect(confirmAction).not.toHaveBeenCalled();
    expect(performAction).not.toHaveBeenCalled();
  });

  it("preserves form content and shows a safe error after API failure", async () => {
    const wrapper = mount(CoinEditorView, {
      props: { coin, saveCoin: vi.fn().mockRejectedValue(new Error("raw SQL secret")), confirmAction: vi.fn(), performAction: vi.fn() },
    });
    await wrapper.get("[data-test='display-name']").setValue("Edited Gold");
    await wrapper.get("form").trigger("submit");
    await Promise.resolve();
    expect((wrapper.get("[data-test='display-name']").element as HTMLInputElement).value).toBe("Edited Gold");
    expect(wrapper.text()).toContain("无法保存更改。");
    expect(wrapper.text()).not.toContain("raw SQL secret");
  });
});
