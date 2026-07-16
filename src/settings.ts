/** The game actions a key can be bound to. */
export type BindableAction = "up" | "down" | "left" | "right" | "interact" | "inventory";

/**
 * Bindings hold `KeyboardEvent.code` values (physical key positions), so the
 * defaults land on ZQSD for AZERTY players and WASD for QWERTY without any
 * configuration. Arrows, Enter and Space stay hardwired on top of these.
 */
export type Bindings = Record<BindableAction, string>;

export const DEFAULT_BINDINGS: Bindings = {
  up: "KeyW",
  down: "KeyS",
  left: "KeyA",
  right: "KeyD",
  interact: "KeyE",
  inventory: "KeyI",
};

/**
 * Device preferences: volumes, scanlines, motion, controls. Deliberately NOT
 * part of the save (they should not travel with save codes across devices).
 */
export type Settings = {
  /** 0..1 */
  musicVolume: number;
  /** 0..1 */
  sfxVolume: number;
  scanlines: boolean;
  reduceMotion: boolean;
  bindings: Bindings;
};

const SETTINGS_KEY = "pixelheim-settings";

export const DEFAULT_SETTINGS: Settings = {
  musicVolume: 0.7,
  sfxVolume: 0.7,
  scanlines: true,
  reduceMotion: false,
  bindings: { ...DEFAULT_BINDINGS },
};

export function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS, bindings: { ...DEFAULT_BINDINGS } };
    const parsed = JSON.parse(raw) as Partial<Settings>;
    return {
      ...DEFAULT_SETTINGS,
      ...parsed,
      bindings: { ...DEFAULT_BINDINGS, ...parsed.bindings },
    };
  } catch {
    return { ...DEFAULT_SETTINGS, bindings: { ...DEFAULT_BINDINGS } };
  }
}

/** Human label for a KeyboardEvent.code, for the options screen. */
export function keyLabel(code: string): string {
  if (code.startsWith("Key")) return code.slice(3);
  if (code.startsWith("Digit")) return code.slice(5);
  const arrows: Record<string, string> = { ArrowUp: "↑", ArrowDown: "↓", ArrowLeft: "←", ArrowRight: "→" };
  return arrows[code] ?? code;
}

export function saveSettings(settings: Settings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    // storage unavailable; settings just will not stick
  }
}
