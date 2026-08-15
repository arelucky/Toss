import { mount } from "@vue/test-utils";
import AssetUploadPanel from "./AssetUploadPanel.vue";

describe("AssetUploadPanel", () => {
  it("disables duplicate submission while uploading", async () => {
    let finish!: () => void;
    const upload = vi.fn(() => new Promise<void>((resolve) => { finish = resolve; }));
    const wrapper = mount(AssetUploadPanel, { props: { upload } });
    const model = new File(["model"], "coin.usdz");
    const preview = new File(["preview"], "preview.webp");
    Object.defineProperty(wrapper.get("[data-test='model']").element, "files", { value: [model] });
    Object.defineProperty(wrapper.get("[data-test='preview']").element, "files", { value: [preview] });
    await wrapper.get("[data-test='model']").trigger("change");
    await wrapper.get("[data-test='preview']").trigger("change");
    await wrapper.get("form").trigger("submit");
    expect(wrapper.get("button[type='submit']").attributes("disabled")).toBeDefined();
    await wrapper.get("form").trigger("submit");
    expect(upload).toHaveBeenCalledTimes(1);
    finish();
  });
});
