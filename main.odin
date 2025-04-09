package edit

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import uc "core:unicode"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "core:strings"

KeyModifier :: enum u8 {
	Control,
	Alt,
	Shift,
}

KeyModifiers :: bit_set[KeyModifier; u8]

Key :: struct {
	codepoint: rune,
	mods: KeyModifiers,
}

import win "core:sys/windows"

slice_peek :: proc(s: []$T, i: int) -> (e: T, ok: bool) {
	if i < 0 || i >= len(s){
		return
	}
	return s[i], true
}

key_decode :: proc(input: []byte) -> (key: Key, rest: []byte) {
	if len(input) < 1 { return }

	consumed := 0

	if input[0] == '\e' {
		next, ok := slice_peek(input, 1)

		if ok {
			n : int
			key.codepoint, n = utf8.decode_rune(input[1:])
			key.mods += { .Alt }
			consumed += max(0, n)
		}
	}

	rest = input[consumed:]
	return

}

main :: proc(){
	TEXT :: "Hellope, world!"

	buffer := make([]u16, 8)
	input := make([]u8, len(buffer) * 2)

	terminal_setup()
	term := terminal_handle()

	running := true

	for running {
		n : u32
		win.ReadConsoleW(term, raw_data(buffer), auto_cast len(buffer), &n, nil)

		dec := utf16.decode_to_utf8(input, buffer[:n])
		inputstr := string(input[:dec])

		// fmt.printfln("%q -> %v", inputstr, buffer[:n])

		key, _ := key_decode(input)
		fmt.println(key)
		if input[0] == 3 {
			running = false
		}
	}

	// table, _ := table_create(TEXT)

	// _, _ = piece_split(&table, {0, 4})
	// _, _ = piece_split(&table, {1, 4})

	// display(table)

	// delete_bytes(&table, {0, 0}, 9)
	// delete_bytes(&table, {0, 5}, 1)
	// delete_bytes(&table, {0, 1}, 4)
	// display(table)

}
