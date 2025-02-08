// hare build -L ../../build -lheif -lglfw3 -lGL -lX11 -lm -lc  -ljpeg -lde265 -lstdc++ -lx265
use os;
use io;
use fmt;
use types::c;
export @symbol("fdopen") fn fdopen(handle:int, permissions:*c::char) *opaque;
export @symbol("fopen") fn fopen(files:*c::char, permissions:*c::char) *opaque;

// Define HEIF functions
export @symbol("heif_context_alloc") fn heif_context_alloc() *opaque;
export @symbol("heif_context_read_from_file") fn heif_context_read_from_file(ctx:*opaque, filename:*c::char, options:*opaque) heif_error;
export @symbol("heif_context_get_primary_image_handle") fn heif_context_get_primary_image_handle(ctx:*opaque, handle:**opaque) void;
export @symbol("heif_decode_image") fn heif_decode_image(handle:*opaque, img:*opaque, heif_colorspace_RGB:int, heif_chroma_interleaved_RGB:int, options:*opaque) void;
export @symbol("heif_image_get_plane_readonly") fn heif_image_get_plane_readonly(img:*opaque, channel:int, stride:*int) *u8;

// Define libjpeg functions and data
// Forward declaration of JPEG structures
// Minimal struct definition for jpeg_decompress_struct
export type jpeg_decompress_struct = struct {
	jpeg_error_mgr: *opaque, // Error handler module
	jpeg_memory_mgr: *opaque, //  Memory manager module
	jpeg_progress_mgr: *opaque, // Progress monitor, or NULL if none
	client_data: *opaque, // Available for use by application
	is_decompressor: bool, // So common code can tell which is which
	global_state: int, // For checking call sequence validity
	src: *opaque, // Source of compressed data
	// Basic description of image --- filled in by jpeg_read_header().
	// Application may inspect these values to decide how to process image.
	image_width: uint, // Nominal image width (from SOF marker)
	image_height: uint, // Nominal image height
	num_components: int, // # of color components in JPEG image
	jpeg_color_space: int, // colorspace of JPEG image
	// more stuff follows, we do not use it...
	remaining: [256]u64
};

type jpeg_error_mgr = struct {
    opaquedata: [16]u64
};

// Function declarations
export @symbol("jpeg_std_error") fn jpeg_std_error(err: *opaque) *opaque;
export @symbol("jpeg_CreateDecompress") fn jpeg_create_decompress(cinfo: *jpeg_decompress_struct, libversion:size, structsize: size) void;
export @symbol("jpeg_destroy_decompress") fn jpeg_destroy_decompress(cinfo: *jpeg_decompress_struct) void;
export @symbol("jpeg_stdio_src") fn jpeg_stdio_src(cinfo: *jpeg_decompress_struct, FILE: *opaque) void;
export @symbol("jpeg_read_header") fn jpeg_read_header(cinfo: *jpeg_decompress_struct, require_image: int) int;
export @symbol("jpeg_start_decompress") fn jpeg_start_decompress(cinfo: *jpeg_decompress_struct) int;
export @symbol("jpeg_read_scanlines") fn jpeg_read_scanlines(cinfo: *jpeg_decompress_struct, buffer: **u8, max_lines: int) int;
export @symbol("jpeg_finish_decompress") fn jpeg_finish_decompress(cinfo: *jpeg_decompress_struct) int;

// Define GLFW functions (forward declarations)
export @symbol("glfwInit") fn glfwInit() int;
export @symbol("glfwCreateWindow") fn glfwCreateWindow(width: int, height: int, title: *c::char, monitor: *opaque, share: *opaque) *opaque;
export @symbol("glfwMakeContextCurrent") fn glfwMakeContextCurrent(window: *opaque) void;
export @symbol("glfwWindowShouldClose") fn glfwWindowShouldClose(window: *opaque) int;
export @symbol("glfwPollEvents") fn glfwPollEvents() void;
export @symbol("glfwSwapBuffers") fn glfwSwapBuffers(window: *opaque) void;
export @symbol("glfwTerminate") fn glfwTerminate() void;

// Define OpenGL functions (only required ones)
export @symbol("glClearColor") fn glClearColor(red: f32, green: f32, blue: f32, alpha: f32) void;
export @symbol("glClear") fn glClear(mask: uint) void;

def GL_COLOR_BUFFER_BIT: uint = 0x4000;

export type heif_error = struct {
code: int,
subcode: int,
message: *c::char,
};

export fn main() void = {
	let (data, width, height, channels) = read_jpeg("test.jpg");
	fmt::printfln("datalen: {}, width: {}, height: {}, channels: {}, mul: {}",
		len(data), width, height, channels, width*height*channels)!;
	for (let i=0z; i<100; i+=1) {
		fmt::printf("{}, ", data[i])!;
	};

	free(data);

	// read_image();
	// Initialize GLFW
	if (glfwInit() == 0) {
		os::exit(1);
	};



	// Create a window
	const title = c::nulstr("Hello GLFW & OpenGL\0");
	const window = glfwCreateWindow(800, 600, title, null:*opaque, null:*opaque);
	if (window == null) {
		glfwTerminate();
		os::exit(1);
	};

	// Make OpenGL context current
	glfwMakeContextCurrent(window);

	// Main loop
	for (glfwWindowShouldClose(window) == 0) {
		// Clear screen with blue color
		glClearColor(0.0, 0.0, 1.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);

		// Swap buffers and poll events
		glfwSwapBuffers(window);
		glfwPollEvents();
	};

	// Cleanup
	glfwTerminate();

};

fn read_image() void = {
	let ctx:*opaque = heif_context_alloc();
	// fmt::printf("ctx {}",ctx)!;
	let c_filename:*c::char = c::fromstr("test.heic");
	defer free(c_filename);
	let img_error:heif_error = heif_context_read_from_file(ctx, c_filename, null:*opaque);
	fmt::printf("code {}",img_error.code)!;
	fmt::printf("subcode {}",img_error.subcode)!;

	// get a handle to the primary image
	let handle = null:*opaque;
	heif_context_get_primary_image_handle(ctx, &handle);
	fmt::printf("handle {}",handle)!;

	// decode the image and convert colorspace to RGB, saved
	// 24bit interleaved
	let img = null:*opaque;
	heif_decode_image(handle, img, 1, 10, null:*opaque);

	let stride:int = 0;
	let data:*u8 = heif_image_get_plane_readonly(img, 10, &stride);
	fmt::printf("data {}",data)!;

};

fn read_jpeg(filename: str) ([]u8, uint, uint, uint) = {
	let c_filename: *c::char = c::fromstr(filename);

	// Open JPEG file
	let file = os::open(filename)!;
	defer io::close(file)!;
	fmt::printf("file {}\n",file:int)!;

	// Declare libjpeg structures
	let dstruct = jpeg_decompress_struct{
		jpeg_error_mgr=null:*opaque,
		jpeg_memory_mgr=null:*opaque,
		jpeg_progress_mgr=null:*opaque,
		client_data=null:*opaque,
		src=null:*opaque,
		...};
	let cinfo = &dstruct;
	let jerr = jpeg_error_mgr {...};

	dstruct.jpeg_error_mgr = jpeg_std_error(&jerr);
	if(dstruct.jpeg_error_mgr == null) {
		fmt::fatal("set jpeg error mgr failed!");
	};
	fmt::printf("err mgr {}\n",dstruct.jpeg_error_mgr)!;
	// jpeg_create_decompress(cinfo, 80, 656);
	jpeg_create_decompress(cinfo, 62, 632);
	defer jpeg_destroy_decompress(cinfo);
	fmt::printf("mem mgr {}\n", (*cinfo).jpeg_memory_mgr)!;

	// Attach file to libjpeg
	let c_file = fdopen(file:int, c::nulstr("rb\0")); // Convert io::file to FILE*
	if(c_file == null) {
		fmt::fatal("file open failed!");
	};

	fmt::printf("cfile {}\n", c_file)!;
	fmt::printf("cinfo.src {}\n", cinfo.src)!;
	jpeg_stdio_src(cinfo, c_file);
	fmt::printf("cinfo.src after jpeg_stdio_src  {}\n", cinfo.src)!;

	fmt::printf("Before jpeg_read_header: cinfo.src = {}\n", cinfo.src)!;

	// Read header and start decompression
	jpeg_read_header(cinfo, 1);
	jpeg_start_decompress(cinfo);


	let width: uint = cinfo.image_width;
	let height: uint = cinfo.image_height;
	let channels: uint = cinfo.num_components:uint;
	let stride: size = width * channels;

	// // Allocate memory for raw image data
	let image_data = alloc([0u8...], width * height * channels)!;
	let row_buffer:*u8 = &(image_data[0]);

	fmt::printf("scanlines")!;
	// Read scanlines into the buffer
	for (let i=0z; i<height; i+= 1) {
		jpeg_read_scanlines(cinfo, &row_buffer, 1);
		row_buffer = (row_buffer:uintptr + stride):*u8;
	};

	jpeg_finish_decompress(cinfo);

	return (image_data, width, height, channels);
};
