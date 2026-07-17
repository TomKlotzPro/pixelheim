import { useEffect, useMemo, useRef, useState } from "react";
import { playTrack, type TrackName } from "./audio/music";
import { SFX } from "./audio/sfx";
import { audioReady, initAudio, isMuted, setMuted } from "./audio/synth";
import { DungeonSelect } from "./components/DungeonSelect";
import { Options } from "./components/Options";
import { loadSettings, type Settings } from "./settings";
import { Battle } from "./components/Battle";
import { CharacterCreation } from "./components/CharacterCreation";
import { Inventory } from "./components/Inventory";
import { PauseMenu } from "./components/PauseMenu";
import { Shop } from "./components/Shop";
import { TitleScreen } from "./components/TitleScreen";
import { Victory } from "./components/Victory";
import { WorldScreen } from "./components/WorldScreen";
import type { GameState } from "./game/types";
import { dispatch, gameStore, useGameState } from "./state/store";
import { clearSave, decodeSaveCode, encodeSaveCode, loadSave, persistSave } from "./state/save";
import type { Direction } from "./world/types";

const SCREEN_TRACKS: Record<GameState["screen"], TrackName> = {
  title: "title",
  create: "title",
  world: "world",
  battle: "battle",
  victory: "world",
  dungeon_select: "world",
};

/** Audio is a pure side effect: watch state transitions, never touch the reducer. */
function useAudio(state: GameState) {
  const prev = useRef(state);
  const screenRef = useRef(state.screen);
  screenRef.current = state.screen;

  useEffect(() => {
    const unlock = () => {
      initAudio();
      playTrack(SCREEN_TRACKS[screenRef.current]);
    };
    window.addEventListener("pointerdown", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);

  useEffect(() => {
    if (audioReady()) playTrack(SCREEN_TRACKS[state.screen]);
  }, [state.screen]);

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
    if (state.screen === "world" && state.world && p.world) {
      if (state.world.position.mapId !== p.world.position.mapId) SFX.door();
      else if (state.world.position.x !== p.world.position.x || state.world.position.y !== p.world.position.y) {
        SFX.step();
      }
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
        if (now.shopOpen) dispatch({ type: "TOGGLE_SHOP" });
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
  }, [state.screen, settings, paused]);

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
      return <CharacterCreation onCreate={(name, roleId) => dispatch({ type: "CREATE_HERO", name, roleId })} />;
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
