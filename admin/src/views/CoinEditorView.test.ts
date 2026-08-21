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

    expect(wrapper.text()).toContain("Create a draft version before publishing.");
    expect(confirmAction).not.toHaveBeenCalled();
    expect(performAction).not.toHaveBeenCalled();

    await wrapper.get("[data-test='rollback']").trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("No previous published version is available to roll back to.");
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
    expect(wrapper.text()).toContain("Could not save changes.");
    expect(wrapper.text()).not.toContain("raw SQL secret");
  });
});
