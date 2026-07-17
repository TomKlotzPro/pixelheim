import type { GameState } from "../game/types";
import { audioReady, midi, now, playNoise, playTone, rampMusicFade } from "./synth";

/**
 * The score: chiptune tracks as data (channels of [midiNote, beats] pairs,
 * note 0 = rest), looped by a lookahead scheduler. Every PLACE has its own
 * theme now - the town is warm, the Deepwood is old, the Mirefen is drowned -
 * and track changes crossfade instead of cutting.
 */
type Note = [number, number];

type Track = {
  bpm: number;
  lead: Note[];
  bass: Note[];
  /** Optional third voice: thirds, arps, countermelody. */
  harmony?: Note[];
  /** Noise hat on every beat when true. */
  hats?: boolean;
  /** Kick/snare per beat: "k", "s" or "." repeated over the bar loop. */
  drums?: string;
  leadType?: OscillatorType;
  harmonyType?: OscillatorType;
};

export type TrackName =
  | "title"
  | "town"
  | "world"
  | "deepwood"
  | "mirefen"
  | "interior"
  | "descent"
  | "battle"
  | "boss"
  | "victory";

const TRACKS: Record<TrackName, Track> = {
  // Slow and noble, A minor. The mountain waits.
  title: {
    bpm: 100,
    lead: [
      [69, 1.5], [72, 0.5], [76, 2],
      [74, 1.5], [72, 0.5], [69, 2],
      [67, 1.5], [69, 0.5], [72, 2],
      [71, 1], [67, 1], [64, 2],
      [69, 1.5], [72, 0.5], [76, 2],
      [79, 1.5], [76, 0.5], [74, 2],
      [72, 1], [74, 1], [76, 1], [72, 1],
      [69, 4],
    ],
    bass: [
      [45, 2], [45, 2], [41, 2], [41, 2],
      [43, 2], [43, 2], [40, 2], [40, 2],
      [45, 2], [45, 2], [41, 2], [41, 2],
      [43, 2], [43, 2], [45, 2], [45, 2],
    ],
    harmony: [
      [0, 4], [57, 4], [0, 4], [55, 4],
      [0, 4], [57, 4], [0, 4], [57, 4],
    ],
    harmonyType: "triangle",
  },
  // Warm G major folk tune: chimney smoke and market chatter.
  town: {
    bpm: 108,
    lead: [
      [67, 1], [71, 0.5], [74, 0.5], [72, 1], [71, 1],
      [69, 1], [71, 0.5], [72, 0.5], [71, 1.5], [67, 0.5],
      [64, 1], [67, 0.5], [71, 0.5], [69, 1], [67, 1],
      [66, 1], [62, 1], [67, 2],
      [67, 1], [71, 0.5], [74, 0.5], [76, 1], [74, 1],
      [72, 1], [71, 0.5], [69, 0.5], [71, 1.5], [72, 0.5],
      [74, 1], [72, 0.5], [71, 0.5], [69, 1], [66, 1],
      [67, 3], [0, 1],
    ],
    bass: [
      [43, 1], [50, 1], [47, 1], [50, 1],
      [45, 1], [52, 1], [45, 1], [52, 1],
      [40, 1], [47, 1], [45, 1], [47, 1],
      [38, 1], [45, 1], [43, 1], [50, 1],
    ],
    harmony: [
      [0, 0.5], [59, 0.5], [62, 0.5], [59, 0.5], [0, 0.5], [59, 0.5], [62, 0.5], [59, 0.5],
      [0, 0.5], [60, 0.5], [64, 0.5], [60, 0.5], [0, 0.5], [60, 0.5], [64, 0.5], [60, 0.5],
      [0, 0.5], [59, 0.5], [62, 0.5], [59, 0.5], [0, 0.5], [57, 0.5], [60, 0.5], [57, 0.5],
      [0, 0.5], [57, 0.5], [62, 0.5], [57, 0.5], [0, 0.5], [59, 0.5], [62, 0.5], [59, 0.5],
    ],
    leadType: "triangle",
    harmonyType: "sine",
  },
  // Bouncy C major. Adventure smells like grass.
  world: {
    bpm: 132,
    lead: [
      [72, 0.5], [76, 0.5], [79, 1], [76, 0.5], [72, 0.5], [74, 1],
      [72, 0.5], [74, 0.5], [76, 1], [72, 1], [67, 1],
      [69, 0.5], [72, 0.5], [76, 1], [74, 0.5], [72, 0.5], [71, 1],
      [67, 0.5], [71, 0.5], [74, 1], [72, 2],
    ],
    bass: [
      [48, 1], [55, 1], [48, 1], [55, 1],
      [53, 1], [60, 1], [53, 1], [60, 1],
      [45, 1], [52, 1], [45, 1], [52, 1],
      [43, 1], [50, 1], [48, 1], [55, 1],
    ],
    harmony: [
      [0, 2], [64, 1], [62, 1],
      [0, 2], [64, 1], [65, 1],
      [0, 2], [64, 1], [62, 1],
      [0, 2], [62, 1], [64, 1],
    ],
    hats: true,
    harmonyType: "triangle",
  },
  // D dorian, wandering. The trees were here first.
  deepwood: {
    bpm: 92,
    lead: [
      [62, 1.5], [65, 0.5], [69, 1], [67, 1],
      [65, 1], [64, 1], [62, 2],
      [60, 1.5], [62, 0.5], [65, 1], [64, 1],
      [62, 1], [59, 1], [62, 2],
      [62, 1.5], [65, 0.5], [69, 1], [71, 1],
      [72, 1], [69, 1], [67, 2],
      [65, 1], [67, 0.5], [65, 0.5], [64, 1], [60, 1],
      [62, 4],
    ],
    bass: [
      [38, 3], [41, 1],
      [36, 3], [40, 1],
      [38, 3], [41, 1],
      [43, 2], [36, 2],
      [38, 3], [41, 1],
      [36, 3], [40, 1],
      [41, 2], [43, 2],
      [38, 4],
    ],
    harmony: [
      [0, 8], [53, 2], [50, 2], [52, 2], [0, 2],
      [0, 8], [55, 2], [53, 2], [50, 2], [0, 2],
    ],
    leadType: "triangle",
    harmonyType: "sine",
  },
  // B minor, sparse and low. Bells under the water.
  mirefen: {
    bpm: 76,
    lead: [
      [59, 2], [62, 1], [61, 1],
      [59, 2], [54, 2],
      [57, 2], [59, 1], [62, 1],
      [61, 2], [0, 2],
      [59, 2], [62, 1], [66, 1],
      [64, 2], [62, 2],
      [61, 1], [59, 1], [57, 1], [54, 1],
      [59, 3], [0, 1],
    ],
    bass: [
      [35, 4], [30, 4],
      [33, 4], [35, 4],
      [35, 4], [31, 4],
      [33, 4], [35, 4],
    ],
    harmony: [
      [0, 6], [47, 2],
      [0, 6], [45, 2],
      [0, 6], [47, 2],
      [0, 6], [42, 2],
    ],
    leadType: "sine",
    harmonyType: "triangle",
  },
  // Soft C major lull: candlelight and a counter to lean on.
  interior: {
    bpm: 96,
    lead: [
      [64, 1], [67, 1], [72, 1.5], [71, 0.5],
      [69, 1], [67, 1], [64, 2],
      [65, 1], [69, 1], [72, 1.5], [74, 0.5],
      [72, 1], [69, 1], [67, 2],
      [64, 1], [67, 1], [72, 1.5], [71, 0.5],
      [69, 1], [71, 1], [72, 2],
      [74, 1], [72, 0.5], [71, 0.5], [69, 1], [65, 1],
      [64, 3], [0, 1],
    ],
    bass: [
      [48, 2], [43, 2],
      [45, 2], [40, 2],
      [41, 2], [48, 2],
      [43, 2], [48, 2],
      [48, 2], [43, 2],
      [45, 2], [40, 2],
      [41, 2], [43, 2],
      [48, 4],
    ],
    leadType: "triangle",
  },
  // A minor pulse before the plunge. Count your potions.
  descent: {
    bpm: 120,
    lead: [
      [69, 1], [0, 0.5], [69, 0.5], [72, 1], [71, 1],
      [69, 1], [0, 0.5], [69, 0.5], [67, 1], [64, 1],
      [69, 1], [0, 0.5], [69, 0.5], [72, 1], [74, 1],
      [76, 1], [74, 0.5], [72, 0.5], [69, 2],
    ],
    bass: [
      [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5],
      [31, 0.5], [43, 0.5], [31, 0.5], [43, 0.5], [32, 0.5], [44, 0.5], [32, 0.5], [44, 0.5],
    ],
    drums: "k...k...",
  },
  // Driving E minor. Something wants to eat you.
  battle: {
    bpm: 150,
    lead: [
      [64, 0.5], [64, 0.5], [67, 0.5], [64, 0.5], [70, 1], [67, 1],
      [64, 0.5], [64, 0.5], [67, 0.5], [70, 0.5], [72, 1], [71, 1],
      [64, 0.5], [64, 0.5], [67, 0.5], [64, 0.5], [62, 1], [64, 1],
      [59, 0.5], [62, 0.5], [64, 0.5], [67, 0.5], [64, 2],
    ],
    bass: [
      [40, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [43, 0.5], [43, 0.5], [45, 0.5], [45, 0.5],
      [40, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [47, 0.5], [47, 0.5], [43, 0.5], [43, 0.5],
    ],
    hats: true,
    drums: "k.s.k.s.",
  },
  // E phrygian, faster and meaner. The floor has a name and it hates you.
  boss: {
    bpm: 164,
    lead: [
      [64, 0.5], [65, 0.5], [64, 0.5], [62, 0.5], [64, 1], [71, 1],
      [64, 0.5], [65, 0.5], [67, 0.5], [65, 0.5], [64, 1], [62, 1],
      [64, 0.5], [65, 0.5], [64, 0.5], [62, 0.5], [64, 1], [72, 1],
      [71, 0.5], [70, 0.5], [67, 0.5], [65, 0.5], [64, 2],
    ],
    bass: [
      [28, 0.5], [40, 0.5], [28, 0.5], [40, 0.5], [29, 0.5], [41, 0.5], [29, 0.5], [41, 0.5],
      [28, 0.5], [40, 0.5], [28, 0.5], [40, 0.5], [31, 0.5], [43, 0.5], [29, 0.5], [41, 0.5],
    ],
    harmony: [
      [0, 4], [52, 2], [53, 2],
      [0, 4], [55, 2], [53, 2],
    ],
    hats: true,
    drums: "kks.kks.",
    harmonyType: "sawtooth",
  },
  // C major laurels. You earned the cheese.
  victory: {
    bpm: 104,
    lead: [
      [72, 0.5], [76, 0.5], [79, 1], [79, 0.5], [76, 0.5], [79, 1],
      [81, 1], [79, 1], [76, 2],
      [72, 0.5], [76, 0.5], [79, 1], [84, 1.5], [83, 0.5],
      [81, 1], [83, 1], [84, 2],
    ],
    bass: [
      [48, 1], [55, 1], [52, 1], [55, 1],
      [53, 1], [57, 1], [48, 1], [55, 1],
      [48, 1], [55, 1], [52, 1], [55, 1],
      [50, 1], [55, 1], [48, 2],
    ],
    harmony: [
      [64, 1], [67, 1], [72, 2],
      [65, 1], [69, 1], [67, 2],
      [64, 1], [67, 1], [72, 2],
      [65, 1], [67, 1], [72, 2],
    ],
    harmonyType: "triangle",
  },
};

/** Which theme a given game state deserves. Places, not screens. */
export function trackForState(state: GameState): TrackName {
  switch (state.screen) {
    case "title":
    case "create":
      return "title";
    case "victory":
      return "victory";
    case "dungeon_select":
      return "descent";
    case "battle": {
      const id = state.battle?.monster.def.id;
      return id === "dragon" || id === "lich" ? "boss" : "battle";
    }
    default: {
      const map = state.world?.position.mapId ?? "town";
      if (map === "deepwood") return "deepwood";
      if (map === "mirefen") return "mirefen";
      if (map === "town") return "town";
      if (map === "overworld" || map === "demo") return "world";
      return "interior";
    }
  }
}

let current: TrackName | null = null;
let timer: ReturnType<typeof setInterval> | null = null;
let fadeTimer: ReturnType<typeof setTimeout> | null = null;
let channelBeats: { notes: Note[]; index: number; nextTime: number; kind: "lead" | "bass" | "harmony" }[] = [];
let hatTime = 0;
let hatsOn = false;
let drums = "";
let drumIndex = 0;
let drumTime = 0;
let leadType: OscillatorType = "square";
let harmonyType: OscillatorType = "square";
let bpm = 120;

const LOOKAHEAD_S = 0.3;
const TICK_MS = 100;
const FADE_S = 0.35;

const CHANNEL_VOLUME: Record<"lead" | "bass" | "harmony", number> = {
  lead: 0.035,
  bass: 0.05,
  harmony: 0.022,
};

function kick(at: number): void {
  playTone({ freq: 110, duration: 0.09, type: "sine", slideTo: 40, volume: 0.09, at, bus: "music" });
}

function snare(at: number): void {
  playNoise({ duration: 0.06, volume: 0.03, at, bus: "music" });
  playTone({ freq: 190, duration: 0.05, type: "triangle", slideTo: 120, volume: 0.03, at, bus: "music" });
}

function schedule(): void {
  if (!audioReady()) return;
  const horizon = now() + LOOKAHEAD_S;
  const beat = 60 / bpm;
  for (const channel of channelBeats) {
    while (channel.nextTime < horizon) {
      const [note, beats] = channel.notes[channel.index];
      const duration = beats * beat;
      if (note > 0) {
        playTone({
          freq: midi(note),
          duration: Math.min(duration * 0.9, duration - 0.02),
          type: channel.kind === "lead" ? leadType : channel.kind === "harmony" ? harmonyType : "triangle",
          volume: CHANNEL_VOLUME[channel.kind],
          at: channel.nextTime,
          bus: "music",
        });
      }
      channel.nextTime += duration;
      channel.index = (channel.index + 1) % channel.notes.length;
    }
  }
  if (hatsOn) {
    while (hatTime < horizon) {
      playNoise({ duration: 0.03, volume: 0.012, at: hatTime, bus: "music" });
      hatTime += beat;
    }
  }
  if (drums) {
    while (drumTime < horizon) {
      const hit = drums[drumIndex % drums.length];
      if (hit === "k") kick(drumTime);
      if (hit === "s") snare(drumTime);
      drumIndex += 1;
      drumTime += beat;
    }
  }
}

function startTrack(name: TrackName): void {
  const track = TRACKS[name];
  current = name;
  bpm = track.bpm;
  leadType = track.leadType ?? "square";
  harmonyType = track.harmonyType ?? "square";
  const start = now() + 0.1;
  channelBeats = [
    { notes: track.lead, index: 0, nextTime: start, kind: "lead" },
    { notes: track.bass, index: 0, nextTime: start, kind: "bass" },
  ];
  if (track.harmony) channelBeats.push({ notes: track.harmony, index: 0, nextTime: start, kind: "harmony" });
  hatsOn = track.hats ?? false;
  hatTime = start;
  drums = track.drums ?? "";
  drumIndex = 0;
  drumTime = start;
  timer = setInterval(schedule, TICK_MS);
  schedule();
}

function stopScheduler(): void {
  if (timer) clearInterval(timer);
  timer = null;
  channelBeats = [];
  drums = "";
}

/** Crossfade to a track: fade out, swap the scheduler, fade back in. */
export function playTrack(name: TrackName): void {
  if (current === name) return;
  if (fadeTimer) clearTimeout(fadeTimer);
  if (!current) {
    rampMusicFade(1, 0.05);
    startTrack(name);
    return;
  }
  current = name; // rapid changes settle on the last request
  rampMusicFade(0, FADE_S);
  fadeTimer = setTimeout(() => {
    stopScheduler();
    rampMusicFade(1, FADE_S);
    startTrack(name);
  }, FADE_S * 1000);
}

export function stopMusic(): void {
  if (fadeTimer) clearTimeout(fadeTimer);
  fadeTimer = null;
  stopScheduler();
  current = null;
}

export function currentTrack(): TrackName | null {
  return current;
}
