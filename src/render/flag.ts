/**
 * The WebGL renderers are the game (Painted World cutover, PIX-51). The
 * legacy DOM tile renderer stays reachable behind ?dom for one release as
 * insurance, then retires with PIX-53.
 */
export const USE_PIXI = !new URLSearchParams(window.location.search).has("dom");
