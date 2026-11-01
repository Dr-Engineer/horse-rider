class_name FallbackData
extends RefCounted
## Stand-in numbers from docs/GAME_DESIGN.md, used only where data/game_data.gd has no entry yet.
## Display text is plain capitals in the headline font's alphabet (no semicolons, ampersands or curly quotes).

const WEAPONS := {
	"fists": {"name": "FISTS", "klass": "body", "damage": 5, "impact": 10, "reach": 1.9, "swing": 0.33, "cost": 0, "ammo": 0, "desc": "ALWAYS WITH YOU."},
	"kick": {"name": "KICK", "klass": "body", "damage": 6, "impact": 20, "reach": 2.1, "swing": 0.5, "cost": 0, "ammo": 0, "desc": "SHOVES THE TARGET SIDEWAYS."},
	"knife": {"name": "KNIFE", "klass": "melee", "damage": 10, "impact": 8, "reach": 2.0, "swing": 0.3, "cost": 80, "ammo": 0, "desc": "THE FASTEST BLADE."},
	"pencase": {"name": "PEN CASE", "klass": "melee", "damage": 7, "impact": 20, "reach": 2.1, "swing": 0.42, "cost": 40, "ammo": 0, "desc": "GRAVEL-FILLED. CHEAP AND COMIC."},
	"whip": {"name": "WHIP", "klass": "melee", "damage": 6, "impact": 15, "reach": 3.0, "swing": 0.34, "cost": 120, "ammo": 0, "desc": "LONG AND QUICK."},
	"sword": {"name": "SWORD", "klass": "melee", "damage": 18, "impact": 24, "reach": 2.6, "swing": 0.55, "cost": 450, "ammo": 0, "desc": "THE BEST ALL-ROUNDER."},
	"key": {"name": "IRON KEY", "klass": "melee", "damage": 15, "impact": 38, "reach": 3.5, "swing": 0.7, "cost": 700, "ammo": 0, "desc": "OUTREACHES SWORDS. WEAK UP CLOSE."},
	"spear": {"name": "SPEAR", "klass": "melee", "damage": 16, "impact": 34, "reach": 4.0, "swing": 0.75, "cost": 600, "ammo": 0, "desc": "AT A FULL GALLOP, +25% IMPACT."},
	"sling": {"name": "SLING", "klass": "ranged", "damage": 3, "impact": 6, "reach": 28.0, "swing": 0.8, "cost": 60, "ammo": 99, "desc": "PLENTIFUL STONES. HARASSES ONLY."},
	"bow": {"name": "BOW", "klass": "ranged", "damage": 7, "impact": 8, "reach": 45.0, "swing": 1.0, "cost": 500, "ammo": 12, "desc": "DRAW TO AIM. +30% AT FULL DRAW."},
	"roped_spear": {"name": "ROPED SPEAR", "klass": "ranged", "damage": 9, "impact": 12, "reach": 18.0, "swing": 1.1, "cost": 900, "ammo": 0, "desc": "THROWN, THEN HAULED BACK. NO AMMO."},
}

const HORSES := {
	"old_tsampa": {"name": "OLD TSAMPA", "cost": 0, "speed": 20.0, "accel": 6.5, "handling": 3.0, "stamina": 80.0, "bulk": 1.0, "desc": "HONEST AND STEADY."},
	"riwoche_dun": {"name": "RIWOCHE DUN", "cost": 320, "speed": 22.0, "accel": 7.5, "handling": 3.4, "stamina": 90.0, "bulk": 0.9, "desc": "LIGHT AND QUICK. EASY TO SHOVE."},
	"nangchen_bay": {"name": "NANGCHEN BAY", "cost": 700, "speed": 24.0, "accel": 7.5, "handling": 3.2, "stamina": 100.0, "bulk": 1.0, "desc": "A PROPER RACEHORSE."},
	"golok_black": {"name": "GOLOK BLACK", "cost": 900, "speed": 23.0, "accel": 6.5, "handling": 2.8, "stamina": 120.0, "bulk": 1.5, "desc": "HEAVY. HARD TO KNOCK OVER."},
	"sertso_grey": {"name": "SERTSO GREY", "cost": 2000, "speed": 27.0, "accel": 8.5, "handling": 3.4, "stamina": 120.0, "bulk": 1.1, "desc": "THE HORSE PEOPLE TELL STORIES ABOUT."},
}
const HORSE_ORDER: Array[String] = ["old_tsampa", "riwoche_dun", "nangchen_bay", "golok_black", "sertso_grey"]
const HORSE_MAX := {"speed": 28.0, "accel": 9.0, "handling": 3.6, "stamina": 130.0, "bulk": 1.6}

const SADDLES := [
	{"name": "FELT PAD", "cost": 0, "desc": "NOTHING FANCY."},
	{"name": "DERGE SADDLE", "cost": 300, "desc": "TAKES 15% LESS IMPACT."},
	{"name": "GILT SADDLE", "cost": 900, "desc": "TAKES 30% LESS IMPACT."},
]
const ARMOR := [
	{"name": "PLAIN CHUBA", "cost": 0, "desc": "THE ROBE YOU STAND IN."},
	{"name": "PADDED CHUBA", "cost": 200, "desc": "+15 MAX HEALTH."},
	{"name": "MAIL SHIRT", "cost": 700, "desc": "+30 MAX HEALTH."},
]
const SHIELD := {"name": "ROUND SHIELD", "cost": 150, "desc": "HOLD TO RAISE. CUTS DAMAGE 75% AND IMPACT 65%. BLOCKS ARROWS."}

const PRIZES := [[200, 120, 70], [420, 260, 150], [800, 500, 300]]
const BOUNTY := [15, 30, 60]
const FINE := [40, 90, 180]

const PLAYERS := {
	"joru": {"name": "JORU", "region": "KHAM", "tag": "BALANCED", "look": "HAIR WOUND WITH RED CORD. PLAIN MAROON ROBE.", "horse": "old_tsampa"},
	"yangkyi": {"name": "YANGKYI", "region": "AMDO", "tag": "QUICK AND LIGHT", "look": "TWO PLAITS. GREY-BLUE ROBE, RED SASH.", "horse": "old_tsampa"},
}
