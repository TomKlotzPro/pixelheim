import { CHANGELOG } from "../changelog";

type ChangelogProps = {
  onClose: () => void;
};

export function Changelog({ onClose }: ChangelogProps) {
  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel inventory-panel" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <h2>Changelog</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <div className="item-list changelog-list">
          {CHANGELOG.map((release) => (
            <section key={release.version} className="release">
              <h3 className="release-title">
                v{release.version} - {release.codename}
                <span className="release-date">{release.date}</span>
              </h3>
              <ul className="release-notes">
                {release.notes.map((note) => (
                  <li key={note}>{note}</li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      </div>
    </div>
  );
}
