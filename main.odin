package edit

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:mem/virtual"
import uc "core:unicode"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "core:strings"

KeyModifier :: enum u8 {
	Shift,
	Control,
	Alt,
}

SpecialKey :: enum rune {
	// Use the surrogate pair range to represent them as runes, the editor is
	// UTF-8 so these codepoints should never appear
	Escape = 0xd800 + 1,
	Return,
	Backspace,
	Tab,
	Home,
	End,
	Up,
	Down,
	Right,
	Left,
}

special_key :: proc(code: SpecialKey) -> rune {
	return rune(code)
}

map_to_special :: proc(k: Key) -> (special: SpecialKey, ok: bool) {
	if .Control in k.mods {
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

Raw_Key_Parser :: struct {
	input: []byte,
	current: int,
}

key_parser_advance :: proc(parser: ^Raw_Key_Parser) -> (byte, bool){
	if parser.current >= len(parser.input) {
		return 0, false
	}
	parser.current += 1
	return parser.input[parser.current - 1], true
}

key_parser_advance_match :: proc(parser: ^Raw_Key_Parser, target: []u8) -> bool {
	if key_parser_has_prefix(parser^, target) {
		parser.current += len(target)
		return true
	}
	return false
}

key_parser_done :: #force_inline proc "contextless" (parser: Raw_Key_Parser) -> bool {
	return parser.current >= len(parser.input)
}

key_parser_has_prefix :: proc(parser: Raw_Key_Parser, prefix: []u8) -> bool {
	if key_parser_done(parser) { return false }
	current_input := parser.input[parser.current:]
	return slice.has_prefix(current_input, prefix)
}

key_parser_next :: proc(parser: ^Raw_Key_Parser) -> (key: Key, had_key: bool) {
	if(key_parser_done(parser^)){ return }

	CSI :: []u8{'\e', '['}

	ARROW_CTRL  :: []u8{'1', ';', '5'}
	ARROW_ALT   :: []u8{'1', ';', '3'}
	ARROW_SHIFT :: []u8{'1', ';', '2'}

	ARROW_CTRL_ALT   :: []u8{'1', ';', '7'}
	ARROW_CTRL_SHIFT :: []u8{'1', ';', '6'}
	ARROW_SHIFT_ALT  :: []u8{'1', ';', '4'}

	ARROW_CTRL_SHIFT_ALT :: []u8{'1', ';', '8'}

	// Special long sequences
	if key_parser_has_prefix(parser^, CSI){
		parser.current += len(CSI)

		switch {
		case key_parser_advance_match(parser, ARROW_CTRL):  key.mods += { .Control }
		case key_parser_advance_match(parser, ARROW_SHIFT): key.mods += { .Shift }
		case key_parser_advance_match(parser, ARROW_ALT):   key.mods += { .Alt }

		case key_parser_advance_match(parser, ARROW_CTRL_ALT):   key.mods += { .Control, .Alt }
		case key_parser_advance_match(parser, ARROW_CTRL_SHIFT): key.mods += { .Control, .Shift }
		case key_parser_advance_match(parser, ARROW_SHIFT_ALT):  key.mods += { .Shift, .Alt }

		case key_parser_advance_match(parser, ARROW_CTRL_SHIFT_ALT):  key.mods += { .Control, .Shift, .Alt }
		}

		next, _ := key_parser_advance(parser)
		switch next {
		case 'A': key.codepoint = special_key(.Up)
		case 'B': key.codepoint = special_key(.Down)
		case 'C': key.codepoint = special_key(.Right)
		case 'D': key.codepoint = special_key(.Left)
		}

		return key, true
	}

	char, _ := key_parser_advance(parser)

	// Alt + Something
	if char == '\e' {
		if key_parser_done(parser^) || parser.input[parser.current] == '\e' {
			key.codepoint = special_key(.Escape)
			key.mods = {}
			return key, true
		}

		key.mods += { .Alt }
		char, _ = key_parser_advance(parser)
	}

	// Control + letter
	if char < 27 {
		key.mods += { .Control }
		key.codepoint = rune('A' + char - 1)
		if char == 0 {
			key.codepoint = ' '
		}

		if special, is_special := map_to_special(key); is_special {
			key.codepoint = rune(special)
			key.mods -= { .Control }
		}
		return key, true
	}

	// Regular char
	if char < 0x80 {
		parser.current -= 1

		r, n := utf8.decode_rune(parser.input[parser.current:])
		parser.current += max(n, 1)
		key.codepoint = r
		return key, true
	}

	return
}

key_decode :: proc(output: []Key, input: []byte) -> []Key{
	parser := Raw_Key_Parser{
		input = input,
		current = 0,
	}

	count := 0
	for key in key_parser_next(&parser){
		if count >= len(output) { break }
		output[count] = key
		count += 1
	}

	return output[:count]

}

main :: proc(){
	TEXT :: "Hellope, world!"

	input := make([]u8, 16)
	key_buffer := make([]Key, 32)

	terminal_setup()
	defer terminal_restore()

	term := terminal_handle()

	running := true

	for running {
		input, _ := terminal_read_input(term, input)
		current_input := input

		dec := key_decode(key_buffer, input)

		fmt.println(dec[:])

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
