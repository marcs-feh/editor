package edit

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:unicode/utf8"

import "core:strings"
import rl "vendor:raylib"

FONT :: #load("assets/departure_mono/DepartureMono-Regular.otf", []byte)
FONT_SIZE :: 22

get_text_views :: proc(table: Piece_Table, allocator := context.allocator) -> (append_buf_view, original_buf_view, text_view : cstring) {
	context.allocator = allocator

	/* Append buf */ {
		builder : strings.Builder
		strings.builder_init(&builder)

		append_buf_bytes := transmute([]byte)fmt.sbprintf(&builder, "%q", string(table.append_buf[:]))
		append_buf_bytes[len(append_buf_bytes) - 1] = 0
		append_buf_view = cstring(raw_data(append_buf_bytes[1:]))
	}
	/* Original buf */ {
		builder : strings.Builder
		strings.builder_init(&builder)

		original_buf_bytes := transmute([]byte)fmt.sbprintf(&builder, "%q", string(table.original_buf[:]))
		original_buf_bytes[len(original_buf_bytes) - 1] = 0
		original_buf_view = cstring(raw_data(original_buf_bytes[1:]))
	}

	/* Text view */ {
		builder : strings.Builder
		strings.builder_init(&builder)

		s, _ := table_build_string(table, allocator)
		text_view = cstring(raw_data(s))
	}

	return
}

draw_text :: proc(font: rl.Font, text: cstring, pos: rl.Vector2, color: rl.Color) -> (width, height: f32) {
	dim := rl.MeasureTextEx(font, text, FONT_SIZE, 0)
	rl.DrawTextEx(font, text, pos, FONT_SIZE, 0, color)
	return dim.x, dim.y
}

main :: proc(){
	// --- Raylib init ---
	rl.InitWindow(800, 600, "Edit")
	rl.SetTargetFPS(60)

	font := rl.LoadFontFromMemory(".OTF", raw_data(FONT), auto_cast len(FONT), FONT_SIZE, nil, -1)
	rl.SetTextureFilter(font.texture, .POINT)

	// --- Table init ---
	TEXT :: "Hellope, world!"

	table, _ := table_create(TEXT)
	display(table)

	off := buffer_append(&table, "It's hammer time")
	piece_add(&table, 1, .Append, off, 16)

	off = buffer_append(&table, "Yo...\n")
	piece_add(&table, 0, .Append, off, 6)

	display(table)

	// --- Render ---
	text_view_arena : virtual.Arena
	arena_error := virtual.arena_init_static(&text_view_arena, 64 * mem.Megabyte)
	ensure(arena_error == nil, "Failed to initialize view arena")
	text_view_allocator := virtual.arena_allocator(&text_view_arena)

	append_buf_view, original_buf_view, text_view := get_text_views(table, text_view_allocator)

	cyan :: rl.Color{ 0x50, 0xd3, 0xf4, 0xff}
	yellow :: rl.Color{ 0xf4, 0xe6, 0x50, 0xff}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		BASE_POS :: [2]f32{ 10, 10 }
		offset : [2]f32


		/* Original buf */ {
			w, h := draw_text(font, "Original:", BASE_POS + offset, rl.WHITE)
			draw_text(font, original_buf_view, BASE_POS + offset + {w, 0} , cyan)
			offset.y += h
		}
		/* Append buf */ {
			w, h := draw_text(font, "Append:", BASE_POS + offset, rl.WHITE)
			draw_text(font, append_buf_view, BASE_POS + offset + {w, 0} , yellow)
			offset.y += h
		}
		/* Text view */ {
			w, h := draw_text(font, "Content:", BASE_POS + offset, rl.WHITE)
			draw_text(font, text_view, BASE_POS + offset + {0, h} , yellow)
			offset.y += h
		}

		rl.EndDrawing()
	}

}

