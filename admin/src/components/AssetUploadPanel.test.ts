import { mount } from "@vue/test-utils";
import AssetUploadPanel from "./AssetUploadPanel.vue";

function file(name: string, size?: number) {
  const value = new File(["asset"], name);
  if (size !== undefined) Object.defineProperty(value, "size", { value: size });
  return value;
}

async function chooseFiles(wrapper: ReturnType<typeof mount>, model: File, preview: File) {
  Object.defineProperty(wrapper.get("[data-test='model']").element, "files", { value: [model] });
  Object.defineProperty(wrapper.get("[data-test='preview']").element, "files", { value: [preview] });
  await wrapper.get("[data-test='model']").trigger("change");
  await wrapper.get("[data-test='preview']").trigger("change");
}

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

  it("alerts without uploading when the model is not USDZ", async () => {
    const upload = vi.fn();
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(AssetUploadPanel, { props: { upload } });
    await chooseFiles(wrapper, file("coin.glb"), file("preview.webp"));

    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("需要 USDZ 文件");
    expect(upload).not.toHaveBeenCalled();
    alert.mockRestore();
  });

  it("alerts without uploading when the model exceeds 50 MB", async () => {
    const upload = vi.fn();
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(AssetUploadPanel, { props: { upload } });
    await chooseFiles(wrapper, file("coin.usdz", 52_428_801), file("preview.webp"));

    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("USDZ 文件大小无效");
    expect(upload).not.toHaveBeenCalled();
    alert.mockRestore();
  });

  it("alerts without uploading when the preview is not WEBP", async () => {
    const upload = vi.fn();
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(AssetUploadPanel, { props: { upload } });
    await chooseFiles(wrapper, file("coin.usdz"), file("preview.png"));

    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("需要 WEBP 文件");
    expect(upload).not.toHaveBeenCalled();
    alert.mockRestore();
  });

  it("alerts without uploading when the preview exceeds 2 MB", async () => {
    const upload = vi.fn();
    const alert = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const wrapper = mount(AssetUploadPanel, { props: { upload } });
    await chooseFiles(wrapper, file("coin.usdz"), file("preview.webp", 2_097_153));

    await wrapper.get("form").trigger("submit");

    expect(alert).toHaveBeenCalledWith("WEBP 文件大小无效");
    expect(upload).not.toHaveBeenCalled();
    alert.mockRestore();
  });
});
