package edit

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:unicode/utf8"

import "core:strings"

main :: proc(){
	TEXT :: "Hellope, world!"

	table, _ := table_create(TEXT)
	display(table)
	insert_at_start_of_piece(&table, 0, "Skibidi")
	display(table)
	insert_at_start_of_piece(&table, 1, "Bopbop")
	display(table)
	insert_at_start_of_piece(&table, 2, " ksjfdkj ")
	display(table)
}
