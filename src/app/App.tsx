import { useEffect, useMemo, useRef, useState } from "react";
import { canChoosePath, pathChoices } from "../game/hero/paths";
import { useAudio } from "../audio/useAudio";
import { useRankUp } from "./useRankUp";
import { useWorldKeys } from "./useWorldKeys";
import { RankUpOverlay } from "../ui/RankUpOverlay";
import { initAudio, isMuted, setMuted } from "../audio/synth";
import { DungeonSelect } from "../ui/screens/DungeonSelect";
import { Options } from "../ui/panels/Options";
import { loadSettings, type Settings } from "./settings";
import { Battle } from "../ui/screens/Battle";
import { CharacterCreation } from "../ui/screens/CharacterCreation";
import { Inventory } from "../ui/panels/Inventory";
import { MapScreen } from "../ui/panels/MapScreen";
import { PauseMenu } from "../ui/panels/PauseMenu";
import { HouseStorage } from "../ui/panels/HouseStorage";
import { Shop } from "../ui/panels/Shop";
import { TownHall } from "../ui/panels/TownHall";
import { Bank } from "../ui/panels/Bank";
import { Trophies } from "../ui/panels/Trophies";
import { Nook } from "../ui/panels/Nook";
import { TitleScreen } from "../ui/screens/TitleScreen";
import { Victory } from "../ui/screens/Victory";
import { WorldScreen } from "../ui/screens/WorldScreen";
import type { GameState } from "../game/types";
import { dispatch, useGameState } from "../state/store";
import { clearSave, decodeSaveCode, encodeSaveCode, loadSave, persistSave } from "../state/save";
import { Sprite } from "../ui/widgets/Sprite";

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
      <Sprite name={muted ? "icon_speaker_off" : "icon_speaker"} size={20} alt="" />
    </button>
  );
}

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
  const pathPending = state.hero ? canChoosePath(state.hero) : false;
  const { title: rankUp, dismiss: dismissRankUp } = useRankUp(state, pathPending);
  const rankUpChoices = rankUp && state.hero && pathPending ? pathChoices(state.hero) : [];

  const hasSaveData = state.hero !== null || save !== null;
  const saveCode = state.hero ? encodeSaveCode(state) : save ? encodeSaveCode(save) : null;

  // Dev entry for the tile engine until the real world ships (PIX-25).
  useEffect(() => {
    if (new URLSearchParams(window.location.search).has("world")) {
      dispatch({ type: "ENTER_WORLD", mapId: "demo" });
    }
  }, []);

  useWorldKeys(state, settings, paused, setPaused, mapOpen, setMapOpen);

  // The HUD's Map button speaks the same event language as the Journal's -
  // a synthetic KeyboardEvent broke silently whenever keys were rebound.
  useEffect(() => {
    const toggle = () => setMapOpen((open) => !open);
    window.addEventListener("pixelheim:map", toggle);
    return () => window.removeEventListener("pixelheim:map", toggle);
  }, []);

  return (
    <div className="crt">
      <div className="corner-buttons">
        <MuteButton />
        <button className="mute-btn" aria-label="Settings" title="Settings" onClick={() => setOptionsOpen(true)}>
          <Sprite name="icon_gear" size={20} alt="" />
        </button>
      </div>
      <Screen state={state} save={save} onOpenOptions={() => setOptionsOpen(true)} />
      {state.openPanel === "inventory" && state.hero && <Inventory />}
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
      {state.openPanel === "shop" && state.hero && <Shop />}
      {state.openPanel === "hall" && state.hero && <TownHall />}
      {state.openPanel === "bank" && state.hero && <Bank />}
      {state.openPanel === "trophies" && state.hero && <Trophies />}
      {state.openPanel === "nook" && state.hero && <Nook />}
      {state.openPanel === "storage" && state.hero && <HouseStorage />}
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
        <RankUpOverlay hero={state.hero} title={rankUp} choices={rankUpChoices} onDismiss={dismissRankUp} />
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
      return (
        <CharacterCreation onCreate={(name, roleId, look) => dispatch({ type: "CREATE_HERO", name, roleId, look })} />
      );
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
