import { useEffect, useMemo, useRef, useState } from "react";
import { playTrack, trackForState } from "../audio/music";
import { ambienceForState, setAmbience } from "../audio/ambience";
import { heroSprite } from "../game/hero/character";
import { rankIndex, rankTitle } from "../game/hero/ranks";
import { canChooseSpec } from "../game/hero/specs";
import { SFX } from "../audio/sfx";
import { audioReady, initAudio, isMuted, setMuted } from "../audio/synth";
import { DungeonSelect } from "../ui/screens/DungeonSelect";
import { Options } from "../ui/panels/Options";
import { loadSettings, type Settings } from "./settings";
import { Battle } from "../ui/screens/Battle";
import { CharacterCreation } from "../ui/screens/CharacterCreation";
import { Inventory } from "../ui/panels/Inventory";
import { MapScreen } from "../ui/panels/MapScreen";
import { PauseMenu } from "../ui/panels/PauseMenu";
import { Shop } from "../ui/panels/Shop";
import { TitleScreen } from "../ui/screens/TitleScreen";
import { Victory } from "../ui/screens/Victory";
import { WorldScreen } from "../ui/screens/WorldScreen";
import type { GameState } from "../game/types";
import { dispatch, gameStore, useGameState } from "../state/store";
import { clearSave, decodeSaveCode, encodeSaveCode, loadSave, persistSave } from "../state/save";
import type { Direction } from "../world/types";



/** The ascension card: shows for a few seconds when the hero crosses a rank. */
function useRankUp(state: GameState): string | null {
  const [title, setTitle] = useState<string | null>(null);
  const prevLevel = useRef(state.hero?.level ?? 0);
  const level = state.hero?.level ?? 0;
  useEffect(() => {
    const before = prevLevel.current;
    prevLevel.current = level;
    const hero = gameStore.getState().hero;
    if (level > before && before > 0 && rankIndex(level) > rankIndex(before) && hero) {
      setTitle(rankTitle(hero));
      SFX.evolve();
    }
  }, [level]);
  // The dismiss timer lives on the title alone: an hp tick or xp gain used
  // to clean it up and strand the card on screen forever (PIX-100).
  useEffect(() => {
    if (!title) return;
    const timer = setTimeout(() => setTitle(null), 4200);
    return () => clearTimeout(timer);
  }, [title]);
  return title;
}

/** Audio is a pure side effect: watch state transitions, never touch the reducer. */
function useAudio(state: GameState) {
  const prev = useRef(state);
  const stateRef = useRef(state);
  stateRef.current = state;

  useEffect(() => {
    const unlock = () => {
      initAudio();
      playTrack(trackForState(stateRef.current));
      setAmbience(ambienceForState(stateRef.current));
    };
    window.addEventListener("pointerdown", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);

  const mapId = state.world?.position.mapId;
  const monsterId = state.battle?.monster.def.id;
  useEffect(() => {
    if (!audioReady()) return;
    playTrack(trackForState(stateRef.current));
    setAmbience(ambienceForState(stateRef.current));
  }, [state.screen, mapId, monsterId]);

  useEffect(() => {
    const p = prev.current;
    prev.current = state;
    if (!audioReady() || state === p) return;

    if (state.hero && p.hero) {
      const sameFight = state.battle && p.battle && state.battle.encounterIndex === p.battle.encounterIndex;
      if (state.hero.level > p.hero.level) {
        SFX.levelUp();
      } else if (sameFight) {
        if (state.battle!.monster.hp < p.battle!.monster.hp) SFX.hit();
        if (state.hero.hp < p.hero.hp) SFX.hurt();
        if (state.hero.hp > p.hero.hp) SFX.heal();
      }
      if (state.gold > p.gold) SFX.coin();
      if (state.battle && p.battle && state.gear.length > p.gear.length) SFX.drop();
      if (state.battle?.phase === "cleared" && p.battle?.phase !== "cleared") SFX.victory();
      if (state.battle?.phase === "lost" && p.battle?.phase !== "lost") SFX.defeat();
    }
    if (state.hero && p.hero) {
      // the wardrobe, the workshop, the mind: each has a voice now
      if (state.equipped !== p.equipped) SFX.equip();
      if (state.hero.skillNodes.length > p.hero.skillNodes.length) SFX.learn();
      const jobsGrew = (Object.keys(state.hero.jobs) as (keyof typeof state.hero.jobs)[]).some(
        (job) => state.hero!.jobs[job].xp > p.hero!.jobs[job].xp || state.hero!.jobs[job].level > p.hero!.jobs[job].level,
      );
      if (jobsGrew && !state.battle) SFX.craft();
    }
    if (state.world && p.world && state.world.openedChests.length > p.world.openedChests.length) SFX.chest();
    if (state.screen === "battle" && p.screen === "world") SFX.bump();
    if (state.screen === "world" && state.world && p.world) {
      const moved = Math.abs(state.world.position.x - p.world.position.x) + Math.abs(state.world.position.y - p.world.position.y);
      if (state.world.position.mapId !== p.world.position.mapId) SFX.door();
      else if (moved > 2) SFX.travel();
      else if (moved > 0) SFX.step();
    }
  }, [state]);
}

function MuteButton() {
  const [muted, setMutedState] = useState(isMuted);
  return (
    <button
      className="mute-btn"
      aria-label={muted ? "Unmute" : "Mute"}
      title={muted ? "Unmute" : "Mute"}
      onClick={() => {
        initAudio();
        setMuted(!muted);
        setMutedState(!muted);
      }}
    >
      {muted ? "\u{1F507}" : "\u{1F50A}"}
    </button>
  );
}

/** Arrows always move regardless of custom bindings. */
const ARROW_DIRECTIONS: Record<string, Direction> = {
  ArrowUp: "up",
  ArrowDown: "down",
  ArrowLeft: "left",
  ArrowRight: "right",
};

export default function App() {
  const state = useGameState();
  const save = useMemo(() => loadSave(), []);
  const [settings, setSettings] = useState<Settings>(loadSettings);
  const [optionsOpen, setOptionsOpen] = useState(false);
  const [paused, setPaused] = useState(false);
  const [mapOpen, setMapOpen] = useState(false);
  const [battleFlash, setBattleFlash] = useState(false);
  const lastScreen = useRef(state.screen);

  // Entering a fight blinks the screen: a beat of black between world and battle.
  useEffect(() => {
    const from = lastScreen.current;
    lastScreen.current = state.screen;
    if (from === "world" && state.screen === "battle" && !settings.reduceMotion) {
      setBattleFlash(true);
      const timer = setTimeout(() => setBattleFlash(false), 450);
      return () => clearTimeout(timer);
    }
  }, [state.screen, settings.reduceMotion]);

  useEffect(() => {
    document.documentElement.classList.toggle("no-scanlines", !settings.scanlines);
    document.documentElement.classList.toggle("reduce-motion", settings.reduceMotion);
  }, [settings]);

  useAudio(state);
  const rankUp = useRankUp(state);

  const hasSaveData = state.hero !== null || save !== null;
  const saveCode = state.hero ? encodeSaveCode(state) : save ? encodeSaveCode(save) : null;

  // Dev entry for the tile engine until the real world ships (PIX-25).
  useEffect(() => {
    if (new URLSearchParams(window.location.search).has("world")) {
      dispatch({ type: "ENTER_WORLD", mapId: "demo" });
    }
  }, []);

  useEffect(() => {
    if (state.screen !== "world") return;
    const { bindings } = settings;
    const onKeyDown = (event: KeyboardEvent) => {
      // Escape peels back one layer at a time: menus first, then the pause
      // screen. Fresh state via the store: this listener outlives renders.
      if (event.key === "Escape") {
        const now = gameStore.getState();
        if (mapOpen) setMapOpen(false);
        else if (now.shopOpen) dispatch({ type: "TOGGLE_SHOP" });
        else if (now.inventoryOpen) dispatch({ type: "TOGGLE_INVENTORY" });
        else if (now.dialogue) dispatch({ type: "ADVANCE_DIALOGUE" });
        else if (!now.hero) dispatch({ type: "EXIT_WORLD" });
        else setPaused((open) => !open);
        return;
      }
      if (paused) return;
      if (event.code === bindings.inventory) {
        dispatch({ type: "TOGGLE_INVENTORY" });
        return;
      }
      if (event.code === bindings.map && state.hero) {
        setMapOpen((open) => !open);
        return;
      }
      if (mapOpen) return;
      // Enter and Space always interact, on top of the custom binding.
      if (event.code === bindings.interact || event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        dispatch({ type: "INTERACT" });
        return;
      }
      const direction =
        ARROW_DIRECTIONS[event.key] ??
        (event.code === bindings.up
          ? "up"
          : event.code === bindings.down
            ? "down"
            : event.code === bindings.left
              ? "left"
              : event.code === bindings.right
                ? "right"
                : null);
      if (!direction) return;
      event.preventDefault();
      dispatch({ type: "MOVE", direction });
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [state.screen, settings, paused, mapOpen, state.hero]);

  return (
    <div className="crt">
      <div className="corner-buttons">
        <MuteButton />
        <button className="mute-btn" aria-label="Settings" title="Settings" onClick={() => setOptionsOpen(true)}>
          {"⚙️"}
        </button>
      </div>
      <Screen state={state} save={save} onOpenOptions={() => setOptionsOpen(true)} />
      {state.inventoryOpen && state.hero && <Inventory />}
      {battleFlash && <div className="battle-flash" aria-hidden="true" />}
      {mapOpen && state.screen === "world" && state.hero && <MapScreen onClose={() => setMapOpen(false)} />}
      {paused && state.screen === "world" && state.hero && (
        <PauseMenu
          onClose={() => setPaused(false)}
          onOpenOptions={() => {
            setPaused(false);
            setOptionsOpen(true);
          }}
        />
      )}
      {state.shopOpen && state.hero && <Shop />}
      {optionsOpen && (
        <Options
          settings={settings}
          onSettingsChange={setSettings}
          canContinue={hasSaveData}
          saveCode={saveCode}
          onImportSave={(code) => {
            const imported = decodeSaveCode(code);
            if (!imported) return false;
            persistSave(imported);
            dispatch({ type: "LOAD", state: imported });
            setOptionsOpen(false);
            return true;
          }}
          onDeleteSave={() => {
            clearSave();
            window.location.reload();
          }}
          onClose={() => setOptionsOpen(false)}
        />
      )}
      {rankUp && state.hero && (
        <div className="rankup-overlay" aria-live="polite">
          <div className="rankup-bar rankup-bar-top" />
          <div className="rankup-bar rankup-bar-bottom" />
          <span className="rankup-rays" aria-hidden="true" />
          <span
            className="rankup-hero"
            aria-hidden="true"
            style={{ backgroundImage: `url(${import.meta.env.BASE_URL}sprites/${heroSprite(state.hero)}_walk.png)` }}
          />
          <div className="rankup-card">
            <span className="rankup-eyebrow">Ascension</span>
            <span className="rankup-title">{rankUp}</span>
            <span className="rankup-note">+1 bonus skill point</span>
            {canChooseSpec(state.hero) && <span className="rankup-note">A specialization awaits in Skills</span>}
          </div>
        </div>
      )}
    </div>
  );
}

function Screen({
  state,
  save,
  onOpenOptions,
}: {
  state: GameState;
  save: GameState | null;
  onOpenOptions: () => void;
}) {
  switch (state.screen) {
    case "title":
      return (
        <TitleScreen
          canContinue={state.hero !== null || save !== null}
          onNewGame={() => {
            clearSave();
            dispatch({ type: "NEW_GAME" });
          }}
          onContinue={() => {
            // A live hero (paused out to the title) resumes in place;
            // otherwise load the persisted save.
            if (state.hero) dispatch({ type: "RETURN_TO_WORLD" });
            else if (save) dispatch({ type: "LOAD", state: save });
          }}
          onOpenOptions={onOpenOptions}
        />
      );
    case "create":
      return <CharacterCreation onCreate={(name, roleId, look) => dispatch({ type: "CREATE_HERO", name, roleId, look })} />;
    case "battle":
      return <Battle />;
    case "world":
      return state.world ? <WorldScreen /> : null;
    case "dungeon_select":
      return state.dungeonSelect ? <DungeonSelect /> : null;
    case "victory":
      return state.hero ? <Victory hero={state.hero} onContinue={() => dispatch({ type: "RETURN_TO_WORLD" })} /> : null;
    default:
      return null;
  }
}
