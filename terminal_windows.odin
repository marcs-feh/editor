#+build windows
package edit

import win "core:sys/windows"

Terminal_Handle :: distinct win.HANDLE

terminal_setup :: proc(){
	handle := win.GetStdHandle(win.STD_INPUT_HANDLE)
	win.SetConsoleMode(handle, win.ENABLE_VIRTUAL_TERMINAL_INPUT)
	win.SetConsoleCP(.UTF8)
	win.SetConsoleOutputCP(.UTF8)
}

terminal_handle :: proc() -> Terminal_Handle {
	return win.GetStdHandle(win.STD_INPUT_HANDLE)
}

terminal_read_input :: proc(handle: Terminal_Handle, buf: []byte) -> (read: []byte, ok: bool){
	unimplemented("Windows terminal read")
	// win.ReadConsoleW(term, raw_data(buffer), auto_cast len(buffer), &n, nil)
	// dec := utf16.decode_to_utf8(input, buffer[:n])
	// inputstr := string(input[:dec])
}
