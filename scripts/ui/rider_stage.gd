class_name RiderStage
extends Node3D
## A horse and rider in the real toon look, dressed from wardrobe names. Used by the title, rider select and portraits.

const HORSE_PATH := "res://assets/models/horse.glb"
const RIDER_PATH := "res://assets/models/rider.glb"

var horse_root: Node3D
var rider_root: Node3D
var horse_ap: AnimationPlayer
var rider_ap: AnimationPlayer


static func _first(n: Node, cls: String) -> Node:
	var found := n.find_children("*", cls, true, false)
	return found[0] if found.size() > 0 else null


## wardrobe: mesh names to show. horse: {coat, mane, rug} colours. Without a horse the rider stands on its own.
func build(wardrobe: Array, slot_a: Color, slot_b: Color, horse: Dictionary = {}, with_horse: bool = true) -> void:
	var rmat := ArtKit.toon(ArtKit.CLASS_RIDER, 0.25)
	var parent: Node3D = self
	if with_horse and ResourceLoader.exists(HORSE_PATH):
		horse_root = (load(HORSE_PATH) as PackedScene).instantiate()
		add_child(horse_root)
		ArtKit.apply(horse_root, rmat)
		horse_ap = _first(horse_root, "AnimationPlayer") as AnimationPlayer
		var skel := _first(horse_root, "Skeleton3D") as Skeleton3D
		for mi: MeshInstance3D in horse_root.find_children("*", "MeshInstance3D", true, false):
			mi.set_instance_shader_parameter("slot_a", slot_a)
			mi.set_instance_shader_parameter("slot_b", horse.get("rug", Color("c8a02a")))
			mi.set_instance_shader_parameter("slot_c", horse.get("coat", Color("a88455")))
			mi.set_instance_shader_parameter("slot_d", horse.get("mane", Color("2b2420")))
		if horse_ap != null:
			for a in horse_ap.get_animation_list():
				horse_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if skel != null:
			var att := BoneAttachment3D.new()
			att.bone_name = "saddle"
			skel.add_child(att)
			parent = att
	if ResourceLoader.exists(RIDER_PATH):
		rider_root = (load(RIDER_PATH) as PackedScene).instantiate()
		parent.add_child(rider_root)
		if parent != self:
			rider_root.position = Vector3(0.0, -0.9, 0.0)
		ArtKit.apply(rider_root, rmat)
		rider_ap = _first(rider_root, "AnimationPlayer") as AnimationPlayer
		var names: Dictionary = {}
		for mi: MeshInstance3D in rider_root.find_children("*", "MeshInstance3D", true, false):
			mi.set_instance_shader_parameter("slot_a", slot_a)
			mi.set_instance_shader_parameter("slot_b", slot_b)
			names[String(mi.name)] = mi
		var want: Array = wardrobe.duplicate()
		var has_body := false
		var has_head := false
		for w: String in want:
			has_body = has_body or (w.begins_with("body_") and names.has(w))
			has_head = has_head or (w.begins_with("head_") and names.has(w))
		if not has_body and names.has("body_chuba"):
			want.append("body_chuba")
		if not has_head and names.has("head_young"):
			want.append("head_young")
		for key: String in names:
			(names[key] as MeshInstance3D).visible = want.has(key)
		if rider_ap != null:
			for a in rider_ap.get_animation_list():
				rider_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR


func play(horse_anim: String, rider_anim: String, speed: float = 1.0) -> void:
	if horse_ap != null and horse_ap.has_animation(horse_anim):
		horse_ap.speed_scale = speed
		horse_ap.play(horse_anim)
	if rider_ap != null and rider_ap.has_animation(rider_anim):
		rider_ap.speed_scale = speed
		rider_ap.play(rider_anim)


## Freeze both animations at a moment (for portraits).
func pose(horse_anim: String, rider_anim: String, t: float = 0.0) -> void:
	play(horse_anim, rider_anim)
	if horse_ap != null:
		horse_ap.pause()
		horse_ap.seek(t, true)
	if rider_ap != null:
		rider_ap.pause()
		rider_ap.seek(t, true)


## Dress a rider from a GameData PLAYERS / RIVALS entry. `horses` is GameData.HORSES (passed in so this file never
## needs the Game autoload, which lets tools run it).
static func dress_from_data(stage: RiderStage, entry: Dictionary, with_horse: bool = true, horses: Dictionary = {}) -> void:
	var horse_def: Dictionary = {}
	var hid := str(entry.get("horse", "old_tsampa"))
	if horses.has(hid):
		horse_def = horses[hid]
	stage.build(entry.get("wardrobe", ["body_chuba", "head_young", "hair_wound"]), entry.get("slot_a", Color("7a1c22")), entry.get("slot_b", Color("f2b632")), horse_def, with_horse)
