use types::c;

// Common numbers
export def GLFW_CLIENT_API:int = 0x00022001;
export def GLFW_OPENGL_ES_API:int = 0x00030002;
export def GLFW_OPENGL_API:int = 0x00030001; // Default
export def GLFW_CONTEXT_VERSION_MAJOR:int = 0x00022002;
export def GLFW_CONTEXT_VERSION_MINOR:int = 0x00022003;
export def GLFW_RESIZABLE:int = 0x00020003;

// Cursor settings
export def GLFW_CURSOR:int = 0x00033001;
export def GLFW_CURSOR_NORMAL:int = 0x00034001;
export def GLFW_CURSOR_HIDDEN:int = 0x00034002;
export def GLFW_CURSOR_DISABLED:int = 0x00034003;

// Setup
export @symbol("glfwInit") fn glfwInit() int;

export @symbol("glfwWindowHint")
fn glfwWindowHint(parameter: int, value: int) void;

export @symbol("glfwSetWindowSizeLimits")
fn glfwSetWindowSizeLimits(window: *opaque, width: int, height: int,
	max_width: int, max_height: int) void;

export @symbol("glfwCreateWindow") fn glfwCreateWindow(
	width:int, height:int,
	title:*c::char,
	monitor:nullable *opaque,
	share:nullable *opaque
) *opaque;

export @symbol("glfwTerminate") fn glfwTerminate() void;

export @symbol("glfwMakeContextCurrent")
fn glfwMakeContextCurrent(window: *opaque) void;

// Enable/disable pause for screen update
export @symbol("glfwSwapInterval") fn glfwSwapInterval(pause: int) void;

export @symbol("glfwSwapBuffers") fn glfwSwapBuffers(
	window: nullable *opaque
) void;

// Get the current window
export @symbol("glfwGetCurrentContext") fn glfwGetCurrentContext() *opaque;

// Set cursor or other input mode (for panning, gamepad input, etc.)
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_HIDDEN);
// glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
export @symbol("glfwSetInputMode")
fn glfwSetInputMode(window: *opaque, input: int, mode: int) void;

export @symbol("glfwPollEvents") fn glfwPollEvents() void;

export @symbol("glfwWindowShouldClose") fn glfwWindowShouldClose(
	window: nullable *opaque
) int;

export @symbol("glfwGetError") fn glfwGetError(description: nullable **c::char) int;

// Callbacks

export @symbol("glfwSetFramebufferSizeCallback")
fn glfwSetFramebufferSizeCallback(
	window: *opaque,
	callback: *fn(win:*opaque, w:int, h:int) void
) void;

export @symbol("glfwSetMouseButtonCallback") fn glfwSetMouseButtonCallback(
	window: *opaque,
	callback: *fn(win:*opaque, button:int, act:int, mods:int) void
) void;

export @symbol("glfwSetCursorPosCallback") fn glfwSetCursorPosCallback(
	window: *opaque,
	callback: *fn(win:*opaque, x:f64, y:f64) void
) void;

export @symbol("glfwSetKeyCallback") fn glfwSetKeyCallback(
	window: *opaque,
	callback: *fn(win:*opaque, key:int, scan:int, act:int, mods:int) void
) void;

export @symbol("glfwSetScrollCallback") fn glfwSetScrollCallback(
	window: *opaque,
	callback: *fn(win:*opaque, x:f64, y:f64) void
) void;
