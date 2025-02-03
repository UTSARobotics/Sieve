#define GL_GLEXT_PROTOTYPES
#include <GLFW/glfw3.h>
// #include <GL/gl.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>


// Function prototypes
void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void createShaders();

GLuint vertexShader, fragmentShader, shaderProgram;
GLuint texture, quadVBO, quadTexCoordVBO;

int main() {
    int WIDTH = 640;
    int HEIGHT = 480;
    // Initialize GLFW
    if (!glfwInit()) {
        fprintf(stderr, "Failed to initialize GLFW\n");
        return -1;
    }

    // Set window hints
    glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE); // Enable window resizing

    // Create a window
    GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Framebuffer Window", NULL, NULL);
    if (!window) {
        fprintf(stderr, "Failed to create window\n");
        glfwTerminate();
        return -1;
    }

    // Make the window's context current
    glfwMakeContextCurrent(window);

    // Set the framebuffer resize callback
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // Create shaders
    createShaders();

    // Create and bind the texture
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    // Set texture parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    // Create a 64x64 RGB image filled with random colors
    int imageSize = 2048;
    unsigned char pixels[imageSize * imageSize * 3];
    srand(time(NULL));

    for (int i = 0; i < imageSize * imageSize; i++) {
        pixels[i * 3] = rand() % 256;  // R
        pixels[i * 3 + 1] = rand() % 256;  // G
        pixels[i * 3 + 2] = rand() % 256;  // B
    }

    // Upload pixel data to the texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, imageSize, imageSize, 0, GL_RGB, GL_UNSIGNED_BYTE, pixels);

    // Create vertex buffer for the full-screen quad
    float quadVertices[] = {
        -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        1.0f, 1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f,
    };

    float quadTexCoords[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };

    GLuint quadVBO, quadTexCoordVBO;
    glGenBuffers(1, &quadVBO);
    glGenBuffers(1, &quadTexCoordVBO);

    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, quadTexCoordVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadTexCoords), quadTexCoords, GL_STATIC_DRAW);

    // Link attributes to buffers
    GLuint positionAttribute = glGetAttribLocation(shaderProgram, "position");
    GLuint texCoordAttribute = glGetAttribLocation(shaderProgram, "texCoord");

    glEnableVertexAttribArray(positionAttribute);
    glEnableVertexAttribArray(texCoordAttribute);

    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    glVertexAttribPointer(positionAttribute, 3, GL_FLOAT, GL_FALSE, 0, (void*)0);

    glBindBuffer(GL_ARRAY_BUFFER, quadTexCoordVBO);
    glVertexAttribPointer(texCoordAttribute, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);

    // Set the texture uniform
    GLuint textureUniform = glGetUniformLocation(shaderProgram, "uTexture");
    glUniform1i(textureUniform, 0);

    // Variables to store window size
    int window_width = WIDTH;
    int window_height = HEIGHT;

    // Main loop
    while (!glfwWindowShouldClose(window)) {
        // Check if window size has changed
        glfwGetWindowSize(window, &window_width, &window_height);
        if (window_width != WIDTH || window_height != HEIGHT) {
            // Update framebuffer viewport
            glViewport(0, 0, window_width, window_height);
            WIDTH = window_width;
            HEIGHT = window_height;
        }

        // Clear the screen
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // Use the shader program
        glUseProgram(shaderProgram);

        // Bind the texture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texture);

        // Draw the full-screen quad
        glDrawArrays(GL_QUADS, 0, 4);

        // Swap buffers
        glfwSwapBuffers(window);

        // Poll for events
        glfwPollEvents();
    }

    // Cleanup
    glDeleteBuffers(1, &quadVBO);
    glDeleteBuffers(1, &quadTexCoordVBO);
    glDeleteTextures(1, &texture);
    glDeleteProgram(shaderProgram);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);
    glfwTerminate();
    return 0;
}

// Callback function for window resize
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    // Update viewport when window is resized
    glViewport(0, 0, width, height);
}

// Function to create and compile shaders
void createShaders() {
    const char* vertexShaderSource = "#version 100\n"
        "attribute vec3 position;"
        "attribute vec2 texCoord;"
        "varying vec2 vTexCoord;"
        "void main() {"
        "    gl_Position = vec4(position, 1.0);"
        "    vTexCoord = texCoord;"
        "}\n";

    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    const char* fragmentShaderSource = "#version 100\n"
        "precision mediump float;"
        "varying vec2 vTexCoord;"
        "uniform sampler2D uTexture;"
        "void main() {"
        "    gl_FragColor = texture2D(uTexture, vTexCoord);"
        "}\n";

    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
}