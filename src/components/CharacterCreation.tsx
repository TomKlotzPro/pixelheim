import { useState } from "react";
import { ROLES } from "../game/roles";
import type { RoleId } from "../game/types";
import { Sprite } from "./Sprite";

type CharacterCreationProps = {
  onCreate: (name: string, roleId: RoleId) => void;
};

export function CharacterCreation({ onCreate }: CharacterCreationProps) {
  const [name, setName] = useState("");
  const [roleId, setRoleId] = useState<RoleId>("warrior");
  const role = ROLES[roleId];

  return (
    <div className="screen create-screen">
      <h2 className="screen-title">Create your hero</h2>
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
      <div className="role-grid">
        {Object.values(ROLES).map((r) => (
          <button
            key={r.id}
            className={`role-card ${r.id === roleId ? "selected" : ""}`}
            onClick={() => setRoleId(r.id)}
          >
            <Sprite name={r.sprite} size={64} alt={r.name} />
            <span className="role-name">{r.name}</span>
          </button>
        ))}
      </div>
      <div className="panel role-details">
        <p>{role.description}</p>
        <div className="role-stats">
          <span>HP {role.baseStats.maxHp}</span>
          <span>MP {role.baseStats.maxMp}</span>
          <span>STR {role.baseStats.strength}</span>
          <span>INT {role.baseStats.intelligence}</span>
          <span>DEX {role.baseStats.dexterity}</span>
          <span>DEF {role.baseStats.defense}</span>
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
      <button
        className="btn btn-primary"
        disabled={name.trim().length === 0}
        onClick={() => onCreate(name.trim(), roleId)}
      >
        Begin the climb
      </button>
    </div>
  );
}
