package game

import "core:fmt"
import "core:os"
import "core:path/filepath"
import rl "vendor:raylib"
import sim "../sim"

Person_Sprite :: enum u8 {
	Man,
	Woman,
	Elder_Man,
	Elder_Woman,
	Child,
}

Assets :: struct {
	terrain:     [sim.Terrain]rl.Texture2D,
	terrain_ok:  [sim.Terrain]bool,
	huts:        [3]rl.Texture2D,
	hut_ok:      [3]bool,
	person:      [Person_Sprite]rl.Texture2D,
	person_ok:   [Person_Sprite]bool,
	good_icon:   [sim.GOOD_COUNT]rl.Texture2D,
	good_ok:     [sim.GOOD_COUNT]bool,
	res_icon:    [4]rl.Texture2D,
	res_ok:      [4]bool,
	activity:    [sim.PRODUCTIVE_ACTIVITY_COUNT]rl.Texture2D,
	activity_ok: [sim.PRODUCTIVE_ACTIVITY_COUNT]bool,
	warned:      bool,
}

try_load :: proc(path: string) -> (rl.Texture2D, bool) {
	if !os.exists(path) {
		return {}, false
	}
	tex := rl.LoadTexture(text_c(path))
	if tex.id == 0 || tex.width <= 0 {
		return {}, false
	}
	rl.SetTextureFilter(tex, .BILINEAR)
	return tex, true
}

resolve_asset :: proc(rel: string) -> string {
	if os.exists(rel) {
		return rel
	}
	if len(os.args) > 0 {
		dir := filepath.dir(os.args[0])
		p, _ := filepath.join({dir, rel})
		if os.exists(p) {
			return p
		}
		p2, _ := filepath.join({dir, "..", rel})
		if os.exists(p2) {
			return p2
		}
	}
	return rel
}

load_assets :: proc(a: ^Assets) {
	load :: proc(a: ^Assets, rel: string) -> (rl.Texture2D, bool) {
		p := resolve_asset(rel)
		tex, ok := try_load(p)
		if !ok {
			fmt.printf("asset missing or unloadable: %s\n", rel)
			a.warned = true
		}
		return tex, ok
	}
	a.terrain[.Meadow], a.terrain_ok[.Meadow] = load(a, "assets/terrain/meadow.png")
	a.terrain[.Forest], a.terrain_ok[.Forest] = load(a, "assets/terrain/forest_floor.png")
	a.terrain[.Rocky], a.terrain_ok[.Rocky] = load(a, "assets/terrain/rocky.png")

	a.huts[0], a.hut_ok[0] = load(a, "assets/structures/hut_01.png")
	a.huts[1], a.hut_ok[1] = load(a, "assets/structures/hut_02.png")
	a.huts[2], a.hut_ok[2] = load(a, "assets/structures/hut_03.png")

	a.good_icon[sim.Good.Berries], a.good_ok[sim.Good.Berries] = load(a, "assets/icons/good_berries.png")
	a.good_icon[sim.Good.Meat], a.good_ok[sim.Good.Meat] = load(a, "assets/icons/good_meat.png")
	a.good_icon[sim.Good.Wood], a.good_ok[sim.Good.Wood] = load(a, "assets/icons/good_wood.png")
	a.good_icon[sim.Good.Stone], a.good_ok[sim.Good.Stone] = load(a, "assets/icons/good_stone.png")
	a.good_icon[sim.Good.Spear], a.good_ok[sim.Good.Spear] = load(a, "assets/icons/good_spear.png")

	a.res_icon[0], a.res_ok[0] = load(a, "assets/resources/berries.png")
	a.res_icon[1], a.res_ok[1] = load(a, "assets/resources/game.png")
	a.res_icon[2], a.res_ok[2] = load(a, "assets/resources/wood.png")
	a.res_icon[3], a.res_ok[3] = load(a, "assets/resources/stone.png")

	a.activity[0], a.activity_ok[0] = load(a, "assets/icons/activity_forage.png")
	a.activity[1], a.activity_ok[1] = load(a, "assets/icons/activity_hunt.png")
	a.activity[2], a.activity_ok[2] = load(a, "assets/icons/activity_wood.png")
	a.activity[3], a.activity_ok[3] = load(a, "assets/icons/activity_stone.png")
	a.activity[4], a.activity_ok[4] = load(a, "assets/icons/activity_craft.png")

	a.person[.Man], a.person_ok[.Man] = load(a, "assets/people/man.png")
	a.person[.Woman], a.person_ok[.Woman] = load(a, "assets/people/woman.png")
	a.person[.Elder_Man], a.person_ok[.Elder_Man] = load(a, "assets/people/elder_man.png")
	a.person[.Elder_Woman], a.person_ok[.Elder_Woman] = load(a, "assets/people/elder_woman.png")
	a.person[.Child], a.person_ok[.Child] = load(a, "assets/people/child.png")
}

unload_assets :: proc(a: ^Assets) {
	unload :: proc(ok: bool, t: rl.Texture2D) {
		if ok do rl.UnloadTexture(t)
	}
	for t in sim.Terrain {
		unload(a.terrain_ok[t], a.terrain[t])
	}
	for i in 0 ..< 3 {
		unload(a.hut_ok[i], a.huts[i])
	}
	for g in sim.Good {
		unload(a.good_ok[g], a.good_icon[g])
	}
	for i in 0 ..< 4 {
		unload(a.res_ok[i], a.res_icon[i])
	}
	for i in 0 ..< sim.PRODUCTIVE_ACTIVITY_COUNT {
		unload(a.activity_ok[i], a.activity[i])
	}
	for s in Person_Sprite {
		unload(a.person_ok[s], a.person[s])
	}
}

draw_tex :: proc(tex: rl.Texture2D, dest: rl.Rectangle, tint: rl.Color) {
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	rl.DrawTexturePro(tex, src, dest, {0, 0}, 0, tint)
}

draw_good_icon :: proc(a: ^Assets, g: sim.Good, dest: rl.Rectangle) {
	if a.good_ok[g] {
		draw_tex(a.good_icon[g], dest, rl.WHITE)
		return
	}
	col := COL_ACCENT
	switch g {
	case .Berries: col = {140, 60, 90, 255}
	case .Meat:    col = {160, 80, 70, 255}
	case .Wood:    col = {120, 90, 50, 255}
	case .Stone:   col = {130, 125, 120, 255}
	case .Spear:   col = {170, 150, 90, 255}
	}
	rl.DrawRectangleRec(dest, col)
	letter := "B"
	switch g {
	case .Berries: letter = "B"
	case .Meat:    letter = "M"
	case .Wood:    letter = "W"
	case .Stone:   letter = "S"
	case .Spear:   letter = "P"
	}
	draw_text(letter, i32(dest.x) + 4, i32(dest.y) + 2, 12, COL_TEXT)
}
