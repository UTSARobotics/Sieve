
// clang-15 -O3 -o gl_test glfw_framebuffer4.c -L../glfw/build/src -lglfw3 -lm -lGL -I. -Wl,--gc-sections -flto
#define GL_GLEXT_PROTOTYPES
#include <GLFW/glfw3.h>
#include <GL/gl.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int WIDTH;
int HEIGHT;
#define MIN_WINDOW_WIDTH 480
#define MIN_WINDOW_HEIGHT 360

GLuint program;
GLuint texture;
GLuint vbo;
unsigned char* pixels;

void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
	glViewport(0, 0, width, height);
	WIDTH=width;
	HEIGHT=height;
	printf("Window resized to %d x %d\n", width, height);
}

void init() {
	WIDTH=640;
	HEIGHT=480;
	pixels = (unsigned char*)malloc(WIDTH * HEIGHT * 4*16);
	srand(time(NULL));
	// Initialize GLFW
	if (!glfwInit()) {
		fprintf(stderr, "Failed to initialize GLFW\n");
		exit(EXIT_FAILURE);
	}

	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE); // Enable window resizing

	// Create a window
	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "4K Renderer", NULL, NULL);
	if (!window) {
		fprintf(stderr, "Failed to create window\n");
		glfwTerminate();
		exit(EXIT_FAILURE);
	}

	// Make the window's context current
	glfwMakeContextCurrent(window);
	glfwSetWindowSizeLimits(window, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, GLFW_DONT_CARE, GLFW_DONT_CARE);
	glfwSwapInterval(1); // Enable vsync

	// Set the framebuffer resize callback
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

	// Create program
	const char* vertexShader = "#version 100\n"
		"attribute vec2 position;"
		"attribute vec2 tex_coord;"
		"varying vec2 v_tex_coord;"
		"void main() {"
		"    gl_Position = vec4(position, 0.0, 1.0);"
		"    v_tex_coord = tex_coord;"
		"}\n";

	const char* fragmentShader = "#version 100\n"
		"precision mediump float;"
		"varying vec2 v_tex_coord;"
		"uniform sampler2D u_texture;"
		"void main() {"
		"    gl_FragColor = texture2D(u_texture, v_tex_coord);"
		"}\n";

	program = glCreateProgram();
	GLuint vs = glCreateShader(GL_VERTEX_SHADER);
	GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(vs, 1, &vertexShader, NULL);
	glShaderSource(fs, 1, &fragmentShader, NULL);
	glCompileShader(vs);
	glCompileShader(fs);
	glAttachShader(program, vs);
	glAttachShader(program, fs);
	glLinkProgram(program);
	glUseProgram(program);

	// Create VBO for positions
	float vertices[] = {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		1.0f, 1.0f,
		-1.0f, 1.0f
	};
	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

	// Create texture
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

	// Initialize texture with random data
	srand(time(NULL));
	for (int i = 0; i < WIDTH * HEIGHT; i++) {
		int r= rand();
		pixels[i * 4] = r % 256;   // R
		pixels[i * 4 + 1] = r^r % 256; // G
		pixels[i * 4 + 2] = r*r % 256; // B
		pixels[i * 4 + 3] = 255;       // A
	}

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

	// Set up vertex attributes
	GLuint pos_loc = glGetAttribLocation(program, "position");
	GLuint tex_loc = glGetAttribLocation(program, "tex_coord");

	glEnableVertexAttribArray(pos_loc);
	glEnableVertexAttribArray(tex_loc);

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glVertexAttribPointer(pos_loc, 2, GL_FLOAT, GL_FALSE, 0, 0);
	glVertexAttribPointer(tex_loc, 2, GL_FLOAT, GL_FALSE, 0, 0);

	// Set uniform
	GLuint tex_uniform = glGetUniformLocation(program, "u_texture");
	glUniform1i(tex_uniform, 0);
}

void render() {
	// Bind texture
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texture);

	// Draw
	glDrawArrays(GL_QUADS, 0, 4);
}

void update_texture() {
	// Generate new data
	for (int i = 0; i < WIDTH * HEIGHT; i++) {
		int r= rand();
		pixels[i * 4] = r % 256;   // R
		pixels[i * 4 + 1] = (r*r) % 256; // G
		pixels[i * 4 + 2] = (-1*r) % 256; // B
		pixels[i * 4 + 3] = 255;       // A
	}

	// Bind and update texture
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}

int main() {
	init();

	while (!glfwWindowShouldClose(glfwGetCurrentContext())) {
		// Clear screen
		// glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
		// glClear(GL_COLOR_BUFFER_BIT);

		// Render
		render();

		// Swap buffers
		glfwSwapBuffers(glfwGetCurrentContext());

		// Update texture
		update_texture();

		// Poll events
		glfwPollEvents();
	}

	// Cleanup
	glDeleteProgram(program);
	glDeleteBuffers(1, &vbo);
	glDeleteTextures(1, &texture);
	glfwTerminate();
	free(pixels);
	return 0;
}