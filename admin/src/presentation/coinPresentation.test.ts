import {
  activeVersion,
  assetState,
  assetStateLabel,
  coinStatusLabel,
  formatBytes,
  publicPreviewURL,
  versionStatusLabel,
} from "./coinPresentation";

const publishedCoin = {
  id: "coin-1",
  displayName: "美丽梦境",
  sortOrder: 10,
  isFeatured: true,
  status: "published",
  activeVersionID: "version-2",
  versions: [
    { id: "version-1", versionNumber: 1, status: "published" },
    {
      id: "version-2",
      versionNumber: 2,
      status: "published",
      modelPath: "coins/dream/v2/model.usdz",
      previewPath: "coins/dream/v2/preview.webp",
      modelByteSize: 1_572_864,
    },
  ],
};

describe("coin presentation", () => {
  it("marks only an active published version with both paths ready", () => {
    expect(activeVersion(publishedCoin)?.id).toBe("version-2");
    expect(assetState(publishedCoin)).toBe("ready");
    expect(assetStateLabel(assetState(publishedCoin))).toBe("已就绪");

    expect(assetState({ ...publishedCoin, activeVersionID: undefined })).toBe("incomplete");
    expect(assetState({
      ...publishedCoin,
      versions: [{ ...publishedCoin.versions[1], status: "draft" }],
    })).toBe("incomplete");
    expect(assetState({
      ...publishedCoin,
      versions: [{ ...publishedCoin.versions[1], modelPath: undefined }],
    })).toBe("incomplete");
    expect(assetState({
      ...publishedCoin,
      versions: [{ ...publishedCoin.versions[1], previewPath: undefined }],
    })).toBe("incomplete");
  });

  it("labels only known presentation values without inventing preview URLs", () => {
    expect(coinStatusLabel("hidden")).toBe("已隐藏");
    expect(versionStatusLabel("draft")).toBe("草稿");
    expect(formatBytes(1_572_864)).toBe("1.5 MB");
    expect(formatBytes(undefined)).toBe("—");
    expect(publicPreviewURL(undefined, (path) => `https://example.test/${path}`)).toBeUndefined();
    expect(publicPreviewURL("coins/dream/v2/preview.webp", (path) => `https://example.test/${path}`))
      .toBe("https://example.test/coins/dream/v2/preview.webp");
  });
});
