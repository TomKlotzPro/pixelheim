import { QUESTS, questProgress, questReady } from "../../game/quests";
import { NPCS } from "../../world/npcs";
import { useGameState } from "../../state/store";
import { useEscapeClose } from "../useEscapeClose";

/** The journal: what you promised, how far along, and who to see about it. */
export function Journal({ onClose }: { onClose: () => void }) {
  useEscapeClose(onClose);
  const state = useGameState();
  const known = QUESTS.filter((q) => state.quests[q.id]);
  const active = known.filter((q) => !state.quests[q.id].done);
  const done = known.filter((q) => state.quests[q.id].done);

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel codex-panel" onClick={(e) => e.stopPropagation()} data-testid="journal">
        <div className="inventory-header">
          <h2>Journal</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <div className="panel-body">
          {known.length === 0 && <p className="empty-note">No promises yet. Talk to the villagers.</p>}
          {active.map((quest) => {
            const giver = NPCS.find((n) => n.id === quest.giver);
            const progress = questProgress(state, quest);
            return (
              <div key={quest.id} className="mastery-row" data-testid={`quest-${quest.id}`}>
                <div className="options-row">
                  <span>
                    {quest.name}
                    {questReady(state, quest) && <em className="doll-granted"> READY - see {giver?.name}</em>}
                  </span>
                  <span className="options-note">
                    {progress}/{quest.objective.count}
                  </span>
                </div>
                <div className="mastery-track">
                  <div className="mastery-fill" style={{ width: `${(progress / quest.objective.count) * 100}%` }} />
                </div>
                <p className="stat-blurb">
                  {quest.brief} ({giver?.name})
                </p>
              </div>
            );
          })}
          {done.length > 0 && <h3 className="options-title">Kept promises</h3>}
          {done.map((quest) => (
            <div key={quest.id} className="options-row">
              <span className="options-note">{quest.name}</span>
              <span className="cleared-tag">DONE</span>
            </div>
          ))}
        </div>
        <p className="options-footer">A promise is a route marked on the heart.</p>
      </div>
    </div>
  );
}
