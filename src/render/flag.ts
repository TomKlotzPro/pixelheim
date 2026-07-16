import { loadSettings } from "../settings";

/**
 * WebGL is the default renderer and the Options screen owns the choice
 * (persisted per device). URL params remain as overrides: ?dom forces the
 * legacy DOM tiles (one pinned spec uses it), ?pixi forces WebGL. Changing
 * the option reloads the page: renderers are chosen once at boot.
 */
const params = new URLSearchParams(window.location.search);
export const USE_PIXI = params.has("dom")
  ? false
  : params.has("pixi")
    ? true
    : loadSettings().renderer !== "classic";
