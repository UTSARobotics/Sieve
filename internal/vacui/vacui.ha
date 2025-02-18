use types::c;
use fmt;

// Must be even power of two
export def EVENT_BUFFER_LENGTH:size = 512;

export type uieventbuffer = struct {
	index: size,
	read: size,
	buffer: [EVENT_BUFFER_LENGTH]uievent
};

// use draw_width and draw_height for buffer resolution
export type ui = struct {
	draw_width: int,
	draw_height: int,
	max: int,
	resize: bool,
	window_width: int,
	window_height: int,
	prev_width: int,
	prev_height: int,
	gl_program: int,
	gl_vertex_buffer: int,
	gl_texture: int,
	gles_window: nullable *opaque,
	events: uieventbuffer
};

// Errors
export type nodisplay = !void;
export type wrongsize = !void;
export type error = !(nodisplay | wrongsize);

fn strerror(err: error) str = {
	match(err) {
	case nodisplay =>
		return "Could not create display window";
	case wrongsize =>
		return "Provided pixel buffer does not match draw size";
	};
};

// for now, just static. In the future, cb can hash map on window.
let UI:ui = ui {
	events = uieventbuffer { index = 0, read = 0, buffer=[noevent...]},
	...
};

// Initialize a framebuffer window for display
// `name` is the display name for the window
// `width` and `height` determine the initial, minimum window dimensions
// `max_size` determines the maximum number of pixels (w/h) for rendering
export fn init(
	name: str,
	width: int,
	height: int,
	max_size: int
) ( void | nodisplay ) = {
	// 1. Create Window
	if(glfwInit() == 0) {
		return nodisplay;
	};
	init_glfw_backend(); // GL/GLES-specific init

	glfwWindowHint(GLFW_RESIZABLE, 1);
	assert(glfwGetError(null)==0);
	let name_buf:[64]c::char = [0...];
	let cname = c::fromstr_buf(name, name_buf);
	let window: *opaque = glfwCreateWindow(width, height, cname,
		null, null);
	if(window == null) {
		return nodisplay;
	};

	glfwMakeContextCurrent(window);
	assert(glfwGetError(null)==0);

	// set size limits to initial and unbounded
	glfwSetWindowSizeLimits(window, width, height, -1, -1);

	// 1.5 Set up callbacks
	glfwSetFramebufferSizeCallback(window, &resize_callback);

	// No pause between frames
	glfwSwapInterval(0);

	// 2. Set up shaders
	let gl_vs = glCreateShader(GL_VERTEX_SHADER);
	let gl_fs = glCreateShader(GL_FRAGMENT_SHADER);
	let vertex_src_c = c::nulstr(VERTEX_SHADER);
	let fragment_src_c = c::nulstr(FRAGMENT_SHADER);
	glShaderSource(gl_vs, 1, &vertex_src_c, null);
	glShaderSource(gl_fs, 1, &fragment_src_c, null);
	glCompileShader(gl_vs);
	glCompileShader(gl_fs);

	let gl_prog = glCreateProgram();
	glAttachShader(gl_prog, gl_vs);
	glAttachShader(gl_prog, gl_fs);
	glLinkProgram(gl_prog);
	glUseProgram(gl_prog);


	// 3. Set up vertex buffer
	// Interleaved position and texture coordinate for cache access
	let vertices: []f32 = [
		-1.0, -1.0,  0.0, 0.0, // bottom left
		 3.0, -1.0,  2.0, 0.0, // bottom right + extra
		-1.0,  3.0,  0.0, 2.0  // top left + extra
	];

	let gl_buf: int = 0;
	glGenBuffers(1, &gl_buf);
	glBindBuffer(GL_ARRAY_BUFFER, gl_buf);
	glBufferData(GL_ARRAY_BUFFER, (len(vertices)*size(f32)):int, &vertices[0],
		GL_STATIC_DRAW);

	// Set attribute locations in buffer
	let pos_attribute = glGetAttribLocation(gl_prog,
		c::nulstr("position\0"));
	let tex_attribute = glGetAttribLocation(gl_prog,
		c::nulstr("tex_coord\0"));
	glEnableVertexAttribArray(pos_attribute);
	glEnableVertexAttribArray(tex_attribute);
	glVertexAttribPointer(pos_attribute, 2, GL_FLOAT, 0,
		4 * size(f32):int, 0);
	glVertexAttribPointer(tex_attribute, 2, GL_FLOAT, 0,
		4 * size(f32):int, 2*size(f32):i64);  // Use i64 for the offset

	// 4. Set up framebuffer
	const (draw_width, draw_height) = windowsize(width, height, max_size);
	let gl_texture: int = 0;
	glGenTextures(1, &gl_texture);
	glBindTexture(GL_TEXTURE_2D, gl_texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, draw_width, draw_height, 0,
		GL_RGBA, GL_UNSIGNED_BYTE, null);

	UI.draw_width = draw_width;
	UI.draw_height = draw_height;
	UI.max = max_size;
	UI.resize = false;
	UI.gl_program = gl_prog;
	UI.gl_vertex_buffer = gl_buf;
	UI.gl_texture = gl_texture;
	UI.gles_window = window;
	assert(glfwGetError(null)==0);
};

// Draw pixel buffer on the screen
export fn draw(rgba_pixels:[]u8) ( wrongsize | void ) = {
	// 0. Check size
	if (len(rgba_pixels) != (UI.draw_width*UI.draw_height*4):size) {
		return wrongsize;
	};

	// 1. Resize if needed
	if(UI.resize) {
		// Update texture size
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, UI.draw_width,
			UI.draw_height, 0, GL_RGBA, GL_UNSIGNED_BYTE,
			null);
		// Update viewport size
		glViewport(0, 0, UI.window_width, UI.window_height);
		UI.resize = false;
	};

	// 2. Copy pixels
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, UI.draw_width, UI.draw_height,
		GL_RGBA, GL_UNSIGNED_BYTE, &rgba_pixels[0]);

	// 3. Display
	glDrawArrays(GL_TRIANGLES, 0, 3);
	glfwSwapBuffers(UI.gles_window);
};

export fn ok() bool = {
	return (glfwWindowShouldClose(UI.gles_window) == 0);
};

// Check for new events, returning the count of unread events
export fn checkevents() size = {
	glfwPollEvents();
	return UI.events.index - UI.events.read;
};

// Get the next unread event or 'noevent'
export fn readevent() uievent = {
	const n_events:size = UI.events.index - UI.events.read;
	if(n_events == 0) {
		return noevent;
	};

	// Fast forward if over half unread events
	// Consider returning an error, but that would be kinda annoying.
	if (n_events > EVENT_BUFFER_LENGTH>>1) {
		UI.events.read = UI.events.index;
		return noevent;
	};

	// Return last unread event.
	// fast modulo for power-of-two: read % 1024 == read & (1024 - 1)
	let unread = UI.events.buffer[UI.events.read & (EVENT_BUFFER_LENGTH-1)];
	UI.events.read += 1;
	return unread;
};

// Get the current rendering size (width, height)
export fn readsize() (size, size) = {
	return (UI.draw_width:size, UI.draw_height:size);
};

fn resize_callback(window: *opaque, w: int, h: int) void = {
	const (draw_width, draw_height) = windowsize(w, h, UI.max);
	UI.draw_width = draw_width;
	UI.draw_height = draw_height;
	UI.window_width = w;
	UI.window_height = h;
	UI.resize = true;
};

// return (draw_width, draw_height) up to max pixels, preserving aspect ratio.
fn windowsize(width:int, height: int, max: int) (int, int) = {
	if (width > max || height > max) {
		let scale = if (width > height) {
			yield max:f32 / width:f32;
		} else {
			yield max:f32 / height:f32;
		};
		return ((scale*width:f32):int, (scale*height:f32):int);
	};
	return (width, height);
};

fn mousemove_callback(window: *opaque, x:f64, y:f64) void = {
	UI.events.index += 1;
	let newevent = mousemove {
		x = x:f32 / UI.window_width:f32,
		y = y:f32 / UI.window_width:f32
	};
	UI.events.buffer[UI.events.index & (EVENT_BUFFER_LENGTH-1)] = newevent;
};

fn mousebutton_callback(window: *opaque, button: int, action: int, mods: int
) void = {
	UI.events.index += 1;
	let newevent = mousebutton {
		button = button,
		action = action,
		mods = mods
	};
	UI.events.buffer[UI.events.index & (EVENT_BUFFER_LENGTH-1)] = newevent;
};

fn scroll_callback(window: *opaque, x: f64, y:f64) void = {
	UI.events.index += 1;
	let newevent = scroll {
		x = x:f32,
		y = y:f32
	};
	UI.events.buffer[UI.events.index & (EVENT_BUFFER_LENGTH-1)] = newevent;
};


fn keypress_callback(window: *opaque, key: int, scancode: int, action: int,
		mods: int) void = {
	UI.events.index += 1;
	let newevent = keypress {
		key = key,
		action = action,
		mods = mods,
		scancode = scancode
	};
	UI.events.buffer[UI.events.index & (EVENT_BUFFER_LENGTH-1)] = newevent;
};
