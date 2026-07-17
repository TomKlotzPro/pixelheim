import { useEffect, useRef, useState } from "react";
import { SFX } from "../../audio/sfx";
import { initAudio, isMuted, setBusVolume, setMuted } from "../../audio/synth";
import { GAME_VERSION } from "../../app/changelog";
import { type BindableAction, DEFAULT_BINDINGS, keyLabel, saveSettings, type Settings } from "../../app/settings";

const CONTROL_ROWS: { action: BindableAction; label: string }[] = [
  { action: "up", label: "Move up" },
  { action: "down", label: "Move down" },
  { action: "left", label: "Move left" },
  { action: "right", label: "Move right" },
  { action: "interact", label: "Talk / interact" },
  { action: "inventory", label: "Inventory" },
  { action: "map", label: "World map" },
];

type OptionsProps = {
  settings: Settings;
  onSettingsChange: (settings: Settings) => void;
  canContinue: boolean;
  saveCode: string | null;
  onImportSave: (code: string) => boolean;
  onDeleteSave: () => void;
  onClose: () => void;
};

export function Options({
  settings,
  onSettingsChange,
  canContinue,
  saveCode,
  onImportSave,
  onDeleteSave,
  onClose,
}: OptionsProps) {
  const [muted, setMutedState] = useState(isMuted);
  const [copied, setCopied] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [importError, setImportError] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [listening, setListening] = useState<BindableAction | null>(null);
  const codeRef = useRef<HTMLTextAreaElement>(null);

  const update = (patch: Partial<Settings>) => {
    const next = { ...settings, ...patch };
    saveSettings(next);
    onSettingsChange(next);
  };

  // While a rebind is armed, the next key pressed becomes the binding.
  useEffect(() => {
    if (!listening) return;
    const capture = (event: KeyboardEvent) => {
      event.preventDefault();
      event.stopPropagation();
      if (event.key !== "Escape") {
        update({ bindings: { ...settings.bindings, [listening]: event.code } });
      }
      setListening(null);
    };
    window.addEventListener("keydown", capture, { capture: true });
    return () => window.removeEventListener("keydown", capture, { capture: true });
  });

  const copySaveCode = async () => {
    if (!saveCode) return;
    try {
      await navigator.clipboard.writeText(saveCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      window.prompt("Copy your save code:", saveCode);
    }
  };

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel inventory-panel options-panel" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <h2>Options</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>

        <div className="panel-body">
        <div className="options-section">
          <h3 className="options-title">Audio</h3>
          <label className="options-row">
            <span>Sound</span>
            <button
              className="btn btn-small"
              onClick={() => {
                initAudio();
                setMuted(!muted);
                setMutedState(!muted);
              }}
            >
              {muted ? "Muted" : "On"}
            </button>
          </label>
          <label className="options-row">
            <span>Music volume</span>
            <input
              type="range"
              min={0}
              max={100}
              value={Math.round(settings.musicVolume * 100)}
              onChange={(e) => {
                initAudio();
                const volume = Number(e.target.value) / 100;
                setBusVolume("music", volume);
                update({ musicVolume: volume });
              }}
            />
          </label>
          <label className="options-row">
            <span>Effects volume</span>
            <input
              type="range"
              min={0}
              max={100}
              value={Math.round(settings.sfxVolume * 100)}
              onChange={(e) => {
                initAudio();
                const volume = Number(e.target.value) / 100;
                setBusVolume("sfx", volume);
                update({ sfxVolume: volume });
              }}
              onPointerUp={() => SFX.coin()}
            />
          </label>
        </div>

        <div className="options-section">
          <h3 className="options-title">Video</h3>
          <label className="options-row">
            <span>CRT scanlines</span>
            <button className="btn btn-small" onClick={() => update({ scanlines: !settings.scanlines })}>
              {settings.scanlines ? "On" : "Off"}
            </button>
          </label>
          <label className="options-row">
            <span>Renderer</span>
            <button
              className="btn btn-small"
              aria-label="Toggle renderer"
              title="WebGL is the game: animations, lighting, particles. Classic is the legacy DOM renderer."
              onClick={() => {
                // Renderers are chosen once at boot; save the choice and restart.
                saveSettings({ ...settings, renderer: settings.renderer === "classic" ? "webgl" : "classic" });
                window.location.reload();
              }}
            >
              {settings.renderer === "classic" ? "Classic" : "WebGL"}
            </button>
          </label>
          <label className="options-row">
            <span>Reduce motion</span>
            <button className="btn btn-small" onClick={() => update({ reduceMotion: !settings.reduceMotion })}>
              {settings.reduceMotion ? "On" : "Off"}
            </button>
          </label>
        </div>

        <div className="options-section">
          <h3 className="options-title">Controls</h3>
          {CONTROL_ROWS.map(({ action, label }) => (
            <div key={action} className="options-row">
              <span>{label}</span>
              <button
                className={`btn btn-small key-btn ${listening === action ? "key-listening" : ""}`}
                aria-label={`Rebind ${label}`}
                onClick={() => setListening(listening === action ? null : action)}
              >
                {listening === action ? "Press a key…" : keyLabel(settings.bindings[action])}
              </button>
            </div>
          ))}
          <div className="options-row">
            <span className="options-note">Arrows always move. Enter and Space always interact.</span>
            <button className="btn btn-small" onClick={() => update({ bindings: { ...DEFAULT_BINDINGS } })}>
              Reset
            </button>
          </div>
        </div>

        <div className="options-section">
          <h3 className="options-title">Save data</h3>
          <div className="options-row options-actions">
            {canContinue && (
              <button className="btn btn-small" onClick={copySaveCode}>
                {copied ? "Copied!" : "Copy save code"}
              </button>
            )}
            <button
              className="btn btn-small"
              onClick={() => {
                setImportOpen((open) => !open);
                setImportError(false);
              }}
            >
              Import save code
            </button>
            {canContinue &&
              (confirmDelete ? (
                <button className="btn btn-small btn-danger" onClick={onDeleteSave}>
                  Really delete?
                </button>
              ) : (
                <button className="btn btn-small btn-danger" onClick={() => setConfirmDelete(true)}>
                  Delete save
                </button>
              ))}
          </div>
          {importOpen && (
            <div className="import-panel">
              <textarea
                ref={codeRef}
                className="import-input"
                placeholder="Paste your save code (PXH1.…)"
                rows={3}
                onChange={() => setImportError(false)}
              />
              {importError && <p className="warning">That does not look like a valid save code.</p>}
              <button
                className="btn btn-primary"
                onClick={() => {
                  if (!onImportSave(codeRef.current?.value ?? "")) setImportError(true);
                }}
              >
                Load save
              </button>
            </div>
          )}
        </div>

        <p className="options-footer">Pixelheim v{GAME_VERSION}</p>
        </div>
      </div>
    </div>
  );
}
