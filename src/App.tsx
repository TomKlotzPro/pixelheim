import { useEffect, useMemo, useReducer } from "react";
import { Battle } from "./components/Battle";
import { CharacterCreation } from "./components/CharacterCreation";
import { Hub } from "./components/Hub";
import { Inventory } from "./components/Inventory";
import { TitleScreen } from "./components/TitleScreen";
import { Victory } from "./components/Victory";
import type { GameState } from "./game/types";
import { gameReducer, initialState } from "./state/gameReducer";
import { clearSave, loadSave, persistSave } from "./state/save";

export default function App() {
  const [state, dispatch] = useReducer(gameReducer, initialState);
  const save = useMemo(() => loadSave(), []);

  useEffect(() => {
    persistSave(state);
  }, [state]);

  return (
    <div className="crt">
      <Screen state={state} save={save} dispatch={dispatch} />
      {state.inventoryOpen && state.hero && <Inventory state={state} dispatch={dispatch} />}
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
          onNewGame={() => {
            clearSave();
            dispatch({ type: "NEW_GAME" });
          }}
          onContinue={() => save && dispatch({ type: "LOAD", state: save })}
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
        />
      );
    case "battle":
      return <Battle state={state} dispatch={dispatch} />;
    case "victory":
      return <Victory hero={state.hero!} onContinue={() => dispatch({ type: "RETURN_TO_HUB" })} />;
    default:
      return null;
  }
}
