use types::c;

// shader types
def GL_VERTEX_SHADER:int = 0x8B31;
def GL_FRAGMENT_SHADER:int = 0x8B30;

// buffer types
def GL_ARRAY_BUFFER:int = 0x8892;

// static data type
def GL_STATIC_DRAW:int = 0x88E4;
def GL_FLOAT:int = 0x1406;
def GL_UNSIGNED_BYTE:int = 0x1401;
def GL_TEXTURE_2D:int = 0x0DE1;
def GL_NEAREST:int = 0x2600;
def GL_TEXTURE_MIN_FILTER:int = 0x2801;
def GL_TEXTURE_MAG_FILTER:int = 0x2800;
def GL_RGBA:int = 0x1908;
def GL_TRIANGLES:int = 0x0004;

// texture unit; implied zero.
// def GL_TEXTURE0: int = 0x84C0;
// also unnecessary: glActiveTexture

// Shaders

export @symbol("glCreateShader") fn glCreateShader(shader_type: int) int;

export @symbol("glShaderSource") fn glShaderSource(
	shader: int,
	count: int,
	shader_sources: **c::char,
	source_lengths: nullable *int // NULL for null-terminated.
) void;

export @symbol("glCompileShader") fn glCompileShader(shader: int) void;

export @symbol("glAttachShader") fn glAttachShader(
	program: int,
	shader: int
) int;

export @symbol("glCreateProgram") fn glCreateProgram() int;

export @symbol("glLinkProgram") fn glLinkProgram(program: int) void;

export @symbol("glUseProgram") fn glUseProgram(program: int) void;

// Vertex

export @symbol("glGenBuffers")
fn glGenBuffers(count: int, buf_refs: *int) void;

export @symbol("glBindBuffer")
fn glBindBuffer(buf_type: int, buf_ref: int) void;

export @symbol("glBufferData") fn glBufferData(
	buf_type: int,
	data_size: int,
	vertices: *f32,
	draw_type: int
) void;

// set position information
export @symbol("glGetAttribLocation")
fn glGetAttribLocation(program: int, name: *c::char) int;

export @symbol("glEnableVertexAttribArray")
fn glEnableVertexAttribArray(attr_location: int) void;

export @symbol("glVertexAttribPointer") fn glVertexAttribPointer(
	attr_location: int,
	num_elements: int,
	data_type: int,
	normalize: int,
	stride: int,
	start_offset: i64
) void;

// Texture

export @symbol("glGenTextures")
fn glGenTextures(count: int, texture_refs: *int) void;

export @symbol("glBindTexture")
fn glBindTexture(tex_type: int, texture_ref: int) void;

export @symbol("glTexParameteri")
fn glTexParameteri(tex_type: int, filter_type:int, interpolation:int) void;

// Set the size for a GL Texture, optionally providing initial data
// color_format, use GL_RGBA. initial_data: can be null for uninitialized.
export @symbol("glTexImage2D") fn glTexImage2D(
	tex_type: int,
	mip_level: int,
	color_format_internal: int,
	width: int,
	height: int,
	deprecated: int,
	color_format: int,
	data_type: int,
	initial_data: nullable *u8
) void;

// Update a section of a GL Texture
export @symbol("glTexSubImage2D") fn glTexSubImage2D(
	tex_type:int,
	mip_level: int,
	offset_x: int,
	offset_y: int,
	width: int,
	height: int,
	color_format: int,
	data_type: int,
	data: *u8
) void;

// glDrawArrays(GL_TRIANGLES, 0, 3);
export @symbol("glDrawArrays")
fn glDrawArrays(geom_type: int, start_offset: int, count: int) void;

export @symbol("glViewport")
fn glViewport(offset_x: int, offset_y: int, width: int, height: int) void;

// Cleanup

export @symbol("glDeleteProgram")
fn glDeleteProgram(program: int) void;

export @symbol("glDeleteBuffers")
fn glDeleteBuffers(count: int, buffer_refs: *int) void;

export @symbol("glDeleteTextures")
fn glDeleteTextures(count: int, texture_refs: *int) void;

export @symbol("glGetError") fn glGetError() int;