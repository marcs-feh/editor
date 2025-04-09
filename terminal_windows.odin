#+build windows
package edit

import win "core:sys/windows"

terminal_setup :: proc(){
	handle := win.GetStdHandle(win.STD_INPUT_HANDLE)
	win.SetConsoleMode(handle, win.ENABLE_VIRTUAL_TERMINAL_INPUT)
	win.SetConsoleCP(.UTF8)
	win.SetConsoleOutputCP(.UTF8)
}

terminal_handle :: proc() -> win.HANDLE {
	return win.GetStdHandle(win.STD_INPUT_HANDLE)
}

