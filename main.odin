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
	// Shift,
}

SpecialKey :: enum rune {
	// Use the surrogate pair range to represent them as runes, the editor is
	// UTF-8 so these codepoints should never appear
	Escape = 0xd800 + 1,
	Return,
	Backspace,
	Tab,
}

map_to_special :: proc(k: Key) -> (special: SpecialKey, ok: bool) {
	if k.mods == { .Control } {
		ok = true
		switch k.codepoint {
		case 'M': special = .Return
		case 'I': special = .Tab
		case '[': special = .Escape
		case: ok = false
		}
	}

	return
}

KeyModifiers :: bit_set[KeyModifier; u8]

Key :: struct {
	codepoint: rune,
	mods: KeyModifiers,
}

slice_peek :: proc "contextless" (s: []$T, i: int) -> (e: T, ok: bool) {
	if i < 0 || i >= len(s){
		return
	}
	#no_bounds_check e = s[i]
	return e, true
}

key_decode :: proc(input: []byte) -> (key: Key, rest: []byte) {
	if len(input) < 1 { return }

	consumed := 0

	char := rune(input[0])

	if char == '\e' {
		next, ok := slice_peek(input, 1)
		if !ok || next == '\e' {
			key.codepoint = rune(SpecialKey.Escape)
			rest = input[consumed:]
			return
		}
		key.mods += { .Alt }
		consumed += 1
	}

	char = rune(input[consumed])
	if char >= 1 && char <= 26 {
		letter := 'A' + (char - 1)
		key.mods += { .Control }
		key.codepoint = letter
		consumed += 1
	}
	else if char == 0 {
		key.mods += { .Control }
		key.codepoint = ' '
	}
	else {
		r, n := utf8.decode_rune(input[consumed:])
		consumed += max(1, n) // Force input to continue, even with errors
		key.codepoint = r
	}

	if special, ok := map_to_special(key); ok {
		key.codepoint = rune(special)
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
		input, _ := terminal_read_input(term, input)
		key, _ := key_decode(input)
		fmt.println(input, int(key.codepoint), key)

		if len(input) > 0 && input[0] == 3 {
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
