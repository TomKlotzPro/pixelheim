import { useRef, useState } from "react";
import { Sprite } from "./Sprite";

type TitleScreenProps = {
  canContinue: boolean;
  saveCode: string | null;
  onNewGame: () => void;
  onContinue: () => void;
  /** Returns false when the pasted code is not a valid save. */
  onImportSave: (code: string) => boolean;
};

export function TitleScreen({ canContinue, saveCode, onNewGame, onContinue, onImportSave }: TitleScreenProps) {
  const [importOpen, setImportOpen] = useState(false);
  const [importError, setImportError] = useState(false);
  const [copied, setCopied] = useState(false);
  const codeRef = useRef<HTMLTextAreaElement>(null);

  const copySaveCode = async () => {
    if (!saveCode) return;
    try {
      await navigator.clipboard.writeText(saveCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard unavailable (permissions, http); show the code for manual copy.
      window.prompt("Copy your save code:", saveCode);
    }
  };

  const importSave = () => {
    const code = codeRef.current?.value ?? "";
    if (!onImportSave(code)) setImportError(true);
  };

  return (
    <div className="screen title-screen">
      <div className="title-monsters">
        <Sprite name="slime" size={48} />
        <Sprite name="goblin" size={48} />
        <Sprite name="skeleton" size={48} />
        <Sprite name="dragon" size={72} />
        <Sprite name="golem" size={48} />
        <Sprite name="ghost" size={48} />
        <Sprite name="wolf" size={48} />
      </div>
      <h1 className="game-title">PIXELHEIM</h1>
      <p className="tagline">Ten floors. One dragon. Infinite cheese wheels.</p>
      <div className="menu">
        <button className="btn btn-primary" onClick={onNewGame}>
          New Game
        </button>
        {canContinue && (
          <button className="btn" onClick={onContinue}>
            Continue
          </button>
        )}
        {canContinue && (
          <button className="btn" onClick={copySaveCode}>
            {copied ? "Copied!" : "Copy save code"}
          </button>
        )}
        <button
          className="btn"
          onClick={() => {
            setImportOpen((open) => !open);
            setImportError(false);
          }}
        >
          Import save code
        </button>
      </div>
      {importOpen && (
        <div className="panel import-panel">
          <textarea
            ref={codeRef}
            className="import-input"
            placeholder="Paste your save code (PXH1.…)"
            rows={4}
            onChange={() => setImportError(false)}
          />
          {importError && <p className="warning">That does not look like a valid save code.</p>}
          <button className="btn btn-primary" onClick={importSave}>
            Load save
          </button>
        </div>
      )}
      <p className="footnote">v0.2 - a retro RPG built with React + TypeScript</p>
    </div>
  );
}
