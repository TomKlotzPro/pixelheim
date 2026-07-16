/**
 * Device preferences: volumes, scanlines, motion. Deliberately NOT part of
 * the save (they should not travel with save codes across devices).
 */
export type Settings = {
  /** 0..1 */
  musicVolume: number;
  /** 0..1 */
  sfxVolume: number;
  scanlines: boolean;
  reduceMotion: boolean;
};

const SETTINGS_KEY = "pixelheim-settings";

export const DEFAULT_SETTINGS: Settings = {
  musicVolume: 0.7,
  sfxVolume: 0.7,
  scanlines: true,
  reduceMotion: false,
};

export function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    return { ...DEFAULT_SETTINGS, ...(JSON.parse(raw) as Partial<Settings>) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(settings: Settings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    // storage unavailable; settings just will not stick
  }
}
