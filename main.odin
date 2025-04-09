package edit

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "core:strings"

import win "core:sys/windows"

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

		fmt.printfln("%q -> %v", inputstr, buffer[:n])

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
