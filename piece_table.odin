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
	start: int,
	length: int,
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
	table_index: int,
	new_start: int,
	new_length: int,
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
		length = len(table.original_buf),
	})

	return
}

buffer_append :: proc {
	buffer_append_string,
	buffer_append_bytes,
}

buffer_append_string :: proc(table: ^Piece_Table, data: string) -> (Piece, bool){
	return buffer_append_bytes(table, transmute([]byte)data)
}

// Append bytes to end of buffer, returns piece pointing to it. The piece is not inserted in the table
buffer_append_bytes :: proc(table: ^Piece_Table, data: []u8) -> (piece: Piece, ok: bool){
	ok = len(data) > 0
	piece.type = .Append
	piece.start = len(table.append_buf)
	piece.length = len(data)
	append(&table.append_buf, ..data)
	return
}

piece_add :: proc(table: ^Piece_Table, index: int, type: Piece_Type, start, length: int, loc := #caller_location){
	piece := Piece {
		type = type,
		start = start,
		length = length,
	}

	buf_length := len(table.append_buf if type == .Append else table.original_buf)

	assert(start + length <= buf_length, "Piece goes outside of buffer bounds", loc)

	inject_at(&table.pieces, index, piece)
}

// Position as if the buffer was one contigous string
Virtual_Position :: distinct int

// Position in terms of a piece index and an offset into it
Piece_Position :: struct {
	index: int,
	offset: int,
}

table_text_length :: proc(table: Piece_Table) -> int {
	acc := 0
	for p in table.pieces {
		acc += p.length
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

to_piece_position :: proc(table: Piece_Table, vp: Virtual_Position) -> (Piece_Position, bool) {
	vp := int(vp)
	acc := 0

	for piece, idx in table.pieces {
		acc += piece.length
		if acc >= vp {
			return Piece_Position {
				index = idx,
				offset = acc - vp
			}, true
		}
	}

	return {}, false
}

piece_resize :: proc(table: ^Piece_Table, piece_index: int, start, length: int, loc := #caller_location){
	piece := table.pieces[piece_index]
	buf_length := len(table.append_buf if piece.type == .Append else table.original_buf)

	assert(start + length <= buf_length, "Piece goes outside of buffer bounds", loc)

	piece.start = start
	piece.length = length
	table.pieces[piece_index] = piece
}

piece_is_appendable :: proc(table: Piece_Table, index: int) -> bool {
	piece := table.pieces[index]
	return piece.type == .Append && piece.start + piece.length == len(table.append_buf)
}

piece_append :: proc(table: ^Piece_Table, index: int, data: []byte){
	assert(piece_is_appendable(table^, index), "Piece is not appendable")
	if extra, ok := buffer_append(table, data); ok {
		table.pieces[index].length += extra.length
	}
}

insert_at_start_of_piece :: proc {
	insert_string_at_start_of_piece,
	insert_bytes_at_start_of_piece,
}

insert_string_at_start_of_piece :: proc(table: ^Piece_Table, index: int, data: string){
	insert_bytes_at_start_of_piece(table, index, transmute([]byte)data)
}

insert_bytes_at_start_of_piece :: proc(table: ^Piece_Table, index: int, data: []byte, loc := #caller_location){
	assert(index < len(table.pieces), fmt.tprint("Out of bounds piece index:", index))

	if index == 0 {
		if new_piece, ok := buffer_append(table, data); ok {
			inject_at(&table.pieces, 0, new_piece)
		}
	}
	else {
		previous := index - 1
		if piece_is_appendable(table^, previous){
			piece_append(table, previous, data)
		}
		else {
			if new_piece, ok := buffer_append(table, data); ok {
				inject_at(&table.pieces, index, new_piece)
			}
		}
	}
}

piece_empty :: #force_inline proc "contextless" (piece: Piece) -> bool {
	return piece.length <= 0
}

@require_results
piece_split :: proc(table: ^Piece_Table, pos: Piece_Position) -> (left, right: Piece) {
	piece := table.pieces[pos.index]
	split_offset := int(pos.offset)
	assert(split_offset < piece.length, "Offset is outside of piece")

	left.type   = piece.type
	left.start  = piece.start
	left.length = split_offset

	right.type   = piece.type
	right.start  = piece.start + split_offset
	right.length = piece.length - split_offset

	inject_at(&table.pieces, pos.index, left)
	table.pieces[pos.index + 1] = right

	return
}

piece_delete_bytes :: proc(table: ^Piece_Table, pos: Piece_Position, count: int) -> (deleted: bool) {
	piece := &table.pieces[pos.index]

	assert(int(pos.offset) + count <= piece.length, fmt.tprint("Count", count, "goes beyond piece", piece.length))

	if pos.offset == 0 {
		piece.start += count
		piece.length -= count
		if piece.length <= 0 {
			ordered_remove(&table.pieces, pos.index)
			deleted = true
		}
	}
	else if int(pos.offset) == piece.length - count {
		piece.length -= count
		if piece.length <= 0 {
			ordered_remove(&table.pieces, pos.index)
			deleted = true
		}
	}
	else {
		left, right := piece_split(table, {pos.index, pos.offset})
		return piece_delete_bytes(table, {pos.index + 1, 0}, count)
	}

	return
}

insert_at_piece :: proc {
	insert_string_at_piece,
	insert_bytes_at_piece,
}

insert_string_at_piece :: proc(table: ^Piece_Table, pos: Piece_Position, data: string){
	insert_bytes_at_piece(table, pos, transmute([]byte)data)
}

insert_bytes_at_piece :: proc(table: ^Piece_Table, pos: Piece_Position, data: []byte){
	if len(data) == 0 { return }

	if pos.index == len(table.pieces) {
		if piece, ok := buffer_append(table, data); ok {
			append(&table.pieces, piece)
		}
		return
	}

	if pos.offset == 0 {
		insert_at_start_of_piece(table, pos.index, data)
		return
	}

	left, right := piece_split(table, {pos.index, pos.offset})
	insert_at_start_of_piece(table, pos.index + 1, data)
}

delete_bytes :: proc(table: ^Piece_Table, pos: Piece_Position, count: int){
	count := count
	pos := pos

	piece := table.pieces[pos.index]
	assert(piece.length - pos.offset > 0, "Improper position for first piece")

	n := min(count, piece.length - pos.offset)
	deleted := piece_delete_bytes(table, pos, n)

	pos.offset = 0
	count -= n

	for count > 0 {
		if !deleted {
			pos.index += 1
			if pos.index >= len(table.pieces) {
				break
			}
		}

		piece := table.pieces[pos.index]
		assert(piece.length - pos.offset > 0, "Improper position for first piece")

		n = min(count, piece.length - pos.offset)
		deleted = piece_delete_bytes(table, pos, n)

		pos.offset = 0
		count -= n
	}
}

display :: proc(table: Piece_Table){
	HILIGHT :: "\e[1;33m"
	RESET :: "\e[0m"

	fmt.println("> " + HILIGHT + "Buffers" + RESET)
	fmt.printfln("  Original: %q", string(table.original_buf[:]))
	fmt.printfln("  Append: %q", string(table.append_buf[:]))

	fmt.println("> " + HILIGHT + "Pieces" + RESET)
	fmt.printfln("% 2s | A | % 4s | % 4s | %s", "ID", "OFF", "LEN", "DATA")

	for piece, i in table.pieces {
		t := " " if piece.type == .Original else "+"
		buf := table.append_buf if piece.type == .Append else table.original_buf
		content := string(buf[piece.start:][:piece.length])
		fmt.printfln("% 2d | %s | % 4d | % 4d | %q", i, t, piece.start, piece.length, content)
	}

	fmt.println("> " + HILIGHT + "Content" + RESET)
	for piece in table.pieces {
		buf := table.append_buf if piece.type == .Append else table.original_buf
		content := string(buf[piece.start:][:piece.length])
		fmt.print(content)
	}
	fmt.println("\n----------------------------")
}
