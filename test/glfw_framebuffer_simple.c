// clang-15 -O2 -o simple_test glfw_framebuffer_simple.c -L../build -I../vendor/glfw/include -lglfw3 -lm -lGLESv2 -lX11 -I. -Wl,--gc-sections,--icf=all,--strip-all -fuse-ld=lld -flto
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <GLES2/gl2.h>
#include <GLFW/glfw3.h>

int WIDTH = 640, HEIGHT = 480;
int MIN_W = 480;
int MIN_H = 360;
int RENDER_W = 640;
int RENDER_H = 480;
int PREV_RENDER_W = 640;
int PREV_RENDER_H = 480;
int MAX_RENDER = 2048;

GLuint program;
GLuint texture;
GLuint vbo;
unsigned char *pixels = NULL;

const char* vertexShaderSource =
	"attribute vec2 position;\n"
	"attribute vec2 tex_coord;\n"
	"varying vec2 v_tex_coord;\n"
	"void main() {\n"
	"  gl_Position = vec4(position, 0.0, 1.0);\n"
	"  v_tex_coord = tex_coord;\n"
	"}\n";

const char* fragmentShaderSource =
	"precision mediump float;\n"
	"varying vec2 v_tex_coord;\n"
	"uniform sampler2D u_texture;\n"
	"void main() {\n"
	"  gl_FragColor = texture2D(u_texture, v_tex_coord);\n"
	"}\n";

static inline void resize_up_to(int width, int height, int* outwidth, int* outheight, int max) {
	if(width > max || height > max){
		if (width > height) {
			*outwidth = max;
			*outheight = (float)height/width*max ;
			return;
		} else {
			*outheight = max;
			*outwidth = (float)width/height*max;
			return;
		}
	}
	*outwidth = width;
	*outheight = height;
}

void mouse_callback(GLFWwindow* window, int button, int action, int mods) {
	if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS) {
		// Handle left mouse button press
		double xpos, ypos;
		glfwGetCursorPos(window, &xpos, &ypos);
		printf("Left mouse button pressed at (%f, %f)\n", xpos, ypos);
	}
}

static void cursor_position_callback(GLFWwindow* window, double xpos, double ypos)
{
	printf("Cursor moved to (%f, %f)\n", xpos, ypos);
}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	if (key == GLFW_KEY_BACKSPACE) {
		// TODO exponential speedup to max delete (erase current fungi)
		if (action == GLFW_PRESS) {
			printf("PACKSPACE PRESSED\n");
		}
		if (action == GLFW_RELEASE) {
			printf("PACKSPACE RELEASED\n");
		}
	}
	// todo undo
	if (key == GLFW_KEY_Z && (mods & GLFW_MOD_CONTROL) && !(mods & GLFW_MOD_SHIFT) && (action == GLFW_PRESS)) {
		printf("UNDO PRESSED\n");
	}
}

void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
	// A normal mouse wheel, being vertical, provides offsets along the Y-axis.
	// todo exponential to max speed, looking at since last scroll?
	printf("scroll %f\n", yoffset);
}

// This callback is called whenever the framebuffer is resized.
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
	resize_up_to(width, height, &RENDER_W, &RENDER_H, MAX_RENDER);
	WIDTH = width;
	HEIGHT = height;
	printf("Window resized to %d x %d, rendering  %d x %d \n", width, height, RENDER_W, RENDER_H);
}

void init() {
	if (!glfwInit()) {
		fprintf(stderr, "Failed to initialize GLFW\n");
		exit(EXIT_FAILURE);
	}

	glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "OpenGL ES Noise Demo", NULL, NULL);
	if (!window) {
		fprintf(stderr, "Failed to create window\n");
		glfwTerminate();
		exit(EXIT_FAILURE);
	}
	glfwMakeContextCurrent(window);
	glfwSetWindowSizeLimits(window, MIN_W, MIN_H, GLFW_DONT_CARE, GLFW_DONT_CARE);
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
	// glfwSwapInterval(1); // glfw pause for screen update
	glfwSwapInterval(0); // no pause for screen update

	// gui io
	glfwSetMouseButtonCallback(window, mouse_callback);
	glfwSetCursorPosCallback(window, cursor_position_callback);
	glfwSetKeyCallback(window, key_callback);
	glfwSetScrollCallback(window, scroll_callback);

	// Allocate pixel buffer for the texture dimensions.
	pixels = (unsigned char*)malloc(MAX_RENDER * MAX_RENDER * 4);
	// seed rng
	srand(time(0));


	// Compile shaders.
	GLuint vs = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vs, 1, &vertexShaderSource, NULL);
	glCompileShader(vs);
	// (Consider adding error checking here.)

	GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fs, 1, &fragmentShaderSource, NULL);
	glCompileShader(fs);
	// (Consider adding error checking here.)

	program = glCreateProgram();
	glAttachShader(program, vs);
	glAttachShader(program, fs);
	glLinkProgram(program);
	// (Check linking errors if desired.)
	glUseProgram(program);

	// Create a VBO with interleaved position and texture coordinates.
	// We use a triangle that spans the entire screen
	float vertices[] = {
		// Position    // Tex Coords
		-1.0f, -1.0f,  0.0f, 0.0f, // bottom left
		 3.0f, -1.0f,  2.0f, 0.0f, // bottom right + extra
		-1.0f,  3.0f,  0.0f, 2.0f  // top left + extra
	};
	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

	GLint posAttrib = glGetAttribLocation(program, "position");
	glEnableVertexAttribArray(posAttrib);
	glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);

	GLint texAttrib = glGetAttribLocation(program, "tex_coord");
	glEnableVertexAttribArray(texAttrib);
	glVertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

	// Create and configure the texture.
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); // GL_LINEAR
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);


	// do not initialize storage
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, RENDER_W, RENDER_H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	// glActiveTexture(GL_TEXTURE0); // implied/default texture unit

	// implied/assumed.
	// GLint texUniform = glGetUniformLocation(program, "u_texture");
	// glUniform1i(texUniform, 0);
}

void draw(unsigned char* pixels_rgba) {
	/// 1. Resize if needed.
	// if resize, make new texture
	if (RENDER_H != PREV_RENDER_H || RENDER_W != PREV_RENDER_W) {
		// Reinitialize the texture storage to the new dimensions.
		// glBindTexture(GL_TEXTURE_2D, texture);
		// Passing NULL as data to allocate storage without initializing it.
		// re-use existing texture.
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, RENDER_W, RENDER_H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		// Reinitialize the viewport.
		glViewport(0, 0, WIDTH, HEIGHT);
		PREV_RENDER_H = RENDER_H;
		PREV_RENDER_W = RENDER_W;
	}

	/// 2. Update Pixels
	// glBindTexture(GL_TEXTURE_2D, texture);
	// Update the texture with the new data.
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, RENDER_W, RENDER_H, GL_RGBA, GL_UNSIGNED_BYTE, pixels_rgba);

	/// 3. Display
	// glClear(GL_COLOR_BUFFER_BIT);
	// glActiveTexture(GL_TEXTURE0);
	// glBindTexture(GL_TEXTURE_2D, texture);
	glDrawArrays(GL_TRIANGLES, 0, 3);
	glfwSwapBuffers(glfwGetCurrentContext());
}


int main() {
	init();
	GLFWwindow* window = glfwGetCurrentContext();

	int i = 0;
	while (!glfwWindowShouldClose(window)) {
		// Generate new random noise in the pixel buffer.
		for (int i = 0; i < RENDER_W * RENDER_H; i+=4) {
			int r = rand();
			pixels[i * 4 + 0] = r & 255;
			pixels[i * 4 + 1] = (r * r) & 255;
			pixels[i * 4 + 2] = (r + 17) & 255;
			pixels[i * 4 + 3] = 255;
			r = r >> 7;
			pixels[(i+1) * 4 + 0] = r & 255;
			pixels[(i+1) * 4 + 1] = (r * r) & 255;
			pixels[(i+1) * 4 + 2] = (r + 17) & 255;
			pixels[(i+1) * 4 + 3] = 255;
			r = r >> 7;
			pixels[(i+2) * 4 + 0] = r & 255;
			pixels[(i+2) * 4 + 1] = (r * r) & 255;
			pixels[(i+2) * 4 + 2] = (r + 17) & 255;
			pixels[(i+2) * 4 + 3] = 255;
			r = r >> 7;
			pixels[(i+3) * 4 + 0] = r & 255;
			pixels[(i+3) * 4 + 1] = (r * r) & 255;
			pixels[(i+3) * 4 + 2] = (r + 17) & 255;
			pixels[(i+3) * 4 + 3] = 255;
		}
		draw(pixels);
		glfwPollEvents();
		i += 1;
		printf("i=%d\n", i);  // 30 fps small
	}

	glDeleteProgram(program);
	glDeleteBuffers(1, &vbo);
	glDeleteTextures(1, &texture);
	glfwTerminate();
	free(pixels);
	return 0;
}
