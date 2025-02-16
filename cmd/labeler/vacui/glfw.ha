use types::C;

// Common numbers
def GLFW_CLIENT_API:i64 = 0x00022001;
def GLFW_OPENGL_ES_API:i64 = 0x00030002;
def GLFW_OPENGL_API:i64 = 0x00030001; // Default
def GLFW_CONTEXT_VERSION_MAJOR:i64 = 0x00022002;
def GLFW_CONTEXT_VERSION_MINOR:i64 = 0x00022003;
def GLFW_RESIZABLE:i64 = 0x00020003;

// Cursor settings

def GLFW_CURSOR:i64 = 0x00033001;
def GLFW_CURSOR_NORMAL:i64 = 0x00034001
def GLFW_CURSOR_HIDDEN:i64 = 0x00034002
def GLFW_CURSOR_DISABLED:i64 = 0x00034003

// Setup

export @symbol("glfwWindowHint")
fn glfwWindowHint(shader_type: i64) void;

export @symbol("glfwCreateWindow")
fn glfwCreateWindow(
	width:int, height:int,
	title:*c::char,
	monitor:nullable *opaque=,
	share:nullable *opaque
) *opaque;

export @symbol("glfwTerminate")
fn glfwTerminate() void;

export @symbol("glfwMakeContextCurrent")
fn glfwMakeContextCurrent(window: *opaque) void;

// Enable/disable pause for screen update
export @symbol("glfwSwapInterval")
fn glfwSwapInterval(pause: 0) void;

export @symbol("glfwSwapBuffers")
fn glfwSwapBuffers(window: *opaque) void;

// Get the current window
export @symbol("glfwGetCurrentContext")
fn glfwGetCurrentContext() *opaque;

// Set cursor or other input mode (for panning, gamepad input, etc.)
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_HIDDEN);
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
export @symbol("glfwSetInputMode")
fn glfwSetInputMode(window: *opaque, input: i64, mode: i64) void;

// Callbacks

export @symbol("glfwSetFramebufferSizeCallback")
fn glfwSetFramebufferSizeCallback(
	window: *opaque,
	callback: *fn(win:*opaque, w:int, h:int) void;
) void;

export @symbol("glfwSetMouseButtonCallback")
fn glfwSetMouseButtonCallback(
	window: *opaque,
	callback: *fn(win:*opaque, button:int, act:int, mods:int) void;
) void;

export @symbol("glfwSetCursorPosCallback")
fn glfwSetCursorPosCallback(
	window: *opaque,
	callback: *fn(win:*opaque, x:f64, y:f64) void;
) void;

export @symbol("glfwSetKeyCallback")
fn glfwSetKeyCallback(
	window: *opaque,
	callback: *fn(win:*opaque, key:int, scan:int, act:int, mods:int) void;
) void;

export @symbol("glfwSetScrollCallback")
fn glfwSetScrollCallback(
	window: *opaque,
	callback: *fn(win:*opaque, x:f64, y:f64) void;
) void;
