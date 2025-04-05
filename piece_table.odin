package edit

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:unicode/utf8"

Piece_Type :: enum u8 {
	Original,
	Append,
}

Piece :: struct {
	start: i32,
	length: i32,
	type: Piece_Type,
}

Piece_Table :: struct {
	append_buf: [dynamic]u8,
	original_buf: [dynamic]u8,
	pieces: [dynamic]Piece,
}

Edit_Op :: enum u8 {
	BufferAppend,
	PieceAdd,
	PieceResize,
	PiecePop,
}

Operation :: struct {
	text_data: []u8,
	table_index: i32,
	new_start: i32,
	new_length: i32,
	type: Piece_Type,
}

DEFAULT_APPEND_BUFFER_LEN :: 512
DEFAULT_PIECE_BUFFER_LEN :: 128

table_create :: proc(original_text: string, allocator := context.allocator) -> (table: Piece_Table, err: mem.Allocator_Error){
	context.allocator = allocator

	table.append_buf = make([dynamic]u8, 0, DEFAULT_APPEND_BUFFER_LEN) or_return
	table.original_buf = make([dynamic]u8, len(original_text)) or_return
	table.pieces = make([dynamic]Piece, 0, DEFAULT_PIECE_BUFFER_LEN) or_return

	assert(len(original_text) == len(table.original_buf[:]), "Length mismatch")
	copy_from_string(table.original_buf[:], original_text)

	append(&table.pieces, Piece {
		type = .Original,
		start = 0,
		length = i32(len(table.original_buf)),
	})

	return
}

buffer_append :: proc {
	buffer_append_string,
	buffer_append_bytes,
}

buffer_append_string :: proc(table: ^Piece_Table, data: string) -> (start: i32){
	return buffer_append_bytes(table, transmute([]byte)data)
}

buffer_append_bytes :: proc(table: ^Piece_Table, data: []u8) -> (start: i32){
	s := len(table.append_buf)
	append(&table.append_buf, ..data)
	return i32(s)
}

piece_add :: proc(table: ^Piece_Table, index: int, type: Piece_Type, start, length: i32, loc := #caller_location){
	piece := Piece {
		type = type,
		start = start,
		length = length,
	}

	buf_length := len(table.append_buf if type == .Append else table.original_buf)

	assert(int(start + length) <= buf_length, "Piece goes outside of buffer bounds", loc)

	inject_at(&table.pieces, index, piece)
}

// Position as if the buffer was one contigous string
Virtual_Position :: distinct int

// Position in terms of a piece index and an offset into it
Piece_Coordinate :: struct {
	index: int,
	offset: int,
}

table_text_length :: proc(table: Piece_Table) -> int {
	acc := 0
	for p in table.pieces {
		acc += int(p.length)
	}
	return acc
}

table_build_string :: proc(table: Piece_Table, allocator := context.allocator) -> (text: string, err: mem.Allocator_Error) {
	buf := make([dynamic]byte, 0, table_text_length(table) + 1) or_return

	for piece in table.pieces {
		table_buf := table.append_buf if piece.type == .Append else table.original_buf
		content := table_buf[piece.start:][:piece.length]
		append(&buf, ..content)
	}

	return string(buf[:]), nil
}

to_piece_position :: proc(table: Piece_Table, vp: Virtual_Position) -> (Piece_Coordinate, bool) {
	vp := int(vp)
	acc := 0

	for piece, idx in table.pieces {
		acc += int(piece.length)
		if acc >= vp {
			return Piece_Coordinate {
				index = idx,
				offset = acc - vp
			}, true
		}
	}

	return {}, false
}

// insert_text :: proc(table: ^Piece_Table, pos: Position, text: string){
//
// }

display :: proc(table: Piece_Table){
	HILIGHT :: "\e[1;33m"
	RESET :: "\e[0m"

	fmt.println("> " + HILIGHT + "Buffers" + RESET)
	fmt.printfln("  Original: %q", string(table.original_buf[:]))
	fmt.printfln("  Append: %q", string(table.append_buf[:]))

	fmt.println("> " + HILIGHT + "Pieces" + RESET)
	fmt.printfln("% 4s | % 4s | % 4s | %s", "BUF", "OFF", "LEN", "DATA")

	for piece in table.pieces {
		t := "O" if piece.type == .Original else "A"
		buf := table.append_buf if piece.type == .Append else table.original_buf
		content := string(buf[piece.start:][:piece.length])
		fmt.printfln("% 4v | % 4d | % 4d | %q", t, piece.start, piece.length, content)
	}

	fmt.println("> " + HILIGHT + "Content" + RESET)
	for piece in table.pieces {
		buf := table.append_buf if piece.type == .Append else table.original_buf
		content := string(buf[piece.start:][:piece.length])
		fmt.print(content)
	}
	fmt.println("\n----------------------------")
}
