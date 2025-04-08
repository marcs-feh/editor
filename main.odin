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

	_, _ = piece_split(&table, {0, 4})
	_, _ = piece_split(&table, {1, 4})

	display(table)

	delete_bytes(&table, {0, 0}, 9)
	delete_bytes(&table, {0, 5}, 1)
	display(table)
}
