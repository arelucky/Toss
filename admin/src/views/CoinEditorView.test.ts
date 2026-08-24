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

describe("CoinEditorView", () => {
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
