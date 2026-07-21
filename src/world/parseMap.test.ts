import { describe, expect, it } from "vitest";
import { isWalkable, parseMap, portalAt, regionAt, tileAt } from "./parseMap";

const PORTALS = [{ x: 2, y: 3, to: { kind: "map", mapId: "elsewhere", x: 1, y: 1 } }] as never;

const map = parseMap(
  "testmap",
  `
  #####
  #.ST#
  #~k.#
  ##D##
  `,
  PORTALS,
);

describe("the ASCII map parser", () => {
  it("reads dimensions and tiles from the drawing", () => {
    expect(map.width).toBe(5);
    expect(map.height).toBe(4);
    expect(tileAt(map, 0, 0)).toBe("wall");
    expect(tileAt(map, 1, 1)).toBe("grass");
    expect(tileAt(map, 2, 1)).toBe("grass"); // S marks spawn, walks like grass
    expect(tileAt(map, 3, 1)).toBe("trophy_shelf");
    expect(tileAt(map, 1, 2)).toBe("water");
    expect(tileAt(map, 2, 2)).toBe("crops");
    expect(tileAt(map, 2, 3)).toBe("door");
  });

  it("answers walkability from the tile table", () => {
    expect(isWalkable(map, 1, 1)).toBe(true); // grass
    expect(isWalkable(map, 2, 2)).toBe(true); // crops
    expect(isWalkable(map, 1, 2)).toBe(false); // water
    expect(isWalkable(map, 3, 1)).toBe(false); // trophy shelf
    expect(isWalkable(map, 0, 0)).toBe(false); // wall
    expect(isWalkable(map, -1, 0)).toBe(false); // off the west edge
    expect(isWalkable(map, 0, 99)).toBe(false); // off the south edge
  });

  it("finds portals only where they are", () => {
    expect(portalAt(map, 2, 3)?.to).toMatchObject({ mapId: "elsewhere" });
    expect(portalAt(map, 1, 1)).toBeNull();
  });

  it("throws on a door with no portal - broken links fail at load, not in play", () => {
    expect(() => parseMap("broken", "\n  #S#\n  #D#\n  ###\n  ", [] as never)).toThrow(/no portal/);
  });

  it("throws on an unknown character so map typos cannot ship", () => {
    expect(() => parseMap("typo", "\n  #S#\n  #?#\n  ###\n  ", [] as never)).toThrow();
  });

  it("regions default to null without a region spec", () => {
    expect(regionAt(map, 1, 1)).toBeNull();
  });
});
