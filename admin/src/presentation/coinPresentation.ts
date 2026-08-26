import type { AdminCoin, CoinVersion } from "../services/adminCoins";

export type CoinAssetState = "ready" | "incomplete";

export function activeVersion(coin: AdminCoin): CoinVersion | undefined {
  return coin.versions?.find((version) => version.id === coin.activeVersionID);
}

export function coinStatusLabel(status: string | undefined): string {
  if (status === "draft") return "草稿";
  if (status === "published") return "已发布";
  if (status === "hidden") return "已隐藏";
  return "未知";
}

export function versionStatusLabel(status: string | undefined): string {
  if (status === "draft") return "草稿";
  if (status === "published") return "已发布";
  return "未知";
}

export function assetState(coin: AdminCoin): CoinAssetState {
  const version = activeVersion(coin);
  return version?.status === "published" && Boolean(version.modelPath && version.previewPath)
    ? "ready"
    : "incomplete";
}

export function assetStateLabel(state: CoinAssetState): "已就绪" | "待上传" {
  return state === "ready" ? "已就绪" : "待上传";
}

export function formatBytes(value: number | undefined): string {
  if (value === undefined || !Number.isFinite(value) || value <= 0) return "—";
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}

export function publicPreviewURL(
  previewPath: string | undefined,
  makePublicURL: (path: string) => string,
): string | undefined {
  return previewPath ? makePublicURL(previewPath) : undefined;
}
