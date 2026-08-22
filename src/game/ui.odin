package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

COL_BG :: rl.Color{22, 19, 17, 255}
COL_PANEL :: rl.Color{36, 31, 28, 235}
COL_PANEL2 :: rl.Color{48, 41, 36, 245}
COL_BORDER :: rl.Color{72, 62, 52, 255}
COL_TEXT :: rl.Color{244, 238, 226, 255}
COL_DIM :: rl.Color{198, 188, 174, 255}
COL_ACCENT :: rl.Color{228, 178, 92, 255}
COL_ACCENT_D :: rl.Color{160, 110, 48, 255}
COL_GOOD :: rl.Color{110, 150, 100, 255}
COL_WARN :: rl.Color{196, 150, 70, 255}
COL_CRIT :: rl.Color{170, 80, 65, 255}
COL_MAP_VOID :: rl.Color{18, 16, 14, 255}

MEADOW_COL :: rl.Color{138, 132, 86, 255}
FOREST_COL :: rl.Color{58, 74, 56, 255}
ROCK_COL :: rl.Color{112, 98, 84, 255}

ROLE_COL := [6]rl.Color{
	{180, 170, 155, 255},
	{150, 170, 90, 255},
	{170, 90, 70, 255},
	{120, 90, 55, 255},
	{130, 130, 140, 255},
	{200, 150, 70, 255},
}

ui_consumed: bool
ui_tooltip: string

g_font: rl.Font
g_font_bold: rl.Font
g_font_ok: bool
g_font_bold_ok: bool
FONT_ATLAS :: i32(40)

text_c :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// Old 12–14px default-font sizes were unreadable. Floor and lift them.
ui_px :: proc(size: i32) -> f32 {
	switch {
	case size <= 12:
		return 16
	case size <= 13:
		return 17
	case size <= 14:
		return 18
	case size <= 16:
		return 19
	case size <= 18:
		return 21
	case size <= 22:
		return 24
	case size <= 28:
		return 32
	}
	return f32(size)
}

ui_spacing :: proc(px: f32) -> f32 {
	s := px * 0.035
	if s < 0.25 do s = 0.25
	if s > 1.1 do s = 1.1
	return s
}

load_ui_font :: proc() {
	cps: [400]rune
	n := 0
	for r := rune(32); r <= 126; r += 1 {
		cps[n] = r
		n += 1
	}
	for r := rune(160); r <= 255; r += 1 {
		cps[n] = r
		n += 1
	}
	extra := [?]rune {
		'–', '—', '‘', '’', '“', '”', '•', '…', '→', '←', '≈', '►', '▲', '▼', '×', '·', '‰',
	}
	for r in extra {
		cps[n] = r
		n += 1
	}

	regular := [?]cstring {
		"C:/Windows/Fonts/segoeui.ttf",
		"C:/Windows/Fonts/calibri.ttf",
		"C:/Windows/Fonts/arial.ttf",
		"C:/Windows/Fonts/tahoma.ttf",
		"C:/Windows/Fonts/verdana.ttf",
		"C:/Windows/Fonts/CascadiaCode.ttf",
	}
	bold := [?]cstring {
		"C:/Windows/Fonts/segoeuib.ttf",
		"C:/Windows/Fonts/calibrib.ttf",
		"C:/Windows/Fonts/arialbd.ttf",
		"C:/Windows/Fonts/tahomabd.ttf",
		"C:/Windows/Fonts/verdanab.ttf",
		"C:/Windows/Fonts/CascadiaCode.ttf",
	}

	try_load :: proc(path: cstring, cps: []rune, n: int) -> (rl.Font, bool) {
		f := rl.LoadFontEx(path, FONT_ATLAS, raw_data(cps), i32(n))
		if rl.IsFontValid(f) && f.texture.id != 0 {
			rl.SetTextureFilter(f.texture, .BILINEAR)
			return f, true
		}
		if f.glyphCount > 0 || f.texture.id != 0 {
			rl.UnloadFont(f)
		}
		return {}, false
	}

	for path in regular {
		if f, ok := try_load(path, cps[:], n); ok {
			g_font = f
			g_font_ok = true
			break
		}
	}
	for path in bold {
		if f, ok := try_load(path, cps[:], n); ok {
			g_font_bold = f
			g_font_bold_ok = true
			break
		}
	}
	if !g_font_ok {
		g_font = rl.GetFontDefault()
	}
}

unload_ui_font :: proc() {
	if g_font_ok {
		rl.UnloadFont(g_font)
		g_font_ok = false
	}
	if g_font_bold_ok {
		rl.UnloadFont(g_font_bold)
		g_font_bold_ok = false
	}
}

font_for :: proc(size: i32) -> rl.Font {
	if size >= 20 && g_font_bold_ok {
		return g_font_bold
	}
	if g_font_ok || g_font.texture.id != 0 {
		return g_font
	}
	return rl.GetFontDefault()
}

draw_text :: proc(s: string, x, y, size: i32, col: rl.Color) {
	px := ui_px(size)
	font := font_for(size)
	rl.DrawTextEx(font, text_c(s), {f32(x), f32(y)}, px, ui_spacing(px), col)
}

measure :: proc(s: string, size: i32) -> i32 {
	px := ui_px(size)
	font := font_for(size)
	v := rl.MeasureTextEx(font, text_c(s), px, ui_spacing(px))
	return i32(v.x + 0.5)
}

measure_h :: proc(size: i32) -> f32 {
	return ui_px(size) + 1
}

draw_panel :: proc(r: rl.Rectangle, title: string = "") {
	rl.DrawRectangleRounded(r, 0.04, 6, COL_PANEL)
	rl.DrawRectangleRoundedLines(r, 0.04, 6, COL_BORDER)
	if title != "" {
		draw_text(title, i32(r.x) + 10, i32(r.y) + 8, 16, COL_ACCENT)
	}
}

in_rec :: proc(r: rl.Rectangle) -> bool {
	return rl.CheckCollisionPointRec(rl.GetMousePosition(), r)
}

button :: proc(r: rl.Rectangle, label: string, active := false, tip: string = "") -> bool {
	hot := in_rec(r)
	if hot {
		ui_consumed = true
		if tip != "" do ui_tooltip = tip
	}
	col := COL_PANEL2
	if active do col = COL_ACCENT_D
	if hot do col = rl.Color{col.r + 18, col.g + 14, col.b + 10, 255}
	rl.DrawRectangleRounded(r, 0.16, 5, col)
	rl.DrawRectangleRoundedLines(r, 0.16, 5, COL_BORDER if !active else COL_ACCENT)
	tw := measure(label, 14)
	th := measure_h(14)
	draw_text(label, i32(r.x + r.width / 2) - tw / 2, i32(r.y + (r.height - th) / 2), 14, COL_TEXT)
	return hot && rl.IsMouseButtonPressed(.LEFT)
}

checkbox :: proc(r: rl.Rectangle, label: string, on: bool, tip: string = "") -> bool {
	box := rl.Rectangle{r.x, r.y, 18, 18}
	hot := in_rec(r)
	if hot {
		ui_consumed = true
		if tip != "" do ui_tooltip = tip
	}
	rl.DrawRectangleRounded(box, 0.2, 4, COL_PANEL2)
	rl.DrawRectangleRoundedLines(box, 0.2, 4, COL_ACCENT if on else COL_BORDER)
	if on {
		rl.DrawRectangleRounded({box.x + 4, box.y + 4, 10, 10}, 0.2, 4, COL_ACCENT)
	}
	draw_text(label, i32(box.x) + 26, i32(box.y), 14, COL_TEXT)
	return hot && rl.IsMouseButtonPressed(.LEFT)
}

icon_btn :: proc(r: rl.Rectangle, label: string, active: bool, tip: string) -> bool {
	return button(r, label, active, tip)
}

bar :: proc(x, y, w, h: f32, t: f32, fill: rl.Color) {
	rl.DrawRectangleRec({x, y, w, h}, rl.Color{20, 18, 16, 255})
	tw := w * clamp_f32(t, 0, 1)
	rl.DrawRectangleRec({x, y, tw, h}, fill)
	rl.DrawRectangleLinesEx({x, y, w, h}, 1, COL_BORDER)
}

clamp_f32 :: proc(v, lo, hi: f32) -> f32 {
	if v < lo do return lo
	if v > hi do return hi
	return v
}

clamp_i32 :: proc(v, lo, hi: i32) -> i32 {
	if v < lo do return lo
	if v > hi do return hi
	return v
}

draw_tooltip :: proc() {
	if ui_tooltip == "" do return
	m := rl.GetMousePosition()
	pad: f32 = 10
	max_w: f32 = 520
	tw := f32(measure(ui_tooltip, 14))
	if tw > max_w - pad * 2 do tw = max_w - pad * 2
	w := tw + pad * 2
	h := measure_h(14) + pad * 2
	x := m.x + 16
	y := m.y + 20
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	if x + w > sw - 4 do x = sw - w - 4
	if y + h > sh - 4 do y = m.y - h - 10
	rl.DrawRectangleRounded({x, y, w, h}, 0.12, 4, rl.Color{16, 14, 12, 250})
	rl.DrawRectangleRoundedLines({x, y, w, h}, 0.12, 4, COL_ACCENT)
	draw_text(ui_tooltip, i32(x + pad), i32(y + pad - 1), 14, COL_TEXT)
}

fmt_qty :: proc(q: i64) -> string {
	if q < 0 do return "N/A"
	whole := q / 1000
	frac := (q % 1000) / 100
	if frac == 0 {
		return fmt.tprintf("%d", whole)
	}
	return fmt.tprintf("%d.%d", whole, frac)
}

fmt_days :: proc(milli: i64) -> string {
	return fmt.tprintf("%.1f d", f64(milli) / 1000.0)
}

fmt_bp :: proc(bp: i32) -> string {
	return fmt.tprintf("%d%%", bp / 100)
}

fmt_cbr :: proc(milli: i32) -> string {
	v := milli
	if v < 0 do v = 0
	whole := v / 1000
	frac := (v / 100) % 10
	if frac == 0 {
		return fmt.tprintf("%d‰", whole)
	}
	return fmt.tprintf("%d.%d‰", whole, frac)
}

fmt_tfr :: proc(milli: i32) -> string {
	v := milli
	if v < 0 do v = 0
	return fmt.tprintf("%d.%d", v / 1000, (v / 100) % 10)
}

fmt_mins :: proc(m: i32) -> string {
	v := m
	if v < 0 do v = 0
	if v < 60 {
		return fmt.tprintf("%dm", v)
	}
	return fmt.tprintf("%dh %dm", v / 60, v % 60)
}

fmt_clock_min :: proc(m: i32) -> string {
	v := m
	if v < 0 do v = 0
	hh := v / 60
	mm := v % 60
	if hh > 23 do hh = hh % 24
	return fmt.tprintf("%02d:%02d", hh, mm)
}

scissor :: proc(r: rl.Rectangle) {
	rl.BeginScissorMode(i32(r.x), i32(r.y), i32(r.width), i32(r.height))
}
