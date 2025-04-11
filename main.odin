package edit

import "core:fmt"
import "core:mem"
import "core:log"
import "core:slice"
import "core:mem/virtual"
import uc "core:unicode"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "core:strings"

import "vendor:glfw"

KeyModifier :: enum u8 {
	Shift,
	Control,
	Alt,
}

KeyModifiers :: bit_set[KeyModifier; u8]

Key :: struct {
	codepoint: rune,
	mods: KeyModifiers,
}

Raw_Key_Parser :: struct {
	input: []byte,
	current: int,
}

import "base:runtime"

App_State :: struct {
	window: glfw.WindowHandle,
	input: [dynamic]Key,
	ctx: runtime.Context,
}

raw_key_handler :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32){
	state := cast(^App_State)glfw.GetWindowUserPointer(window)
	context = state.ctx
	fmt.println("Code:", scancode, "Action:", action, "Mods:", mods)
}

text_key_handler :: proc "c" (window: glfw.WindowHandle, codepoint: rune, mods: i32){
	state := cast(^App_State)glfw.GetWindowUserPointer(window)
	context = state.ctx
	fmt.println("Press:", codepoint, "Mods:", mods)
}

app_state_init :: proc(state: ^App_State, allocator := context.allocator){
	state.input = make([dynamic]Key, 0, 64)
}

main :: proc(){
	TEXT :: "Hellope, world!"

	state := new(App_State)
	app_state_init(state)

	logger : log.Logger
	logger = log.create_console_logger(.Debug, { .Level, .Time, .Terminal_Color, .Short_File_Path, .Line, .Procedure })
	defer log.destroy_console_logger(logger)

	if !glfw.Init() {
		log.fatal("Failed to initalize GLFW:", glfw.GetError())
		return
	}
	defer glfw.Terminate()

	state.window = glfw.CreateWindow(900, 700, "Editor", nil, nil)
	if state.window == nil {
		log.fatal("Failed to create GLFW window:", glfw.GetError())
		return
	}
	defer glfw.DestroyWindow(state.window)

	glfw.SetWindowUserPointer(state.window, state)
	glfw.SetCharModsCallback(state.window, text_key_handler)
	glfw.SetKeyCallback(state.window, raw_key_handler)

	for !glfw.WindowShouldClose(state.window){
		glfw.PollEvents()
		glfw.SwapBuffers(state.window)
	}
}
