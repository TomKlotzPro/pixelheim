type SpriteProps = {
  name: string;
  size?: number;
  alt?: string;
  className?: string;
};

export function Sprite({ name, size = 64, alt = "", className }: SpriteProps) {
  return (
    <img
      src={`${import.meta.env.BASE_URL}sprites/${name}.png`}
      width={size}
      height={size}
      alt={alt}
      className={className}
      style={{ imageRendering: "pixelated" }}
      draggable={false}
    />
  );
}
