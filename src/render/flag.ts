import { loadSettings } from "../app/settings";

/** The three world renderers: Pixi canvas, three.js voxel diorama, DOM tiles. */
export type RendererKind = "pixi" | "voxel" | "dom";

/**
 * The voxel diorama is the default renderer (the PIX-111 verdict: Tom played
 * it, Tom kept it) and the Options screen owns the choice (persisted per
 * device). URL params remain as overrides: ?dom forces the legacy DOM tiles
 * (one pinned spec uses it), ?pixi forces the classic WebGL canvas, ?voxel
 * forces the diorama. Changing the option reloads the page: renderers are
 * chosen once at boot.
 */
function resolve(): RendererKind {
  const params = new URLSearchParams(window.location.search);
  if (params.has("dom")) return "dom";
  if (params.has("pixi")) return "pixi";
  if (params.has("voxel")) return "voxel";
  const saved = loadSettings().renderer;
  return saved === "classic" ? "dom" : saved === "voxel" ? "voxel" : "pixi";
}

export const RENDERER: RendererKind = resolve();

/** Canvas renderers share the Pixi battle scene and the e2e state mirror. */
export const USE_PIXI = RENDERER !== "dom";
