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

	piece_delete_bytes(&table, {0, 5}, 2)
	// piece_delete_bytes(&table, {1, 5}, 1)
	display(table)
}
