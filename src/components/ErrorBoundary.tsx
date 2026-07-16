import { Component, type ErrorInfo, type ReactNode } from "react";

type Props = { children: ReactNode };
type State = { crashed: boolean };

/**
 * The last line of defense: a component throw must never blank the game
 * (PIX-58 taught us that lesson). Progress persists on every action, so a
 * reload always recovers cleanly.
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { crashed: false };

  static getDerivedStateFromError(): State {
    return { crashed: true };
  }

  componentDidCatch(error: unknown, info: ErrorInfo): void {
    console.error("Pixelheim glitched:", error, info.componentStack);
  }

  render(): ReactNode {
    if (!this.state.crashed) return this.props.children;
    return (
      <div className="screen crash-screen">
        <h1 className="game-title">GLITCH!</h1>
        <p className="tagline">
          The cartridge hiccuped. Your progress is saved automatically, so blow on it and try again.
        </p>
        <button className="btn btn-primary" onClick={() => window.location.reload()}>
          Reload
        </button>
      </div>
    );
  }
}
