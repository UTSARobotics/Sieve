#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>



// Function prototypes
void framebuffer_size_callback(GLFWwindow* window, int width, int height);

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

    // Variables to store window size
    int window_width = WIDTH;
    int window_height = HEIGHT;

    // Main loop
    while (!glfwWindowShouldClose(window)) {
        // Check if window size has changed
        glfwGetWindowSize(window, &window_width, &window_height);

        // Clear the screen
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // Here is where you can write to the framebuffer
        // For example, draw a simple point
        glBegin(GL_POINTS);
        glColor3f(1.0f, 0.0f, 0.0f);
        glVertex2f(0.0f, 0.0f); // Draw at the center of the window 
        glEnd();

        // Swap buffers
        glfwSwapBuffers(window);

        // Poll for events
        glfwPollEvents();
    }

    // Terminate GLFW
    glfwTerminate();
    return 0;
}

// Callback function for window resize
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    // Update viewport when window is resized
    glViewport(0, 0, width, height);
}