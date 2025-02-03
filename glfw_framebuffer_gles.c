// clang-15 -O3 -o gles_test glfw_framebuffer_gles.c -L../glfw/build/src -lglfw3 -lm -lGLESv2 -lEGL -I. -Wl,--gc-sections -flto
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <GLES2/gl2.h>
#include <GLFW/glfw3.h>

int WIDTH = 640, HEIGHT = 480;
#define MIN_WINDOW_WIDTH 480
#define MIN_WINDOW_HEIGHT 360

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

// This callback is called whenever the framebuffer is resized.
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
    WIDTH = width;
    HEIGHT = height;
    printf("Window resized to %d x %d\n", width, height);

    // Reallocate the pixel buffer to match the new dimensions.
    if (pixels) {
        free(pixels);
    }
    pixels = (unsigned char*)malloc(WIDTH * HEIGHT * 4);

    // Reinitialize the texture storage to the new dimensions.
    glBindTexture(GL_TEXTURE_2D, texture);
    // Passing NULL as data to allocate storage without initializing it.
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
}

void init() {
    srand(time(NULL));

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
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    glfwSwapInterval(1); // vsync enabled

    // Allocate pixel buffer for the initial texture dimensions.
    pixels = (unsigned char*)malloc(WIDTH * HEIGHT * 4);

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
    // We use a triangle strip for the full-screen quad.
    float vertices[] = {
        // Position      // Tex Coords
        -1.0f, -1.0f,    0.0f, 0.0f, // bottom left
         1.0f, -1.0f,    1.0f, 0.0f, // bottom right
        -1.0f,  1.0f,    0.0f, 1.0f, // top left
         1.0f,  1.0f,    1.0f, 1.0f  // top right
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // Initialize texture with random noise.
    for (int i = 0; i < WIDTH * HEIGHT; i++) {
        int r = rand();
        pixels[i * 4 + 0] = r % 256;
        pixels[i * 4 + 1] = (r * r) % 256;
        pixels[i * 4 + 2] = (r + 17) % 256;
        pixels[i * 4 + 3] = 255;
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    GLint texUniform = glGetUniformLocation(program, "u_texture");
    glUniform1i(texUniform, 0);
}

void update_texture() {
    // Generate new random noise in the pixel buffer.
    for (int i = 0; i < WIDTH * HEIGHT; i++) {
        int r = rand();
        pixels[i * 4 + 0] = r % 256;
        pixels[i * 4 + 1] = (r * r) % 256;
        pixels[i * 4 + 2] = (r + 97) % 256;
        pixels[i * 4 + 3] = 255;
    }
    glBindTexture(GL_TEXTURE_2D, texture);
    // Update the texture with the new data.
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}

void render() {
    glClear(GL_COLOR_BUFFER_BIT);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

int main() {
    init();
    GLFWwindow* window = glfwGetCurrentContext();

    while (!glfwWindowShouldClose(window)) {
        update_texture();
        render();
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glDeleteProgram(program);
    glDeleteBuffers(1, &vbo);
    glDeleteTextures(1, &texture);
    glfwTerminate();
    free(pixels);
    return 0;
}
