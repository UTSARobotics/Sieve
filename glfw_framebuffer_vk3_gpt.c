// clang-15 -O3 -o vulkan_test glfw_framebuffer_vk3_gpt.c -L../glfw/build/src -lglfw3 -lvulkan -lm -I. -Wl,--gc-sections -flto
#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VK_CHECK(result) do { \
    VkResult r = result; \
    if (r != VK_SUCCESS) { \
        fprintf(stderr, "Vulkan error %d at %s:%d\n", r, __FILE__, __LINE__); \
        exit(1); \
    } \
} while (0)

#define MIN_WINDOW_WIDTH 480
#define MIN_WINDOW_HEIGHT 360

typedef struct {
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
    VkDevice device;
    VkQueue graphicsQueue;
    uint32_t graphicsQueueFamily;
    VkSurfaceKHR surface;
    VkSwapchainKHR swapchain;
    
    // For our dynamic framebuffer texture
    VkImage textureImage;
    VkDeviceMemory textureMemory;
    VkImageView textureView;
    VkSampler textureSampler;
    
    // Pipeline resources
    VkRenderPass renderPass;
    VkPipelineLayout pipelineLayout;
    VkPipeline pipeline;
    VkCommandPool commandPool;
    VkCommandBuffer commandBuffer;
    VkDescriptorSetLayout descriptorSetLayout;
    VkDescriptorPool descriptorPool;
    VkDescriptorSet descriptorSet;

    // Swapchain resources
    VkFormat swapchainFormat;
    VkExtent2D swapchainExtent;
    uint32_t swapchainImageCount;
    VkImage* swapchainImages;
    VkImageView* swapchainImageViews;
    VkFramebuffer* swapchainFramebuffers;

    // Sync objects
    VkSemaphore imageAvailable;
    VkSemaphore renderFinished;
    VkFence inFlightFence;
    
    // Dynamic size info
    uint32_t width;
    uint32_t height;
    uint8_t* pixels;
    
    // Window
    GLFWwindow* window;
} VulkanState;

//
// Utility functions (shader module creation, memory type finding, etc.)
//

VkShaderModule createShaderModule(VkDevice device, const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Failed to open file: %s\n", filename);
        return VK_NULL_HANDLE;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = (char*)malloc(length);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory for shader\n");
        fclose(file);
        return VK_NULL_HANDLE;
    }

    if (fread(buffer, 1, length, file) != (size_t)length) {
        fprintf(stderr, "Failed to read file: %s\n", filename);
        free(buffer);
        fclose(file);
        return VK_NULL_HANDLE;
    }
    fclose(file);

    VkShaderModuleCreateInfo createInfo = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = length,
        .pCode = (const uint32_t*)buffer
    };

    VkShaderModule shaderModule;
    VkResult result = vkCreateShaderModule(device, &createInfo, NULL, &shaderModule);
    free(buffer);

    if (result != VK_SUCCESS) {
        fprintf(stderr, "Failed to create shader module\n");
        return VK_NULL_HANDLE;
    }

    return shaderModule;
}

uint32_t findMemoryType(VkPhysicalDevice physicalDevice, uint32_t typeFilter, VkMemoryPropertyFlags properties) {
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((typeFilter & (1 << i)) && 
            (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }

    fprintf(stderr, "Failed to find suitable memory type!\n");
    exit(1);
}

//
// Swapchain & Texture creation and cleanup
//

// Creates the swapchain, its image views, and framebuffers.
void createSwapchain(VulkanState* vk) {
    VkSurfaceCapabilitiesKHR capabilities;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vk->physicalDevice, vk->surface, &capabilities);

    uint32_t formatCount;
    vkGetPhysicalDeviceSurfaceFormatsKHR(vk->physicalDevice, vk->surface, &formatCount, NULL);
    VkSurfaceFormatKHR* formats = malloc(formatCount * sizeof(VkSurfaceFormatKHR));
    vkGetPhysicalDeviceSurfaceFormatsKHR(vk->physicalDevice, vk->surface, &formatCount, formats);
    
    // Choose first available format, but prefer B8G8R8A8_UNORM
    vk->swapchainFormat = formats[0].format;
    for (uint32_t i = 0; i < formatCount; i++) {
        if (formats[i].format == VK_FORMAT_B8G8R8A8_UNORM) {
            vk->swapchainFormat = formats[i].format;
            break;
        }
    }
    free(formats);

    VkSwapchainCreateInfoKHR createInfo = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = vk->surface,
        .minImageCount = capabilities.minImageCount + 1,
        .imageFormat = vk->swapchainFormat,
        .imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        .imageExtent = {vk->width, vk->height},
        .imageArrayLayers = 1,
        .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = VK_PRESENT_MODE_FIFO_KHR,
        .clipped = VK_TRUE
    };

    VK_CHECK(vkCreateSwapchainKHR(vk->device, &createInfo, NULL, &vk->swapchain));

    // Get swapchain images
    vkGetSwapchainImagesKHR(vk->device, vk->swapchain, &vk->swapchainImageCount, NULL);
    vk->swapchainImages = malloc(vk->swapchainImageCount * sizeof(VkImage));
    vk->swapchainImageViews = malloc(vk->swapchainImageCount * sizeof(VkImageView));
    vk->swapchainFramebuffers = malloc(vk->swapchainImageCount * sizeof(VkFramebuffer));
    
    vkGetSwapchainImagesKHR(vk->device, vk->swapchain, &vk->swapchainImageCount, vk->swapchainImages);

    // Create image views and framebuffers
    for (uint32_t i = 0; i < vk->swapchainImageCount; i++) {
        VkImageViewCreateInfo viewInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = vk->swapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = vk->swapchainFormat,
            .components.r = VK_COMPONENT_SWIZZLE_IDENTITY,
            .components.g = VK_COMPONENT_SWIZZLE_IDENTITY,
            .components.b = VK_COMPONENT_SWIZZLE_IDENTITY,
            .components.a = VK_COMPONENT_SWIZZLE_IDENTITY,
            .subresourceRange = {
                .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1
            }
        };

        VK_CHECK(vkCreateImageView(vk->device, &viewInfo, NULL, &vk->swapchainImageViews[i]));

        VkFramebufferCreateInfo framebufferInfo = {
            .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = vk->renderPass,
            .attachmentCount = 1,
            .pAttachments = &vk->swapchainImageViews[i],
            .width = vk->width,
            .height = vk->height,
            .layers = 1
        };

        VK_CHECK(vkCreateFramebuffer(vk->device, &framebufferInfo, NULL, &vk->swapchainFramebuffers[i]));
    }
}

// Creates the texture (an image, its memory, and image view) used for the dynamic framebuffer.
VkResult createTexture(VulkanState* vk) {
    VkImageCreateInfo imageInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = VK_IMAGE_TYPE_2D,
        .format = VK_FORMAT_R8G8B8A8_UNORM,
        .extent = { vk->width, vk->height, 1 },
        .mipLevels = 1,
        .arrayLayers = 1,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .tiling = VK_IMAGE_TILING_OPTIMAL,
        .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    };
    
    VK_CHECK(vkCreateImage(vk->device, &imageInfo, NULL, &vk->textureImage));
    
    VkMemoryRequirements memReqs;
    vkGetImageMemoryRequirements(vk->device, vk->textureImage, &memReqs);
    
    VkMemoryAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memReqs.size,
        .memoryTypeIndex = findMemoryType(vk->physicalDevice, memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    };
    
    VK_CHECK(vkAllocateMemory(vk->device, &allocInfo, NULL, &vk->textureMemory));
    VK_CHECK(vkBindImageMemory(vk->device, vk->textureImage, vk->textureMemory, 0));
    
    VkImageViewCreateInfo viewInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = vk->textureImage,
        .viewType = VK_IMAGE_VIEW_TYPE_2D,
        .format = VK_FORMAT_R8G8B8A8_UNORM,
        .subresourceRange = {
            .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1
        }
    };
    
    VK_CHECK(vkCreateImageView(vk->device, &viewInfo, NULL, &vk->textureView));
    
    return VK_SUCCESS;
}

// Frees/destroys swapchain, framebuffer, image view, and texture resources.
void cleanupSwapchain(VulkanState* vk) {
    for (uint32_t i = 0; i < vk->swapchainImageCount; i++) {
        vkDestroyFramebuffer(vk->device, vk->swapchainFramebuffers[i], NULL);
        vkDestroyImageView(vk->device, vk->swapchainImageViews[i], NULL);
    }
    vkDestroySwapchainKHR(vk->device, vk->swapchain, NULL);
    free(vk->swapchainImages);
    free(vk->swapchainImageViews);
    free(vk->swapchainFramebuffers);

    vkDestroyImageView(vk->device, vk->textureView, NULL);
    vkDestroyImage(vk->device, vk->textureImage, NULL);
    vkFreeMemory(vk->device, vk->textureMemory, NULL);

    free(vk->pixels);
}

// Recreates the swapchain (and texture and descriptor set) for a new window size.
void recreateSwapchain(VulkanState* vk, uint32_t newWidth, uint32_t newHeight) {
    vkDeviceWaitIdle(vk->device);

    cleanupSwapchain(vk);

    vk->width = newWidth;
    vk->height = newHeight;
    vk->pixels = malloc(vk->width * vk->height * 4);

    createSwapchain(vk);
    createTexture(vk);

    // Update descriptor set with new texture view.
    VkDescriptorImageInfo imageInfo = {
        .sampler = vk->textureSampler,
        .imageView = vk->textureView,
        .imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    };

    VkWriteDescriptorSet descriptorWrite = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = vk->descriptorSet,
        .dstBinding = 0,
        .dstArrayElement = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .pImageInfo = &imageInfo
    };

    vkUpdateDescriptorSets(vk->device, 1, &descriptorWrite, 0, NULL);
}

//
// Texture update and rendering functions
//

void updateTexture(VulkanState* vk) {
    VkBuffer stagingBuffer;
    VkDeviceMemory stagingMemory;
    
    VkBufferCreateInfo bufferInfo = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = vk->width * vk->height * 4,
        .usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE
    };
    
    VK_CHECK(vkCreateBuffer(vk->device, &bufferInfo, NULL, &stagingBuffer));
    
    VkMemoryRequirements memReqs;
    vkGetBufferMemoryRequirements(vk->device, stagingBuffer, &memReqs);
    
    VkMemoryAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memReqs.size,
        .memoryTypeIndex = findMemoryType(vk->physicalDevice, memReqs.memoryTypeBits,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    };
    
    VK_CHECK(vkAllocateMemory(vk->device, &allocInfo, NULL, &stagingMemory));
    VK_CHECK(vkBindBufferMemory(vk->device, stagingBuffer, stagingMemory, 0));
    
    void* data;
    vkMapMemory(vk->device, stagingMemory, 0, bufferInfo.size, 0, &data);
    memcpy(data, vk->pixels, vk->width * vk->height * 4);
    vkUnmapMemory(vk->device, stagingMemory);

    VkCommandBufferBeginInfo beginInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
    };
    
    VK_CHECK(vkBeginCommandBuffer(vk->commandBuffer, &beginInfo));

    VkImageMemoryBarrier barrier = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .image = vk->textureImage,
        .subresourceRange = {
            .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1
        },
        .srcAccessMask = 0,
        .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT
    };
    
    vkCmdPipelineBarrier(vk->commandBuffer,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0,
        0, NULL,
        0, NULL,
        1, &barrier);
    
    VkBufferImageCopy region = {
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = {
            .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1
        },
        .imageOffset = {0, 0, 0},
        .imageExtent = {vk->width, vk->height, 1}
    };
    
    vkCmdCopyBufferToImage(vk->commandBuffer,
        stagingBuffer,
        vk->textureImage,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1, &region);
    
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    
    vkCmdPipelineBarrier(vk->commandBuffer,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        0,
        0, NULL,
        0, NULL,
        1, &barrier);
    
    VK_CHECK(vkEndCommandBuffer(vk->commandBuffer));
    
    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &vk->commandBuffer
    };
    
    VK_CHECK(vkQueueSubmit(vk->graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE));
    vkQueueWaitIdle(vk->graphicsQueue);
    
    vkDestroyBuffer(vk->device, stagingBuffer, NULL);
    vkFreeMemory(vk->device, stagingMemory, NULL);
}    

// Render a frame. If the presentation returns VK_ERROR_OUT_OF_DATE_KHR or VK_SUBOPTIMAL_KHR,
// then the swapchain is recreated.
void render(VulkanState* vk) {
    vkWaitForFences(vk->device, 1, &vk->inFlightFence, VK_TRUE, UINT64_MAX);
    vkResetFences(vk->device, 1, &vk->inFlightFence);
    
    uint32_t imageIndex;
    VkResult result = vkAcquireNextImageKHR(vk->device, vk->swapchain, UINT64_MAX, 
                                             vk->imageAvailable, VK_NULL_HANDLE, &imageIndex);
    if (result == VK_ERROR_OUT_OF_DATE_KHR) {
        return;  // Skip this frame; the framebuffer callback will trigger a swapchain recreation.
    } else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        VK_CHECK(result);
    }
    
    vkResetCommandBuffer(vk->commandBuffer, 0);
    
    VkCommandBufferBeginInfo beginInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    };
    
    VK_CHECK(vkBeginCommandBuffer(vk->commandBuffer, &beginInfo));
    
    VkClearValue clearValue = {{{0.0f, 0.0f, 0.0f, 1.0f}}};
    VkRenderPassBeginInfo renderPassInfo = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = vk->renderPass,
        .framebuffer = vk->swapchainFramebuffers[imageIndex],
        .renderArea.offset = {0, 0},
        .renderArea.extent = {vk->width, vk->height},
        .clearValueCount = 1,
        .pClearValues = &clearValue
    };
    
    vkCmdBeginRenderPass(vk->commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
    
    // Set dynamic viewport and scissor:
    VkViewport viewport = {
        .x = 0.0f,
        .y = 0.0f,
        .width = (float)vk->width,
        .height = (float)vk->height,
        .minDepth = 0.0f,
        .maxDepth = 1.0f
    };
    vkCmdSetViewport(vk->commandBuffer, 0, 1, &viewport);
    
    VkRect2D scissor = {
        .offset = {0, 0},
        .extent = {vk->width, vk->height}
    };
    vkCmdSetScissor(vk->commandBuffer, 0, 1, &scissor);
    
    vkCmdBindPipeline(vk->commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, vk->pipeline);
    vkCmdBindDescriptorSets(vk->commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
        vk->pipelineLayout, 0, 1, &vk->descriptorSet, 0, NULL);
    
    vkCmdDraw(vk->commandBuffer, 4, 1, 0, 0);
    
    vkCmdEndRenderPass(vk->commandBuffer);
    
    VK_CHECK(vkEndCommandBuffer(vk->commandBuffer));
    
    VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    
    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &vk->imageAvailable,
        .pWaitDstStageMask = waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &vk->commandBuffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &vk->renderFinished
    };
    
    VK_CHECK(vkQueueSubmit(vk->graphicsQueue, 1, &submitInfo, vk->inFlightFence));
    
    VkPresentInfoKHR presentInfo = {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &vk->renderFinished,
        .swapchainCount = 1,
        .pSwapchains = &vk->swapchain,
        .pImageIndices = &imageIndex
    };
    
    result = vkQueuePresentKHR(vk->graphicsQueue, &presentInfo);
    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR) {
        int width, height;
        glfwGetFramebufferSize(vk->window, &width, &height);
        if (width > 0 && height > 0)
            recreateSwapchain(vk, width, height);
    } else {
        VK_CHECK(result);
    }
}

//
// Vulkan initialization and pipeline setup
//

void vk_init(VulkanState* vk) {
    // Instance creation
    VkApplicationInfo appInfo = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Vulkan Dynamic Framebuffer",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = VK_API_VERSION_1_0
    };

    uint32_t glfwExtensionCount = 0;
    const char** glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    VkInstanceCreateInfo createInfo = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = glfwExtensionCount,
        .ppEnabledExtensionNames = glfwExtensions
    };

    printf("Creating instance...\n");
    VK_CHECK(vkCreateInstance(&createInfo, NULL, &vk->instance));
    printf("Instance created.\n");

    // Surface creation
    printf("Creating surface...\n");
    VK_CHECK(glfwCreateWindowSurface(vk->instance, vk->window, NULL, &vk->surface));
    printf("Surface created.\n");

    // Select physical device
    uint32_t deviceCount = 0;
    printf("Enumerating physical devices...\n");
    VK_CHECK(vkEnumeratePhysicalDevices(vk->instance, &deviceCount, NULL));
    
    if (deviceCount == 0) {
        fprintf(stderr, "Failed to find GPUs with Vulkan support\n");
        exit(1);
    }

    VkPhysicalDevice* devices = malloc(sizeof(VkPhysicalDevice) * deviceCount);
    VK_CHECK(vkEnumeratePhysicalDevices(vk->instance, &deviceCount, devices));

    for (uint32_t i = 0; i < deviceCount; i++) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(devices[i], &props);
        printf("Device %d: %s\n", i, props.deviceName);
        
        // Prefer discrete GPU
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            vk->physicalDevice = devices[i];
            printf("Selected discrete GPU: %s\n", props.deviceName);
            break;
        }
    }
    
    if (vk->physicalDevice == VK_NULL_HANDLE) {
        vk->physicalDevice = devices[0];
    }
    free(devices);

    // Find queue family that supports graphics and presentation.
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(vk->physicalDevice, &queueFamilyCount, NULL);
    VkQueueFamilyProperties* queueFamilies = malloc(sizeof(VkQueueFamilyProperties) * queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(vk->physicalDevice, &queueFamilyCount, queueFamilies);

    vk->graphicsQueueFamily = UINT32_MAX;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        VkBool32 presentSupport = VK_FALSE;
        VK_CHECK(vkGetPhysicalDeviceSurfaceSupportKHR(vk->physicalDevice, i, vk->surface, &presentSupport));
        
        if ((queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && presentSupport) {
            vk->graphicsQueueFamily = i;
            break;
        }
    }
    free(queueFamilies);

    if (vk->graphicsQueueFamily == UINT32_MAX) {
        fprintf(stderr, "Failed to find suitable queue family\n");
        exit(1);
    }

    // Logical device creation
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = vk->graphicsQueueFamily,
        .queueCount = 1,
        .pQueuePriorities = &queuePriority
    };

    const char* deviceExtensions[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };

    VkPhysicalDeviceFeatures deviceFeatures = {0};
    VkDeviceCreateInfo deviceCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueCreateInfo,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = deviceExtensions,
        .pEnabledFeatures = &deviceFeatures
    };

    VK_CHECK(vkCreateDevice(vk->physicalDevice, &deviceCreateInfo, NULL, &vk->device));
    vkGetDeviceQueue(vk->device, vk->graphicsQueueFamily, 0, &vk->graphicsQueue);

    // Command pool and buffer
    VkCommandPoolCreateInfo poolInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = vk->graphicsQueueFamily
    };

    VK_CHECK(vkCreateCommandPool(vk->device, &poolInfo, NULL, &vk->commandPool));

    VkCommandBufferAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = vk->commandPool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1
    };

    VK_CHECK(vkAllocateCommandBuffers(vk->device, &allocInfo, &vk->commandBuffer));

    // Sync objects
    VkSemaphoreCreateInfo semaphoreInfo = { .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    VkFenceCreateInfo fenceInfo = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT
    };

    VK_CHECK(vkCreateSemaphore(vk->device, &semaphoreInfo, NULL, &vk->imageAvailable));
    VK_CHECK(vkCreateSemaphore(vk->device, &semaphoreInfo, NULL, &vk->renderFinished));
    VK_CHECK(vkCreateFence(vk->device, &fenceInfo, NULL, &vk->inFlightFence));

    // Render pass creation
    VkAttachmentDescription colorAttachment = {
        .format = VK_FORMAT_B8G8R8A8_UNORM,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    };

    VkAttachmentReference colorAttachmentRef = {
        .attachment = 0,
        .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
    };

    VkSubpassDescription subpass = {
        .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorAttachmentRef
    };

    VkRenderPassCreateInfo renderPassInfo = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &colorAttachment,
        .subpassCount = 1,
        .pSubpasses = &subpass
    };

    VK_CHECK(vkCreateRenderPass(vk->device, &renderPassInfo, NULL, &vk->renderPass));

    // Create initial swapchain and texture.
    createSwapchain(vk);
    createTexture(vk);

    // Descriptor set layout for combined image sampler.
    VkDescriptorSetLayoutBinding samplerLayoutBinding = {
        .binding = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT
    };

    VkDescriptorSetLayoutCreateInfo layoutInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &samplerLayoutBinding
    };

    VK_CHECK(vkCreateDescriptorSetLayout(vk->device, &layoutInfo, NULL, &vk->descriptorSetLayout));

    // Pipeline layout
    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &vk->descriptorSetLayout
    };

    VK_CHECK(vkCreatePipelineLayout(vk->device, &pipelineLayoutInfo, NULL, &vk->pipelineLayout));
}

void vk_init_pipeline(VulkanState* vk) {
    // Create shader modules.
    VkShaderModule vertShaderModule = createShaderModule(vk->device, "vert.spv");
    VkShaderModule fragShaderModule = createShaderModule(vk->device, "frag.spv");

    if (!vertShaderModule || !fragShaderModule) {
        fprintf(stderr, "Failed to create shader modules\n");
        exit(1);
    }

    VkPipelineShaderStageCreateInfo vertShaderStageInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main"
    };

    VkPipelineShaderStageCreateInfo fragShaderStageInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main"
    };

    VkPipelineShaderStageCreateInfo shaderStages[] = {vertShaderStageInfo, fragShaderStageInfo};

    VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    };

    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN
    };

    VkViewport viewport = {
        .width = (float)vk->width,
        .height = (float)vk->height,
        .maxDepth = 1.0f
    };

    VkRect2D scissor = {
        .extent = {vk->width, vk->height}
    };

    VkPipelineViewportStateCreateInfo viewportState = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor
    };

    VkPipelineRasterizationStateCreateInfo rasterizer = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0f,
        .cullMode = VK_CULL_MODE_BACK_BIT,
        .frontFace = VK_FRONT_FACE_CLOCKWISE
    };

    VkPipelineMultisampleStateCreateInfo multisampling = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
    };

    VkPipelineColorBlendAttachmentState colorBlendAttachment = {
        .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = VK_FALSE
    };

    VkPipelineColorBlendStateCreateInfo colorBlending = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = VK_FALSE,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment
    };

    VkDynamicState dynamicStates[] = {
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_SCISSOR
    };
    
    VkPipelineDynamicStateCreateInfo dynamicState = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2,
        .pDynamicStates = dynamicStates
    };

    VkGraphicsPipelineCreateInfo pipelineInfo = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .layout = vk->pipelineLayout,
        .renderPass = vk->renderPass,
        .subpass = 0,
        .pDynamicState = &dynamicState
    };

    VK_CHECK(vkCreateGraphicsPipelines(vk->device, VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &vk->pipeline));

    // Create texture sampler.
    VkSamplerCreateInfo samplerInfo = {
        .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = VK_FILTER_LINEAR,
        .minFilter = VK_FILTER_LINEAR,
        .addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
    };

    VK_CHECK(vkCreateSampler(vk->device, &samplerInfo, NULL, &vk->textureSampler));

    // Create descriptor pool and allocate descriptor set.
    VkDescriptorPoolSize poolSize = {
        .type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1
    };

    VkDescriptorPoolCreateInfo poolInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &poolSize,
        .maxSets = 1
    };

    VK_CHECK(vkCreateDescriptorPool(vk->device, &poolInfo, NULL, &vk->descriptorPool));

    VkDescriptorSetAllocateInfo allocInfoDS = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = vk->descriptorPool,
        .descriptorSetCount = 1,
        .pSetLayouts = &vk->descriptorSetLayout
    };

    VK_CHECK(vkAllocateDescriptorSets(vk->device, &allocInfoDS, &vk->descriptorSet));

    VkDescriptorImageInfo imageInfo = {
        .sampler = vk->textureSampler,
        .imageView = vk->textureView,
        .imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    };

    VkWriteDescriptorSet descriptorWrite = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = vk->descriptorSet,
        .dstBinding = 0,
        .dstArrayElement = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .pImageInfo = &imageInfo
    };

    vkUpdateDescriptorSets(vk->device, 1, &descriptorWrite, 0, NULL);

    vkDestroyShaderModule(vk->device, fragShaderModule, NULL);
    vkDestroyShaderModule(vk->device, vertShaderModule, NULL);
}

//
// GLFW callback: on framebuffer resize, recreate the swapchain.
//
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    if (width == 0 || height == 0)
        return;
    VulkanState* vk = (VulkanState*)glfwGetWindowUserPointer(window);
    recreateSwapchain(vk, width, height);
    printf("Window resized to %d x %d\n", width, height);
}

//
// Main function
//
int main() {
    VulkanState vk = {0};
    vk.width = 640;
    vk.height = 480;

    if (!glfwInit()) {
        fprintf(stderr, "Failed to initialize GLFW\n");
        return -1;
    }

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

    vk.window = glfwCreateWindow(vk.width, vk.height, "Vulkan Renderer", NULL, NULL);
    if (!vk.window) {
        fprintf(stderr, "Failed to create window\n");
        glfwTerminate();
        return -1;
    }

    glfwSetWindowUserPointer(vk.window, &vk);
    glfwSetWindowSizeLimits(vk.window, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, GLFW_DONT_CARE, GLFW_DONT_CARE);
    glfwSetFramebufferSizeCallback(vk.window, framebuffer_size_callback);

    vk.pixels = malloc(vk.width * vk.height * 4);

    vk_init(&vk);
    vk_init_pipeline(&vk);

    while (!glfwWindowShouldClose(vk.window)) {
        // Update the pixel data (random noise for demonstration)
        for (uint32_t i = 0; i < vk.width * vk.height; i++) {
            int r = rand();
            vk.pixels[i * 4] = r % 256;          // R
            vk.pixels[i * 4 + 1] = (r*r) % 256;    // G
            vk.pixels[i * 4 + 2] = (-1*r) % 256;   // B
            vk.pixels[i * 4 + 3] = 255;            // A
        }

        updateTexture(&vk);
        render(&vk);
        glfwPollEvents();
    }

    vkDeviceWaitIdle(vk.device);

    // Cleanup all Vulkan resources.
    for (uint32_t i = 0; i < vk.swapchainImageCount; i++) {
        vkDestroyFramebuffer(vk.device, vk.swapchainFramebuffers[i], NULL);
        vkDestroyImageView(vk.device, vk.swapchainImageViews[i], NULL);
    }

    vkDestroyPipeline(vk.device, vk.pipeline, NULL);
    vkDestroyPipelineLayout(vk.device, vk.pipelineLayout, NULL);
    vkDestroyRenderPass(vk.device, vk.renderPass, NULL);
    vkDestroyDescriptorSetLayout(vk.device, vk.descriptorSetLayout, NULL);
    vkDestroyDescriptorPool(vk.device, vk.descriptorPool, NULL);
    
    if (vk.textureImage != VK_NULL_HANDLE) {
        vkDestroySampler(vk.device, vk.textureSampler, NULL);
        vkDestroyImageView(vk.device, vk.textureView, NULL);
        vkDestroyImage(vk.device, vk.textureImage, NULL);
        vkFreeMemory(vk.device, vk.textureMemory, NULL);
    }

    free(vk.swapchainImages);
    free(vk.swapchainImageViews);
    free(vk.swapchainFramebuffers);
    vkDestroySwapchainKHR(vk.device, vk.swapchain, NULL);

    vkDestroySemaphore(vk.device, vk.renderFinished, NULL);
    vkDestroySemaphore(vk.device, vk.imageAvailable, NULL);
    vkDestroyFence(vk.device, vk.inFlightFence, NULL);
    vkDestroyCommandPool(vk.device, vk.commandPool, NULL);
    vkDestroyDevice(vk.device, NULL);
    vkDestroySurfaceKHR(vk.instance, vk.surface, NULL);
    vkDestroyInstance(vk.instance, NULL);

    free(vk.pixels);
    glfwDestroyWindow(vk.window);
    glfwTerminate();

    return 0;
}
