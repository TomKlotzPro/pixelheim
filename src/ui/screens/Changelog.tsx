import { CHANGELOG } from "../../app/changelog";

type ChangelogPageProps = {
  onBack: () => void;
};

/** The full release history as its own page, newest first. */
export function ChangelogPage({ onBack }: ChangelogPageProps) {
  return (
    <div className="screen changelog-page">
      <div className="changelog-page-header">
        <button className="btn btn-small" onClick={onBack}>
          &lt; Back
        </button>
        <h1>Changelog</h1>
      </div>
      <div className="changelog-scroll">
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
  );
}
