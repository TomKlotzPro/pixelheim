import { gearByUid } from "../hero/character";
import { gearItem } from "./rarity";
import type { Equipped, GearInstance } from "../types";

/**
 * What each equippable LOOKS like on the body: item id -> the worn overlay
 * sprite drawn for the hero's anatomy. Families share silhouettes; tiers
 * change the palette. Anything unlisted simply doesn't render (jewelry).
 */
export const WEAR_OF: Record<string, string> = {
  // weapons - the blade in the hand
  rusty_sword: "wear_sword_rusty",
  iron_sword: "wear_sword",
  obsidian_blade: "wear_sword_dark",
  dragonbane: "wear_dragonbane",
  beast_cleaver: "wear_axe",
  steel_axe: "wear_axe",
  war_hammer: "wear_hammer",
  hunting_bow: "wear_bow",
  longbow: "wear_bow",
  deeproot_bow: "wear_bow",
  shadow_dagger: "wear_dagger",
  wyrmfang_dagger: "wear_dagger",
  apprentice_staff: "wear_staff",
  arch_staff: "wear_staff",
  moon_wand: "wear_staff",
  emberwood_staff: "wear_staff",
  // body - plates and drapes over the torso
  leather_armor: "wear_plate_leather",
  traveler_cloak: "wear_robe_cloak",
  iron_armor: "wear_plate",
  runic_armor: "wear_plate_runic",
  scaled_mail: "wear_plate_scaled",
  mage_robe: "wear_robe",
  shadow_cloak: "wear_robe_shadow",
  // head - domes over the hair, faces stay open
  leather_cap: "wear_helm_leather",
  iron_helm: "wear_helm",
  wyrm_visor: "wear_helm_crest",
  // off-hand - shields on the left arm
  reed_buckler: "wear_shield_small",
  steel_shield: "wear_shield_small",
  tower_shield: "wear_shield_tower",
  grave_ward: "wear_shield_ward",
};

/** Paint order matters: body first, then shield, helm, weapon on top. */
const OUTFIT_ORDER = ["body", "offhand", "head", "weapon"] as const;

/** The worn overlay sprites for this equipment set, in paint order. */
export function outfitFor(gear: GearInstance[], equipped: Equipped): string[] {
  return OUTFIT_ORDER.flatMap((slot) => {
    const instance = gearByUid(gear, equipped[slot]);
    const wear = instance ? WEAR_OF[gearItem(instance).id] : undefined;
    return wear ? [wear] : [];
  });
}
