#include <GLFW/glfw3.h>
#include <GL/gl.h>
#include <stdio.h>
#include <stdlib.h>


// Function prototypes
void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void createShaders();

GLuint vertexShader, fragmentShader, shaderProgram;
GLuint vbo;

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

    // Create and populate VBO
    GLuint vbo;
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    // Point data: position (3 floats) and color (3 floats) per point
    float points[] = {
        // Position       // Color
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f,  // Center (Red)
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f, 0.0f,  // Bottom-left (Green)
        0.5f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f,  // Bottom-right (Blue)
        0.0f, 0.5f, 0.0f, 1.0f, 1.0f, 0.0f,   // Top (Yellow)
        // Add more points as needed
    };

    glBufferData(GL_ARRAY_BUFFER, sizeof(points), points, GL_STATIC_DRAW);

    // Link attributes to buffer
    GLuint positionAttribute = glGetAttribLocation(shaderProgram, "position");
    GLuint colorAttribute = glGetAttribLocation(shaderProgram, "color");

    glEnableVertexAttribArray(positionAttribute);
    glEnableVertexAttribArray(colorAttribute);

    glVertexAttribPointer(positionAttribute, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
    glVertexAttribPointer(colorAttribute, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));

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

        // Draw all points
        glDrawArrays(GL_POINTS, 0, 4);  // Adjust the count based on the number of points

        // Swap buffers
        glfwSwapBuffers(window);

        // Poll for events
        glfwPollEvents();
    }

    // Cleanup
    glDeleteBuffers(1, &vbo);
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
        "attribute vec3 color;"
        "varying vec3 vColor;"
        "void main() {"
        "    gl_Position = vec4(position, 1.0);"
        "    vColor = color;"
        "}\n";

    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    const char* fragmentShaderSource = "#version 100\n"
        "precision mediump float;"
        "varying vec3 vColor;"
        "void main() {"
        "    gl_FragColor = vec4(vColor, 1.0);"
        "}\n";

    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
}