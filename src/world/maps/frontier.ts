import { parseMap } from "../parseMap";
import type { WorldMap } from "../types";

/**
 * The frontier: two wild regions beyond the Ashenreach's mountain ring,
 * reached through passes in the east and west walls. Harder than anything
 * on the old overworld - late-game hunting grounds with their own forage.
 */
export const DEEPWOOD_MAP: WorldMap = parseMap(
  "deepwood",
  `
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^ffffff....ffffffffffffffffff^
  ^fff..fffff..ffffff..ffffffff^
  ^ff.~~~ff.ffff.fffff.ffffffff^
  ^ff~~~~~f..fff.ff......ffffff^
  ^ff~~~~~ff.ff..ff.ffff.ffffff^
  ^fff~~~ff..f.fff.fffff.ffffff^
  ^ffff.ff..ff.ff..fff...ffffff^
  ^ff.....ff.f..f.ffff.ffffffff^
  ^ff.ffff.ff.........fff..ffff^
  ^f..fff.ff...........ff.fffff^
  ^f.ff..ff....fffff....ff.ffff^
  C============..W...=====.ffff^
  ^f.ff..fff...........fff.ffff^
  ^ff.fff.ff...........ff.fffff^
  ^fff.ff..fff.......fff..fffff^
  ^ff..fffff.f.####_####..fffff^
  ^f.ffff..ff..#______#.ff.ffff^
  ^ff.ff.ffff..#__$___#..ffffff^
  ^fff...ffff..#______#.fffffff^
  ^ffff.ffffff.###__###..ffffff^
  ^ff.ffffff.ff...ff..ff.ffffff^
  ^ffffff..ffffffff..ffffffffff^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  `,
  [{ x: 0, y: 12, to: { kind: "map", mapId: "overworld", x: 46, y: 16 } }],
  {
    grid: `
  ------------------------------
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  -DDDDDDDDDDDDDDDDDDDDDDDDDDDD-
  ------------------------------
  `,
    legend: { D: "deepwood" },
  },
);

export const MIREFEN_MAP: WorldMap = parseMap(
  "mirefen",
  `
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  ^.wwwwwww~~wwwwwwwwwww.wwwwww^
  ^ww.wwww~~~~www..wwwwww.wwwww^
  ^www.ww~~~~~~ww.w.wwwww.wwwww^
  ^ww.ww.w~~~~ww.www.wwwww.wwww^
  ^w.www.ww~~ww.wwwww.####.wwww^
  ^ww.ww.ww~bww.ww.ww.#_W#.wwww^
  ^www.w.ww~b.w.w.www.#__#.wwww^
  ^ww.wwww~~b~~w.ww.w.##_#.wwww^
  ^w.ww.ww~~~~~ww.wwww..w..wwww^
  ^ww.wwwww~~~~www.wwww.wwwwwww^
  ^www.wwwww~~~wwww.wwwwwwwwwww^
  ^.www.=======b=========.*====C
  ^ww.wwwww~~~wwwww.wwwww.wwwww^
  ^w.wwww.w~~~~ww.wwww.wwwwwwww^
  ^ww.ww.ww~~~~~ww.wwwww.wwwwww^
  ^www.wwww~~b~~www.ww.wwwwwwww^
  ^ww.wwwww~~b~www.wwww.wwwwwww^
  ^w.ww.www~~b~~ww.ww.wwww.wwww^
  ^ww.wwww~~~~~~www.wwww.wwwwww^
  ^www.ww~~~~~~~~ww.wwwwww.wwww^
  ^ww.www.~~~~~~www.ww.wwwwwwww^
  ^wwww.www~~~www.wwww.wwwwwwww^
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  `,
  [{ x: 29, y: 12, to: { kind: "map", mapId: "overworld", x: 1, y: 16 } }],
  {
    grid: `
  ------------------------------
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  -MMMMMMMMMMMMMMMMMMMMMMMMMMMM-
  ------------------------------
  `,
    legend: { M: "mire" },
  },
);
