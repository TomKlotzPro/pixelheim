import { useState } from "react";
import { dispatch, useGameState } from "../state/store";
import { encodeSaveCode } from "../state/save";

type PauseMenuProps = {
  onClose: () => void;
  onOpenOptions: () => void;
};

/** The Escape menu: resume, grab your save code, options, or bow out. */
export function PauseMenu({ onClose, onOpenOptions }: PauseMenuProps) {
  const state = useGameState();
  const [copied, setCopied] = useState(false);

  const copySaveCode = async () => {
    const code = encodeSaveCode(state);
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      window.prompt("Copy your save code:", code);
    }
  };

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel pause-panel" onClick={(e) => e.stopPropagation()}>
        <h2>Paused</h2>
        <div className="pause-actions">
          <button className="btn btn-primary" onClick={onClose}>
            Resume
          </button>
          <button className="btn" onClick={copySaveCode}>
            {copied ? "Copied!" : "Copy save code"}
          </button>
          <button className="btn" onClick={onOpenOptions}>
            Options
          </button>
          <button
            className="btn btn-danger"
            onClick={() => {
              dispatch({ type: "QUIT_TO_TITLE" });
              onClose();
            }}
          >
            Quit to title
          </button>
        </div>
        <p className="options-footer">Progress is saved automatically.</p>
      </div>
    </div>
  );
}
