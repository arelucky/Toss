import { flushPromises, mount } from "@vue/test-utils";
import CoinEditorView from "./CoinEditorView.vue";

const coin = { id: "coin-id", displayName: "Gold", description: "Original", sortOrder: 0, isFeatured: false, versions: [{ id: "v1", versionNumber: 1, status: "published" }] };

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
