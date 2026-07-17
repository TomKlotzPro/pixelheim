type StatBarProps = {
  label: string;
  value: number;
  max: number;
  color: string;
};

export function StatBar({ label, value, max, color }: StatBarProps) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0;
  return (
    <div className="statbar">
      <span className="statbar-label">{label}</span>
      <div className="statbar-track">
        <div className="statbar-fill" style={{ width: `${pct}%`, background: color }} />
      </div>
      <span className="statbar-value">
        {value}/{max}
      </span>
    </div>
  );
}
