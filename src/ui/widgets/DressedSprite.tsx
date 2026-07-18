import { useEffect, useState } from "react";
import { composePortrait, outfitKey } from "../../render/outfit";
import { Sprite } from "./Sprite";

type DressedSpriteProps = {
  name: string;
  outfit: string[];
  size?: number;
  alt?: string;
  className?: string;
};

/** The hero wearing their gear: a Sprite whose pixels include the outfit. */
export function DressedSprite({ name, outfit, size = 64, alt = "", className }: DressedSpriteProps) {
  const key = outfitKey(name, outfit);
  const [dressed, setDressed] = useState<{ key: string; url: string } | null>(null);

  useEffect(() => {
    if (outfit.length === 0) return;
    let live = true;
    composePortrait(name, outfit)
      .then((url) => {
        if (live) setDressed({ key, url });
        return null;
      })
      .catch(() => null);
    return () => {
      live = false;
    };
  }, [name, key, outfit]);

  if (outfit.length === 0 || dressed?.key !== key) {
    return <Sprite name={name} size={size} alt={alt} className={className} />;
  }
  return (
    <img
      src={dressed.url}
      width={size}
      height={size}
      alt={alt}
      className={className}
      style={{ imageRendering: "pixelated" }}
      draggable={false}
    />
  );
}
