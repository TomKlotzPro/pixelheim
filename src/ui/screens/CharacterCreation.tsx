import { useState } from "react";
import { ROLES } from "../../game/hero/roles";
import type { RoleId } from "../../game/types";
import { Sprite } from "../widgets/Sprite";

/** One-line pitch per role, for the class list. */
const ROLE_PITCH: Record<RoleId, string> = {
  warrior: "Steel and stubbornness",
  mage: "Glass cannon, loud spells",
  rogue: "Fast, sharp, gone",
  cleric: "Holds the line, heals it too",
};

const STAT_ROWS = [
  { key: "maxHp", label: "HP" },
  { key: "maxMp", label: "MP" },
  { key: "strength", label: "STR" },
  { key: "intelligence", label: "INT" },
  { key: "dexterity", label: "DEX" },
  { key: "defense", label: "DEF" },
] as const;

// Bars are comparable across classes: each stat is scaled to the roster max.
const STAT_MAX = Object.fromEntries(
  STAT_ROWS.map((row) => [row.key, Math.max(...Object.values(ROLES).map((r) => r.baseStats[row.key]))]),
) as Record<(typeof STAT_ROWS)[number]["key"], number>;

/** Palette-swap looks per role: 0 is the classic, 1-3 swap skin and outfit. */
const LOOKS = [0, 1, 2, 3];

function lookSprite(base: string, look: number): string {
  return look ? `${base}_l${look}` : base;
}

type CharacterCreationProps = {
  onCreate: (name: string, roleId: RoleId, look: number) => void;
};

export function CharacterCreation({ onCreate }: CharacterCreationProps) {
  const [name, setName] = useState("");
  const [roleId, setRoleId] = useState<RoleId>("warrior");
  const [look, setLook] = useState(0);
  const role = ROLES[roleId];
  const base = import.meta.env.BASE_URL;

  return (
    <div className="screen create-screen">
      <p className="create-eyebrow">The mountain is waiting</p>
      <h2 className="screen-title">Create your hero</h2>

      <div className="create-layout">
        <div className="role-list" role="radiogroup" aria-label="Class">
          {Object.values(ROLES).map((r) => (
            <button
              key={r.id}
              className={`role-card ${r.id === roleId ? "selected" : ""}`}
              onClick={() => setRoleId(r.id)}
            >
              <Sprite name={r.sprite} size={40} alt="" />
              <span className="role-card-text">
                <span className="role-name">{r.name}</span>
                <span className="role-pitch">{ROLE_PITCH[r.id]}</span>
              </span>
            </button>
          ))}
        </div>

        <div className="panel role-details">
          <div className="role-portrait">
            <span
              className="role-portrait-art"
              style={{
                backgroundImage: `url(${base}sprites/${lookSprite(role.sprite, look)}_walk.png)`,
                backgroundSize: "384px 96px",
              }}
            />
            <div className="look-row" role="radiogroup" aria-label="Look">
              {LOOKS.map((i) => (
                <button
                  key={i}
                  className={`look-swatch ${i === look ? "selected" : ""}`}
                  aria-label={`Look ${i + 1}`}
                  onClick={() => setLook(i)}
                >
                  <Sprite name={lookSprite(role.sprite, i)} size={28} alt="" />
                </button>
              ))}
            </div>
            <span className="role-portrait-name">{name.trim() || "..."}</span>
            <span className="role-portrait-class">{role.name}</span>
          </div>
          <div className="role-sheet">
            <p className="role-blurb">{role.description}</p>
            <div className="role-bars">
              {STAT_ROWS.map((row) => (
                <div key={row.key} className="role-bar-row">
                  <span className="role-bar-label">{row.label}</span>
                  <span className="role-bar-track">
                    <span
                      className="role-bar-fill"
                      style={{ width: `${Math.round((role.baseStats[row.key] / STAT_MAX[row.key]) * 100)}%` }}
                    />
                  </span>
                  <span className="role-bar-value">{role.baseStats[row.key]}</span>
                </div>
              ))}
            </div>
            <p className="skill-line">
              Skills:{" "}
              {role.skills.map((skill, i) => (
                <span key={skill.name}>
                  {i > 0 && ", "}
                  <strong>{skill.name}</strong> (Lv{skill.unlockLevel})
                </span>
              ))}
            </p>
            <p className="skill-line">{role.skills[0].description}</p>
          </div>
        </div>
      </div>

      <div className="create-footer">
        <label className="name-field">
          <span>Name</span>
          <input
            value={name}
            maxLength={16}
            placeholder="Dragonsbane..."
            onChange={(e) => setName(e.target.value)}
            autoFocus
          />
        </label>
        <button
          className="btn btn-primary"
          disabled={name.trim().length === 0}
          onClick={() => onCreate(name.trim(), roleId, look)}
        >
          Begin the climb
        </button>
      </div>
    </div>
  );
}
