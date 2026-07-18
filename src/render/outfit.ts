/**
 * Runtime outfit composition: stamps the worn overlay sprites onto the hero's
 * walk sheet (or a single frame) on a canvas, cached per equipment set. This
 * is how gear becomes CLOTHING - drawn into the sprite, not stuck on top -
 * without pre-generating every hero x look x rank x gear combination.
 */
const ART = 16;
/** The generator's walk cycle bobs frames 1 and 3 up a pixel; overlays follow. */
const WALK_FRAME_DY = [0, -1, 0, -1];

const imageCache = new Map<string, Promise<HTMLImageElement>>();

function loadImage(src: string): Promise<HTMLImageElement> {
  let cached = imageCache.get(src);
  if (!cached) {
    cached = new Promise((resolve, reject) => {
      const img = new Image();
      img.addEventListener("load", () => resolve(img), { once: true });
      img.addEventListener("error", () => reject(new Error(`could not load ${src}`)), { once: true });
      img.src = src;
    });
    imageCache.set(src, cached);
  }
  return cached;
}

function spriteUrl(name: string): string {
  return `${import.meta.env.BASE_URL}sprites/${name}.png`;
}

/** Stable cache key for a base sprite dressed in an outfit. */
export function outfitKey(base: string, outfit: string[]): string {
  return `${base}|${outfit.join("+")}`;
}

const sheetCache = new Map<string, Promise<HTMLCanvasElement>>();

/**
 * The hero's walk sheet with the outfit painted onto every frame.
 * Returns a canvas (4 frames x 16px); callers texture/slice it themselves.
 */
export function composeWalkSheet(heroName: string, outfit: string[]): Promise<HTMLCanvasElement> {
  const key = outfitKey(`${heroName}_walk`, outfit);
  let cached = sheetCache.get(key);
  if (!cached) {
    cached = (async () => {
      const [base, ...wears] = await Promise.all([
        loadImage(spriteUrl(`${heroName}_walk`)),
        ...outfit.map((wear) => loadImage(spriteUrl(wear))),
      ]);
      const frames = Math.max(1, Math.round(base.width / ART));
      const canvas = document.createElement("canvas");
      canvas.width = base.width;
      canvas.height = base.height;
      const ctx = canvas.getContext("2d")!;
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(base, 0, 0);
      for (let frame = 0; frame < frames; frame++) {
        const dy = WALK_FRAME_DY[frame % WALK_FRAME_DY.length];
        for (const wear of wears) ctx.drawImage(wear, frame * ART, dy);
      }
      return canvas;
    })();
    sheetCache.set(key, cached);
  }
  return cached;
}

const portraitCache = new Map<string, Promise<string>>();

/** A single dressed frame as a data URL, for the DOM hero and the doll. */
export function composePortrait(heroName: string, outfit: string[]): Promise<string> {
  const key = outfitKey(heroName, outfit);
  let cached = portraitCache.get(key);
  if (!cached) {
    cached = (async () => {
      const [base, ...wears] = await Promise.all([
        loadImage(spriteUrl(heroName)),
        ...outfit.map((wear) => loadImage(spriteUrl(wear))),
      ]);
      const canvas = document.createElement("canvas");
      canvas.width = ART;
      canvas.height = ART;
      const ctx = canvas.getContext("2d")!;
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(base, 0, 0);
      for (const wear of wears) ctx.drawImage(wear, 0, 0);
      return canvas.toDataURL();
    })();
    portraitCache.set(key, cached);
  }
  return cached;
}
