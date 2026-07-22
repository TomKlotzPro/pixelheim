import type { ReactNode } from "react";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

/**
 * The one modal scaffold every panel used to hand-roll (PIX-116): the
 * click-to-close overlay, the stop-propagation panel, the header with an
 * optional portrait, gold line and extras, and the capture-phase Esc close.
 * Thirteen panels repeated this by hand; drift lived in the differences.
 */
export function PanelShell({
  onClose,
  className,
  testId,
  title,
  sprite,
  spriteAlt,
  gold,
  headerExtra,
  children,
}: {
  onClose: () => void;
  className?: string;
  testId?: string;
  title: string;
  sprite?: string;
  spriteAlt?: string;
  gold?: number;
  headerExtra?: ReactNode;
  children: ReactNode;
}) {
  useEscapeClose(onClose);
  return (
    <div className="overlay" onClick={onClose}>
      <div className={`panel ${className ?? ""}`} onClick={(e) => e.stopPropagation()} data-testid={testId}>
        <div className="inventory-header">
          {sprite && <Sprite name={sprite} size={40} alt={spriteAlt ?? ""} />}
          <h2>{title}</h2>
          {gold !== undefined && (
            <span className="gold-line">
              <Sprite name="gold" size={16} /> {gold}
            </span>
          )}
          {headerExtra}
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
