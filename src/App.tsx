import { useEffect, useMemo, useReducer, useRef, useState } from "react";
import { playTrack, type TrackName } from "./audio/music";
import { SFX } from "./audio/sfx";
import { audioReady, initAudio, isMuted, setMuted } from "./audio/synth";
import { Options } from "./components/Options";
import { loadSettings, type Settings } from "./settings";
import { Battle } from "./components/Battle";
import { CharacterCreation } from "./components/CharacterCreation";
import { Hub } from "./components/Hub";
import { Inventory } from "./components/Inventory";
import { Shop } from "./components/Shop";
import { TitleScreen } from "./components/TitleScreen";
import { Victory } from "./components/Victory";
import { WorldScreen } from "./components/WorldScreen";
import type { GameState } from "./game/types";
import { gameReducer, initialState } from "./state/gameReducer";
import { clearSave, decodeSaveCode, encodeSaveCode, loadSave, persistSave } from "./state/save";
import type { Direction } from "./world/types";

const SCREEN_TRACKS: Record<GameState["screen"], TrackName> = {
  title: "title",
  create: "title",
  hub: "world",
  world: "world",
  battle: "battle",
  victory: "world",
  gameover: "title",
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

const KEY_DIRECTIONS: Record<string, Direction> = {
  ArrowUp: "up",
  ArrowDown: "down",
  ArrowLeft: "left",
  ArrowRight: "right",
  w: "up",
  s: "down",
  a: "left",
  d: "right",
};

export default function App() {
  const [state, dispatch] = useReducer(gameReducer, initialState);
  const save = useMemo(() => loadSave(), []);
  const [settings, setSettings] = useState<Settings>(loadSettings);
  const [optionsOpen, setOptionsOpen] = useState(false);

  useEffect(() => {
    persistSave(state);
  }, [state]);

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
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        dispatch({ type: "EXIT_WORLD" });
        return;
      }
      const direction = KEY_DIRECTIONS[event.key];
      if (!direction) return;
      event.preventDefault();
      dispatch({ type: "MOVE", direction });
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [state.screen]);

  return (
    <div className="crt">
      <div className="corner-buttons">
        <MuteButton />
        <button className="mute-btn" aria-label="Settings" title="Settings" onClick={() => setOptionsOpen(true)}>
          {"⚙️"}
        </button>
      </div>
      <Screen state={state} save={save} dispatch={dispatch} onOpenOptions={() => setOptionsOpen(true)} />
      {state.inventoryOpen && state.hero && <Inventory state={state} dispatch={dispatch} />}
      {state.shopOpen && state.hero && <Shop state={state} dispatch={dispatch} />}
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
  dispatch,
  onOpenOptions,
}: {
  state: GameState;
  save: GameState | null;
  dispatch: React.Dispatch<Parameters<typeof gameReducer>[1]>;
  onOpenOptions: () => void;
}) {
  switch (state.screen) {
    case "title":
      return (
        <TitleScreen
          canContinue={save !== null}
          onNewGame={() => {
            clearSave();
            dispatch({ type: "NEW_GAME" });
          }}
          onContinue={() => save && dispatch({ type: "LOAD", state: save })}
          onOpenOptions={onOpenOptions}
        />
      );
    case "create":
      return <CharacterCreation onCreate={(name, roleId) => dispatch({ type: "CREATE_HERO", name, roleId })} />;
    case "hub":
      return (
        <Hub
          state={state}
          onEnterLevel={(level) => dispatch({ type: "ENTER_LEVEL", level })}
          onRest={() => dispatch({ type: "REST" })}
          onOpenInventory={() => dispatch({ type: "TOGGLE_INVENTORY" })}
          onOpenShop={() => dispatch({ type: "TOGGLE_SHOP" })}
          onEnterWorld={() =>
            dispatch({ type: "ENTER_WORLD", mapId: state.world?.position.mapId ?? "overworld" })
          }
        />
      );
    case "battle":
      return <Battle state={state} dispatch={dispatch} />;
    case "world":
      return state.world ? <WorldScreen state={state} dispatch={dispatch} /> : null;
    case "victory":
      return <Victory hero={state.hero!} onContinue={() => dispatch({ type: "RETURN_TO_HUB" })} />;
    default:
      return null;
  }
}
