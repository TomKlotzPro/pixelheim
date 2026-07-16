import { audioReady, midi, now, playNoise, playTone } from "./synth";

/**
 * A chiptune track: channels of [midiNote, beats] pairs (note 0 = rest),
 * looped by a lookahead scheduler. Tracks are data, like sprites and maps.
 */
type Note = [number, number];

type Track = {
  bpm: number;
  lead: Note[];
  bass: Note[];
  /** Noise hat on every beat when true. */
  hats?: boolean;
};

export type TrackName = "title" | "world" | "battle";

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
    hats: true,
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
  },
};

let current: TrackName | null = null;
let timer: ReturnType<typeof setInterval> | null = null;
let channelBeats: { notes: Note[]; index: number; nextTime: number; kind: "lead" | "bass" }[] = [];
let hatTime = 0;
let hatsOn = false;
let bpm = 120;

const LOOKAHEAD_S = 0.3;
const TICK_MS = 100;

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
          type: channel.kind === "lead" ? "square" : "triangle",
          volume: channel.kind === "lead" ? 0.035 : 0.05,
          at: channel.nextTime,
        });
      }
      channel.nextTime += duration;
      channel.index = (channel.index + 1) % channel.notes.length;
    }
  }
  if (hatsOn) {
    while (hatTime < horizon) {
      playNoise({ duration: 0.03, volume: 0.012, at: hatTime });
      hatTime += beat;
    }
  }
}

export function playTrack(name: TrackName): void {
  if (current === name) return;
  stopMusic();
  const track = TRACKS[name];
  current = name;
  bpm = track.bpm;
  const start = now() + 0.1;
  channelBeats = [
    { notes: track.lead, index: 0, nextTime: start, kind: "lead" },
    { notes: track.bass, index: 0, nextTime: start, kind: "bass" },
  ];
  hatsOn = track.hats ?? false;
  hatTime = start;
  timer = setInterval(schedule, TICK_MS);
  schedule();
}

export function stopMusic(): void {
  if (timer) clearInterval(timer);
  timer = null;
  current = null;
  channelBeats = [];
}

export function currentTrack(): TrackName | null {
  return current;
}
