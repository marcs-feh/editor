#+build linux
package edit

import "core:sys/posix"

Terminal_Handle :: distinct posix.FD


term_saved_attrs : posix.termios

term_have_saved_attrs := false

terminal_setup :: proc(){
	term : posix.termios
	posix.tcgetattr(posix.STDIN_FILENO, &term)

	if !term_have_saved_attrs {
		term_saved_attrs = term
		term_have_saved_attrs = true
	}

	term.c_lflag -= { .ICANON, .ECHO, .ISIG, }
	term.c_iflag = {}

	ok := posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &term) == .OK
	ensure(ok, "Failed to set terminal attribute")
}

terminal_restore :: proc(){
	posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &term_saved_attrs)
}

terminal_handle :: proc() -> Terminal_Handle {
	return posix.STDIN_FILENO
}

terminal_read_input :: proc(handle: Terminal_Handle, buf: []byte) -> (read: []byte, ok: bool){
	if n := posix.read(auto_cast handle, raw_data(buf), auto_cast len(buf)); n >= 0 {
		read = buf[:n]
		ok = true
	}
	return
}

