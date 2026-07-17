import { expect, test } from "@playwright/test";
// Importing the registry runs every map through parseMap plus the cross-map
// portal checks at module load: a malformed map fails this spec before any
// browser starts. This is the CI gate for map authoring.
import { MAPS } from "../src/world/maps";
import { TILES } from "../src/world/tiles";

test("every map parses, validates, and only uses known tiles", () => {
  const maps = Object.values(MAPS);
  expect(maps.length).toBeGreaterThan(0);
  for (const map of maps) {
    expect(map.tiles.length).toBe(map.height);
    for (const row of map.tiles) {
      expect(row.length).toBe(map.width);
      for (const tile of row) expect(TILES[tile]).toBeDefined();
    }
  }
});
