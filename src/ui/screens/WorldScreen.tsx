import { lazy, Suspense, useEffect, useState } from "react";
import { heroSprite as heroSpriteOf } from "../../game/hero/character";
import { outfitFor } from "../../game/economy/wearables";
import { DressedSprite } from "../widgets/DressedSprite";
import { rankIndex, rankPresence } from "../../game/hero/ranks";
import { dispatch, useGameState, useWorld } from "../../state/store";
import { getMap } from "../../world/maps/index";
import { spawnSpecies } from "../../game/combat/encounters";
import { getMonster } from "../../game/combat/monsters";
import { chestSpriteName, chestsOn } from "../../world/chests";
import { furnitureOn } from "../../game/economy/house";
import { getItem } from "../../game/economy/items";
import { npcById, npcPosition, npcsOn } from "../../world/npcs";
import { spawnPosition, spawnRegion, spawnsOn } from "../../world/spawns";
import { regionAt } from "../../world/parseMap";
import { signsOn } from "../../world/signs";
import { TILES } from "../../world/tiles";
import type { Direction } from "../../world/types";

import { RENDERER } from "../../render/flag";
import { WILD_TILES } from "../../state/shared";
import { cameraFor, VIEW_H, VIEW_W } from "../../render/worldCamera";
import { interactionPrompt } from "../../world/interactionPrompt";
import { MiniMap } from "../panels/MapScreen";
import { Sprite } from "../widgets/Sprite";
import { WorldHud } from "../widgets/WorldHud";

const ART_PX = 16;

// Lazy so pixi.js (and three.js) stay out of the main bundle until the flag asks.
const PixiWorldView = lazy(() => import("../../render/PixiWorldView").then((m) => ({ default: m.PixiWorldView })));
const VoxelWorldView = lazy(() =>
  import("../../render/voxel/VoxelWorldView").then((m) => ({ default: m.VoxelWorldView })),
);

/** Largest integer art scale that fits the window; pixels stay crisp. */
function computeScale(): number {
  const availW = window.innerWidth - 48;
  const availH = window.innerHeight - 150;
  return Math.max(2, Math.min(Math.floor(availW / (VIEW_W * ART_PX)), Math.floor(availH / (VIEW_H * ART_PX))));
}

function useTileScale(): number {
  const [scale, setScale] = useState(computeScale);
  useEffect(() => {
    const onResize = () => setScale(computeScale());
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);
  return scale;
}

export function WorldScreen() {
  const state = useGameState();
  const world = useWorld().position;
  const map = getMap(world.mapId);
  const heroSprite = state.hero ? heroSpriteOf(state.hero) : "hero_warrior";
  const outfit = state.hero ? outfitFor(state.gear, state.equipped) : [];
  const tilePx = ART_PX * useTileScale();

  // The one prompt rule, shared with the canvas renderers (PIX-115).
  const promptAt = interactionPrompt(state, map.id);
  const { x: cameraX, y: cameraY } = cameraFor(map, world);

  const clickTile = (x: number, y: number) => {
    const dx = x - world.x;
    const dy = y - world.y;
    if (Math.abs(dx) + Math.abs(dy) !== 1) return;
    const direction: Direction = dx === 1 ? "right" : dx === -1 ? "left" : dy === 1 ? "down" : "up";
    dispatch({ type: "MOVE", direction });
  };

  return (
    <div className="screen world-screen">
      {state.hero && <WorldHud />}
      {state.hero && <MiniMap />}
      {state.hero && !state.introSeen && (
        <div className="overlay">
          <div className="panel intro-panel">
            <p>The mountain burned once. The village rebuilt. The monsters never left.</p>
            <p>Pixelheim needs someone stubborn enough to climb the Ashen Mountain.</p>
            <p>The gate is north, past the inn. The merchant buys and sells. The inn is warm. Good luck.</p>
            <button className="btn btn-primary" onClick={() => dispatch({ type: "DISMISS_INTRO" })}>
              Set out
            </button>
          </div>
        </div>
      )}
      {/* The stage wraps the viewport so the dialogue overlays the world
          instead of pushing the layout below it. */}
      <div className="world-stage">
        {RENDERER !== "dom" ? (
          <>
            <Suspense
              fallback={
                <div
                  className="world-viewport world-loading-standalone"
                  style={{ width: VIEW_W * tilePx, height: VIEW_H * tilePx }}
                >
                  <div className="world-loading">
                    <span className="world-loading-text">
                      Loading
                      <span className="loading-dots" />
                    </span>
                  </div>
                </div>
              }
            >
              {RENDERER === "voxel" ? (
                <VoxelWorldView scale={tilePx / ART_PX} mapId={map.id} />
              ) : (
                <PixiWorldView scale={tilePx / ART_PX} mapId={map.id} />
              )}
            </Suspense>
            {/* State mirror: 1px hooks the e2e suite asserts against, since the
              canvas has no DOM to query. Purely derived, never interactive. */}
            <div className="world-mirror" aria-hidden="true">
              <div
                data-testid="world-hero"
                data-pos={`${world.x},${world.y}`}
                data-rank={state.hero ? rankIndex(state.hero.level) : 0}
                data-outfit={outfit.join("+")}
                className={`facing-${world.facing}`}
              />
              {npcsOn(map.id).map((npc) => (
                <div key={npc.id} data-testid="world-npc" />
              ))}
              {spawnsOn(map.id)
                .filter((spawn) => !(state.world?.slain ?? []).includes(spawn.id))
                .map((spawn) => {
                  const at = spawnPosition(spawn, state.worldSteps);
                  return <div key={spawn.id} data-testid="world-monster" data-pos={`${at.x},${at.y}`} />;
                })}
              {chestsOn(map.id).map((chest) => (
                <div
                  key={chest.id}
                  data-testid="world-chest"
                  data-pos={`${chest.x},${chest.y}`}
                  data-open={(state.world?.openedChests ?? []).includes(chest.id) || undefined}
                />
              ))}
              {furnitureOn(state, map.id).map((f) => (
                <div
                  key={`${f.x},${f.y}`}
                  data-testid="world-furniture"
                  data-pos={`${f.x},${f.y}`}
                  data-item={f.itemId}
                />
              ))}
              {signsOn(map.id, state.house.owned).map((sign) => (
                <div
                  key={`${sign.x},${sign.y}`}
                  data-testid="door-sign"
                  data-label={sign.label}
                  data-icon={sign.icon}
                />
              ))}
              {promptAt && <div data-testid="npc-prompt" />}
            </div>
          </>
        ) : (
          <div
            className="world-viewport"
            data-testid="world-viewport"
            data-map={map.id}
            style={{ width: VIEW_W * tilePx, height: VIEW_H * tilePx }}
          >
            <div
              className="world-map"
              style={{
                width: map.width * tilePx,
                height: map.height * tilePx,
                transform: `translate(${-cameraX * tilePx}px, ${-cameraY * tilePx}px)`,
              }}
            >
              {map.tiles.map((row, y) =>
                row.map((tile, x) => {
                  // Dangerous ground is visible: wild-region tiles grow dark tufts.
                  const dangerous = WILD_TILES.has(tile) && regionAt(map, x, y) !== null;
                  const terrain = `url(${import.meta.env.BASE_URL}sprites/${TILES[tile].sprite}.png)`;
                  const overlay = `url(${import.meta.env.BASE_URL}sprites/overlay_wild.png)`;
                  return (
                    <div
                      key={`${x},${y}`}
                      className="world-tile"
                      data-danger={dangerous || undefined}
                      onClick={() => clickTile(x, y)}
                      style={{
                        left: x * tilePx,
                        top: y * tilePx,
                        width: tilePx,
                        height: tilePx,
                        backgroundSize: `${tilePx}px ${tilePx}px`,
                        backgroundImage: dangerous ? `${overlay}, ${terrain}` : terrain,
                      }}
                    />
                  );
                }),
              )}
              {chestsOn(map.id).map((chest) => {
                const sprite = chestSpriteName(chest, (state.world?.openedChests ?? []).includes(chest.id));
                if (!sprite) return null;
                return (
                  <div
                    key={chest.id}
                    className="world-npc"
                    data-testid="world-chest"
                    style={{ left: chest.x * tilePx, top: chest.y * tilePx, width: tilePx, height: tilePx }}
                  >
                    <Sprite name={sprite} size={tilePx} alt="" />
                  </div>
                );
              })}
              {furnitureOn(state, map.id).map((f) => (
                <div
                  key={`${f.x},${f.y}`}
                  className="world-npc"
                  style={{ left: f.x * tilePx, top: f.y * tilePx, width: tilePx, height: tilePx }}
                >
                  <Sprite name={getItem(f.itemId).sprite} size={tilePx} alt={getItem(f.itemId).name} />
                </div>
              ))}
              {signsOn(map.id, state.house.owned).map((sign) => (
                <span
                  key={`${sign.x},${sign.y}`}
                  className="door-sign"
                  style={{ left: (sign.x + 0.5) * tilePx, top: sign.y * tilePx }}
                >
                  {sign.icon && <Sprite name={sign.icon} size={16} alt="" />}
                  {sign.label}
                </span>
              ))}
              {spawnsOn(map.id)
                .filter((spawn) => !(state.world?.slain ?? []).includes(spawn.id))
                .map((spawn) => {
                  const at = spawnPosition(spawn, state.worldSteps);
                  const species = getMonster(spawnSpecies(spawnRegion(spawn), spawn.x * 31 + spawn.y));
                  return (
                    <div
                      key={spawn.id}
                      className="world-npc"
                      style={{ left: at.x * tilePx, top: at.y * tilePx, width: tilePx, height: tilePx }}
                    >
                      <Sprite name={species.sprite} size={tilePx} alt={species.name} />
                    </div>
                  );
                })}
              {npcsOn(map.id).map((npc) => {
                const pos = npcPosition(npc, state.worldSteps);
                return (
                  <div
                    key={npc.id}
                    className="world-npc"
                    data-testid="world-npc"
                    style={{ left: pos.x * tilePx, top: pos.y * tilePx, width: tilePx, height: tilePx }}
                  >
                    <Sprite name={npc.sprite} size={tilePx} alt={npc.name} />
                  </div>
                );
              })}
              <div
                className={`world-hero facing-${world.facing}`}
                data-testid="world-hero"
                data-pos={`${world.x},${world.y}`}
                data-rank={state.hero ? rankIndex(state.hero.level) : 0}
                data-outfit={outfit.join("+")}
                style={{
                  left: world.x * tilePx,
                  top: world.y * tilePx,
                  width: tilePx,
                  height: tilePx,
                  transform: state.hero ? `scale(${rankPresence(state.hero.level)})` : undefined,
                }}
              >
                <DressedSprite name={heroSprite} outfit={outfit} size={tilePx} alt="hero" />
              </div>
              {promptAt && (
                <div
                  className="npc-prompt"
                  data-testid="npc-prompt"
                  style={{
                    left: promptAt.x * tilePx,
                    top: promptAt.y * tilePx - tilePx / 2,
                    width: tilePx,
                  }}
                >
                  !
                </div>
              )}
            </div>
          </div>
        )}
        {state.dialogue &&
          (() => {
            const npc = npcById(state.dialogue!.npcId);
            if (!npc) return null;
            return (
              <div className="dialogue-box panel" data-testid="dialogue">
                <Sprite name={npc.sprite} size={48} alt={npc.name} />
                <div className="dialogue-body">
                  <span className="dialogue-name">{npc.name}</span>
                  <p className="dialogue-text">{npc.lines[state.dialogue.page]}</p>
                </div>
                <button className="btn btn-small" onClick={() => dispatch({ type: "ADVANCE_DIALOGUE" })}>
                  {state.dialogue.page >= npc.lines.length - 1 ? "Farewell" : "..."}
                </button>
              </div>
            );
          })()}
      </div>
      {state.worldMessage ? (
        <p className="world-hint world-message">{state.worldMessage}</p>
      ) : (
        <div className="controls-legend" aria-label="Controls">
          <p className="controls-legend-title">Controls</p>
          <span className="legend-row">
            <span>Move</span>
            <span className="legend-key">Arrows / WASD</span>
          </span>
          <span className="legend-row">
            <span>Talk / open</span>
            <span className="legend-key">E</span>
          </span>
          <span className="legend-row">
            <span>Pack</span>
            <span className="legend-key">I</span>
          </span>
          <span className="legend-row">
            <span>Map</span>
            <span className="legend-key">M</span>
          </span>
          <span className="legend-row">
            <span>Journal</span>
            <span className="legend-key">J</span>
          </span>
          <span className="legend-row">
            <span>Pause</span>
            <span className="legend-key">Esc</span>
          </span>
          <span className="legend-note">Rebind in Options</span>
        </div>
      )}
    </div>
  );
}
