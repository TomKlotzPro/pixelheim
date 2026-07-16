import { useEffect, useMemo, useReducer } from "react";
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

  useEffect(() => {
    persistSave(state);
  }, [state]);

  // Dev entry for the tile engine until the real world ships (PIX-25).
  useEffect(() => {
    if (new URLSearchParams(window.location.search).has("world")) {
      dispatch({ type: "ENTER_WORLD", mapId: "demo" });
    }
  }, []);

  useEffect(() => {
    if (state.screen !== "world") return;
    const onKeyDown = (event: KeyboardEvent) => {
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
      <Screen state={state} save={save} dispatch={dispatch} />
      {state.inventoryOpen && state.hero && <Inventory state={state} dispatch={dispatch} />}
      {state.shopOpen && state.hero && <Shop state={state} dispatch={dispatch} />}
    </div>
  );
}

function Screen({
  state,
  save,
  dispatch,
}: {
  state: GameState;
  save: GameState | null;
  dispatch: React.Dispatch<Parameters<typeof gameReducer>[1]>;
}) {
  switch (state.screen) {
    case "title":
      return (
        <TitleScreen
          canContinue={save !== null}
          saveCode={save ? encodeSaveCode(save) : null}
          onNewGame={() => {
            clearSave();
            dispatch({ type: "NEW_GAME" });
          }}
          onContinue={() => save && dispatch({ type: "LOAD", state: save })}
          onImportSave={(code) => {
            const imported = decodeSaveCode(code);
            if (!imported) return false;
            persistSave(imported);
            dispatch({ type: "LOAD", state: imported });
            return true;
          }}
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
