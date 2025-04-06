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
	// display(table)
	insert_at_start_of_piece(&table, 0, "Skibidi ")
	// display(table)
	insert_at_start_of_piece(&table, 1, "Bopbop ")
	display(table)

	insert_at_piece(&table, {0, 3}, "BAH")
	insert_at_piece(&table, {2, 0}, "---")
	insert_at_piece(&table, {4, 3}, "zip zap zop")
	insert_at_piece(&table, {4, 3}, "X")
	insert_at_piece(&table, {6, 0}, "y")
	display(table)
}
