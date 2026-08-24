import {
  AdminCoinsError,
  createAdminCoinsService,
  sha256Hex,
  uploadVersionAssets,
  validateModelFile,
  validatePreviewFile,
} from "./adminCoins";

describe("admin coin service", () => {
  it("validates USDZ and WEBP extension and fixed byte limits", () => {
    expect(validateModelFile(new File([new Uint8Array(10)], "coin.usdz"))).toEqual({ ok: true });
    expect(validateModelFile(new File([new Uint8Array(10)], "coin.obj"))).toEqual({ ok: false, error: "需要 USDZ 文件" });
    expect(validateModelFile({ name: "coin.usdz", size: 52_428_801 } as File).ok).toBe(false);
    expect(validatePreviewFile(new File([new Uint8Array(10)], "preview.webp"))).toEqual({ ok: true });
    expect(validatePreviewFile(new File([new Uint8Array(10)], "preview.png"))).toEqual({ ok: false, error: "需要 WEBP 文件" });
    expect(validatePreviewFile({ name: "preview.webp", size: 2_097_153 } as File).ok).toBe(false);
  });

  it("computes a lowercase 64-character SHA-256", async () => {
    const hash = await sha256Hex(new File(["toss"], "coin.usdz"));
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it("uses only a session token when invoking admin-coins", async () => {
    const invoke = vi.fn().mockResolvedValue({ data: [], error: null });
    const session = vi.fn().mockResolvedValue({ access_token: "session-token" });
    const service = createAdminCoinsService({ invoke, session });
    await service.listDrafts();
    expect(invoke).toHaveBeenCalledWith("admin-coins", {
      body: { action: "listDrafts" },
      headers: { Authorization: "Bearer session-token" },
    });
  });

  it("maps 403 without exposing server details", async () => {
    const service = createAdminCoinsService({
      session: vi.fn().mockResolvedValue({ access_token: "token" }),
      invoke: vi.fn().mockResolvedValue({ data: null, error: { context: { status: 403 }, message: "admin uuid and SQL" } }),
    });
    await expect(service.listDrafts()).rejects.toEqual(new AdminCoinsError(403, "您无权访问此管理后台。"));
  });

  it("uploads through createVersion, signed URLs, direct PUTs, then refreshes", async () => {
    const actions: string[] = [];
    const action = vi.fn(async (request: { action: string; asset?: string }) => {
      actions.push(request.asset ? `${request.action}:${request.asset}` : request.action);
      if (request.action === "createVersion") return { id: "version-id" };
      if (request.action === "createUploadURL") return { uploadURL: `https://upload/${request.asset}` };
      if (request.action === "listDrafts") return [];
      return {};
    });
    const upload = vi.fn(async (url: string) => actions.push(`PUT:${url.split("/").at(-1)}`));
    await uploadVersionAssets({
      coinID: "coin-id",
      versionNumber: 1,
      minAppVersion: "1.0.0",
      model: new File(["model"], "coin.usdz"),
      preview: new File(["preview"], "preview.webp"),
    }, { action, upload });
    expect(actions).toEqual([
      "createVersion",
      "createUploadURL:model",
      "PUT:model",
      "createUploadURL:preview",
      "PUT:preview",
      "listDrafts",
    ]);
  });
});
