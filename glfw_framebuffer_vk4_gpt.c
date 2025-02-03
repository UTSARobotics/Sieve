// demo.c
#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Maximum limits (adjust as needed)
#define MAX_SWAPCHAIN_IMAGES 16
#define MAX_WIDTH 2048
#define MAX_HEIGHT 2048

#define MIN_WINDOW_WIDTH 480
#define MIN_WINDOW_HEIGHT 360

// Simple error checking macro.
#define VK_CHECK(result) do { VkResult r = (result); if (r != VK_SUCCESS) { \
    fprintf(stderr, "Vulkan error %d at %s:%d\n", r, __FILE__, __LINE__); exit(1); } } while (0)

typedef struct {
    // Vulkan instance and device objects
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
    VkDevice device;
    VkQueue graphicsQueue;
    uint32_t graphicsQueueFamily;
    VkSurfaceKHR surface;
    
    // Swapchain and related arrays (fixed maximum size)
    VkSwapchainKHR swapchain;
    VkImage swapchainImages[MAX_SWAPCHAIN_IMAGES];
    VkImageView swapchainImageViews[MAX_SWAPCHAIN_IMAGES];
    VkFramebuffer swapchainFramebuffers[MAX_SWAPCHAIN_IMAGES];
    uint32_t swapchainImageCount;
    VkFormat swapchainFormat;
    VkExtent2D swapchainExtent;
    
    // Texture used for the framebuffer (dynamic image updated each frame)
    VkImage textureImage;
    VkDeviceMemory textureMemory;
    VkImageView textureView;
    VkSampler textureSampler;
    
    // Pipeline, render pass, descriptor, etc.
    VkRenderPass renderPass;
    VkPipelineLayout pipelineLayout;
    VkPipeline pipeline;
    VkDescriptorSetLayout descriptorSetLayout;
    VkDescriptorPool descriptorPool;
    VkDescriptorSet descriptorSet;
    
    // Command pool and a single command buffer for our copy and render commands.
    VkCommandPool commandPool;
    VkCommandBuffer commandBuffer;
    
    // Sync objects
    VkSemaphore imageAvailable;
    VkSemaphore renderFinished;
    VkFence inFlightFence;
    
    // Persistent staging buffer (allocated once to be large enough for the maximum texture)
    VkBuffer stagingBuffer;
    VkDeviceMemory stagingMemory;
    void* stagingMapped;
    
    // Pixel data: allocated on the heap (size: MAX_WIDTH * MAX_HEIGHT * 4)
    unsigned char* pixels;
    // Current framebuffer size (always ≤ MAX_WIDTH/MAX_HEIGHT)
    uint32_t width;
    uint32_t height;
    
    // GLFW window handle
    GLFWwindow* window;
} VulkanState;

// Forward declarations
VkShaderModule createShaderModule(VkDevice device, const char* filename);
uint32_t findMemoryType(VkPhysicalDevice physicalDevice, uint32_t typeFilter, VkMemoryPropertyFlags properties);

//
// 1. Instance, Device, Command Pool, and Sync Objects
//
void initInstanceAndDevice(VulkanState* vk) {
    VkApplicationInfo appInfo = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Simple Vulkan Framebuffer",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = VK_API_VERSION_1_0,
    };

    uint32_t glfwExtCount = 0;
    const char** glfwExt = glfwGetRequiredInstanceExtensions(&glfwExtCount);
    VkInstanceCreateInfo createInfo = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = glfwExtCount,
        .ppEnabledExtensionNames = glfwExt,
    };
    VK_CHECK(vkCreateInstance(&createInfo, NULL, &vk->instance));

    VK_CHECK(glfwCreateWindowSurface(vk->instance, vk->window, NULL, &vk->surface));

    uint32_t deviceCount = 0;
    VK_CHECK(vkEnumeratePhysicalDevices(vk->instance, &deviceCount, NULL));
    if (deviceCount == 0) {
        fprintf(stderr, "Failed to find GPUs with Vulkan support\n");
        exit(1);
    }
    VkPhysicalDevice devices[deviceCount];
    VK_CHECK(vkEnumeratePhysicalDevices(vk->instance, &deviceCount, devices));
    for (uint32_t i = 0; i < deviceCount; i++) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(devices[i], &props);
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            vk->physicalDevice = devices[i];
            break;
        }
    }
    if (vk->physicalDevice == VK_NULL_HANDLE)
        vk->physicalDevice = devices[0];

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(vk->physicalDevice, &queueFamilyCount, NULL);
    VkQueueFamilyProperties queueFamilies[queueFamilyCount];
    vkGetPhysicalDeviceQueueFamilyProperties(vk->physicalDevice, &queueFamilyCount, queueFamilies);
    vk->graphicsQueueFamily = UINT32_MAX;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        VkBool32 presentSupport = VK_FALSE;
        vkGetPhysicalDeviceSurfaceSupportKHR(vk->physicalDevice, i, vk->surface, &presentSupport);
        if ((queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && presentSupport) {
            vk->graphicsQueueFamily = i;
            break;
        }
    }
    if (vk->graphicsQueueFamily == UINT32_MAX) {
        fprintf(stderr, "Failed to find suitable queue family\n");
        exit(1);
    }
    
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueInfo = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = vk->graphicsQueueFamily,
        .queueCount = 1,
        .pQueuePriorities = &queuePriority,
    };
    const char* deviceExts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };
    VkDeviceCreateInfo deviceInfo = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueInfo,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = deviceExts,
    };
    VK_CHECK(vkCreateDevice(vk->physicalDevice, &deviceInfo, NULL, &vk->device));
    vkGetDeviceQueue(vk->device, vk->graphicsQueueFamily, 0, &vk->graphicsQueue);

    VkCommandPoolCreateInfo poolInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = vk->graphicsQueueFamily,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
    };
    VK_CHECK(vkCreateCommandPool(vk->device, &poolInfo, NULL, &vk->commandPool));
    VkCommandBufferAllocateInfo cmdAllocInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = vk->commandPool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };
    VK_CHECK(vkAllocateCommandBuffers(vk->device, &cmdAllocInfo, &vk->commandBuffer));

    VkSemaphoreCreateInfo semInfo = { .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    VK_CHECK(vkCreateSemaphore(vk->device, &semInfo, NULL, &vk->imageAvailable));
    VK_CHECK(vkCreateSemaphore(vk->device, &semInfo, NULL, &vk->renderFinished));
    VkFenceCreateInfo fenceInfo = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT,
    };
    VK_CHECK(vkCreateFence(vk->device, &fenceInfo, NULL, &vk->inFlightFence));
}

//
// 2. Query the swapchain format early (so that the render pass uses a valid format).
//
void querySwapchainFormat(VulkanState* vk) {
    uint32_t formatCount = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(vk->physicalDevice, vk->surface, &formatCount, NULL);
    if (formatCount > 0) {
        VkSurfaceFormatKHR* formats = malloc(formatCount * sizeof(VkSurfaceFormatKHR));
        vkGetPhysicalDeviceSurfaceFormatsKHR(vk->physicalDevice, vk->surface, &formatCount, formats);
        vk->swapchainFormat = formats[0].format;
        for (uint32_t i = 0; i < formatCount; i++) {
            if (formats[i].format == VK_FORMAT_B8G8R8A8_UNORM) {
                vk->swapchainFormat = formats[i].format;
                break;
            }
        }
        free(formats);
    }
}

//
// 3. Pipeline, Render Pass, and Descriptor Setup
//
void initPipeline(VulkanState* vk) {
    // Render pass.
    VkAttachmentDescription colorAttachment = {
        .format = vk->swapchainFormat,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };
    VkAttachmentReference colorRef = {
        .attachment = 0,
        .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    VkSubpassDescription subpass = {
        .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorRef,
    };
    VkRenderPassCreateInfo rpInfo = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &colorAttachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
    };
    VK_CHECK(vkCreateRenderPass(vk->device, &rpInfo, NULL, &vk->renderPass));

    // Descriptor set layout: one combined image sampler.
    VkDescriptorSetLayoutBinding samplerBinding = {
        .binding = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT,
    };
    VkDescriptorSetLayoutCreateInfo dsLayoutInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &samplerBinding,
    };
    VK_CHECK(vkCreateDescriptorSetLayout(vk->device, &dsLayoutInfo, NULL, &vk->descriptorSetLayout));

    VkPipelineLayoutCreateInfo plInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &vk->descriptorSetLayout,
    };
    VK_CHECK(vkCreatePipelineLayout(vk->device, &plInfo, NULL, &vk->pipelineLayout));

    // Create shader modules.
    VkShaderModule vertModule = createShaderModule(vk->device, "vert.spv");
    VkShaderModule fragModule = createShaderModule(vk->device, "frag.spv");
    VkPipelineShaderStageCreateInfo shaderStages[2] = {
        {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VK_SHADER_STAGE_VERTEX_BIT,
            .module = vertModule,
            .pName = "main",
        },
        {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = fragModule,
            .pName = "main",
        }
    };

    // No vertex input (we use gl_VertexIndex in the shader).
    VkPipelineVertexInputStateCreateInfo vertexInput = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    };
    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN,
    };

    VkDynamicState dynStates[2] = { VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR };
    VkPipelineDynamicStateCreateInfo dynamicState = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2,
        .pDynamicStates = dynStates,
    };

    VkPipelineViewportStateCreateInfo viewportState = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .scissorCount = 1,
    };

    VkPipelineRasterizationStateCreateInfo rasterizer = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0f,
        .cullMode = VK_CULL_MODE_BACK_BIT,
        .frontFace = VK_FRONT_FACE_CLOCKWISE,
    };

    VkPipelineMultisampleStateCreateInfo multisampling = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
    };

    VkPipelineColorBlendAttachmentState colorBlend = {
        .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = VK_FALSE,
    };

    VkPipelineColorBlendStateCreateInfo colorBlending = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &colorBlend,
    };

    VkGraphicsPipelineCreateInfo pipelineInfo = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = shaderStages,
        .pVertexInputState = &vertexInput,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .pDynamicState = &dynamicState,
        .layout = vk->pipelineLayout,
        .renderPass = vk->renderPass,
        .subpass = 0,
    };
    VK_CHECK(vkCreateGraphicsPipelines(vk->device, VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &vk->pipeline));

    // Create sampler.
    VkSamplerCreateInfo samplerInfo = {
        .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = VK_FILTER_LINEAR,
        .minFilter = VK_FILTER_LINEAR,
        .addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    };
    VK_CHECK(vkCreateSampler(vk->device, &samplerInfo, NULL, &vk->textureSampler));

    // Create descriptor pool and allocate the descriptor set.
    VkDescriptorPoolSize poolSize = {
        .type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
    };
    VkDescriptorPoolCreateInfo dpInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &poolSize,
        .maxSets = 1,
    };
    VK_CHECK(vkCreateDescriptorPool(vk->device, &dpInfo, NULL, &vk->descriptorPool));
    VkDescriptorSetAllocateInfo dsAllocInfo = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = vk->descriptorPool,
        .descriptorSetCount = 1,
        .pSetLayouts = &vk->descriptorSetLayout,
    };
    VK_CHECK(vkAllocateDescriptorSets(vk->device, &dsAllocInfo, &vk->descriptorSet));
    // (We'll update the descriptor with the valid texture view after creating the texture.)
    
    vkDestroyShaderModule(vk->device, fragModule, NULL);
    vkDestroyShaderModule(vk->device, vertModule, NULL);
}

//
// 4. Swapchain Creation (using fixed‑size arrays)
//
void initSwapchain(VulkanState* vk) {
    VkSurfaceCapabilitiesKHR caps;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vk->physicalDevice, vk->surface, &caps);
    vk->swapchainExtent.width = vk->width;
    vk->swapchainExtent.height = vk->height;
    
    VkSwapchainCreateInfoKHR scInfo = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = vk->surface,
        .minImageCount = caps.minImageCount + 1,
        .imageFormat = vk->swapchainFormat,
        .imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        .imageExtent = vk->swapchainExtent,
        .imageArrayLayers = 1,
        .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .preTransform = caps.currentTransform,
        .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = VK_PRESENT_MODE_FIFO_KHR,
        .clipped = VK_TRUE,
    };
    VK_CHECK(vkCreateSwapchainKHR(vk->device, &scInfo, NULL, &vk->swapchain));

    uint32_t count = MAX_SWAPCHAIN_IMAGES;
    VkImage images[MAX_SWAPCHAIN_IMAGES];
    VK_CHECK(vkGetSwapchainImagesKHR(vk->device, vk->swapchain, &count, images));
    vk->swapchainImageCount = count;
    for (uint32_t i = 0; i < count; i++) {
        vk->swapchainImages[i] = images[i];
        VkImageViewCreateInfo viewInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = vk->swapchainImages[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = vk->swapchainFormat,
            .components = { VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY,
                            VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY },
            .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
        };
        VK_CHECK(vkCreateImageView(vk->device, &viewInfo, NULL, &vk->swapchainImageViews[i]));
        
        VkFramebufferCreateInfo fbInfo = {
            .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = vk->renderPass,
            .attachmentCount = 1,
            .pAttachments = &vk->swapchainImageViews[i],
            .width = vk->width,
            .height = vk->height,
            .layers = 1,
        };
        VK_CHECK(vkCreateFramebuffer(vk->device, &fbInfo, NULL, &vk->swapchainFramebuffers[i]));
    }
}

//
// 5. Texture and Persistent Staging Buffer
//
void initTexture(VulkanState* vk) {
    VkImageCreateInfo imgInfo = {
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
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
    };
    VK_CHECK(vkCreateImage(vk->device, &imgInfo, NULL, &vk->textureImage));
    
    VkMemoryRequirements memReq;
    vkGetImageMemoryRequirements(vk->device, vk->textureImage, &memReq);
    VkMemoryAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memReq.size,
        .memoryTypeIndex = findMemoryType(vk->physicalDevice, memReq.memoryTypeBits,
                          VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT),
    };
    VK_CHECK(vkAllocateMemory(vk->device, &allocInfo, NULL, &vk->textureMemory));
    VK_CHECK(vkBindImageMemory(vk->device, vk->textureImage, vk->textureMemory, 0));
    
    VkImageViewCreateInfo viewInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = vk->textureImage,
        .viewType = VK_IMAGE_VIEW_TYPE_2D,
        .format = VK_FORMAT_R8G8B8A8_UNORM,
        .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
    };
    VK_CHECK(vkCreateImageView(vk->device, &viewInfo, NULL, &vk->textureView));

    // Update descriptor set with the newly created texture view.
    VkDescriptorImageInfo diInfo = {
        .sampler = vk->textureSampler,
        .imageView = vk->textureView,
        .imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    };
    VkWriteDescriptorSet writeDS = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = vk->descriptorSet,
        .dstBinding = 0,
        .descriptorCount = 1,
        .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .pImageInfo = &diInfo,
    };
    vkUpdateDescriptorSets(vk->device, 1, &writeDS, 0, NULL);

    // Create a persistent staging buffer sized for MAX_WIDTH*MAX_HEIGHT*4.
    VkDeviceSize stagingSize = MAX_WIDTH * MAX_HEIGHT * 4;
    VkBufferCreateInfo bufInfo = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = stagingSize,
        .usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    };
    VK_CHECK(vkCreateBuffer(vk->device, &bufInfo, NULL, &vk->stagingBuffer));
    vkGetBufferMemoryRequirements(vk->device, vk->stagingBuffer, &memReq);
    allocInfo.allocationSize = memReq.size;
    allocInfo.memoryTypeIndex = findMemoryType(vk->physicalDevice, memReq.memoryTypeBits,
                                VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    VK_CHECK(vkAllocateMemory(vk->device, &allocInfo, NULL, &vk->stagingMemory));
    VK_CHECK(vkBindBufferMemory(vk->device, vk->stagingBuffer, vk->stagingMemory, 0));
    VK_CHECK(vkMapMemory(vk->device, vk->stagingMemory, 0, stagingSize, 0, &vk->stagingMapped));

    // Transition texture image from UNDEFINED to SHADER_READ_ONLY_OPTIMAL.
    VkCommandBufferAllocateInfo allocInfoCmd = {
         .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
         .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
         .commandPool = vk->commandPool,
         .commandBufferCount = 1,
    };
    VkCommandBuffer tempCmd;
    VK_CHECK(vkAllocateCommandBuffers(vk->device, &allocInfoCmd, &tempCmd));
    VkCommandBufferBeginInfo beginInfo = {
         .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
         .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    VK_CHECK(vkBeginCommandBuffer(tempCmd, &beginInfo));
    VkImageMemoryBarrier barrier = {
         .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
         .newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
         .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
         .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
         .image = vk->textureImage,
         .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
         .srcAccessMask = 0,
         .dstAccessMask = VK_ACCESS_SHADER_READ_BIT,
    };
    vkCmdPipelineBarrier(tempCmd,
         VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
         VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
         0, 0, NULL, 0, NULL, 1, &barrier);
    VK_CHECK(vkEndCommandBuffer(tempCmd));
    VkSubmitInfo submitInfo = {
         .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
         .commandBufferCount = 1,
         .pCommandBuffers = &tempCmd,
    };
    VK_CHECK(vkQueueSubmit(vk->graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE));
    VK_CHECK(vkQueueWaitIdle(vk->graphicsQueue));
    vkFreeCommandBuffers(vk->device, vk->commandPool, 1, &tempCmd);
}

//
// 6. Update Texture Each Frame
//    (Copy pixel data into the persistent staging buffer, then record a command buffer that:
//     - transitions the texture image from SHADER_READ_ONLY_OPTIMAL to TRANSFER_DST_OPTIMAL,
//     - copies the buffer to the image, and
//     - transitions back to SHADER_READ_ONLY_OPTIMAL.)
//
void updateTexture(VulkanState* vk) {
    size_t dataSize = vk->width * vk->height * 4;
    memcpy(vk->stagingMapped, vk->pixels, dataSize);
    
    VkCommandBufferBeginInfo beginInfo = {
         .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
         .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    VK_CHECK(vkBeginCommandBuffer(vk->commandBuffer, &beginInfo));
    
    VkImageMemoryBarrier barrier = {
         .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         .oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
         .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
         .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
         .image = vk->textureImage,
         .subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 },
         .srcAccessMask = VK_ACCESS_SHADER_READ_BIT,
         .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
    };
    vkCmdPipelineBarrier(vk->commandBuffer,
         VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
         VK_PIPELINE_STAGE_TRANSFER_BIT,
         0, 0, NULL, 0, NULL, 1, &barrier);
    
    VkBufferImageCopy region = {
         .bufferOffset = 0,
         .bufferRowLength = 0,
         .bufferImageHeight = 0,
         .imageSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 },
         .imageOffset = { 0, 0, 0 },
         .imageExtent = { vk->width, vk->height, 1 },
    };
    vkCmdCopyBufferToImage(vk->commandBuffer, vk->stagingBuffer, vk->textureImage,
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
    
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    vkCmdPipelineBarrier(vk->commandBuffer,
         VK_PIPELINE_STAGE_TRANSFER_BIT,
         VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
         0, 0, NULL, 0, NULL, 1, &barrier);
    
    VK_CHECK(vkEndCommandBuffer(vk->commandBuffer));
    
    // Submit the update command buffer without waiting on any semaphore.
    VkSubmitInfo submitInfo = {
         .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
         .commandBufferCount = 1,
         .pCommandBuffers = &vk->commandBuffer,
         .waitSemaphoreCount = 0,
         .signalSemaphoreCount = 0,
    };
    VK_CHECK(vkQueueSubmit(vk->graphicsQueue, 1, &submitInfo, vk->inFlightFence));
    VK_CHECK(vkQueueWaitIdle(vk->graphicsQueue));
}



//
// 8. Resize Handling: Recreate Swapchain and Texture
//
void recreateSwapchain(VulkanState* vk, uint32_t newWidth, uint32_t newHeight) {
    vkDeviceWaitIdle(vk->device);
    for (uint32_t i = 0; i < vk->swapchainImageCount; i++) {
        vkDestroyFramebuffer(vk->device, vk->swapchainFramebuffers[i], NULL);
        vkDestroyImageView(vk->device, vk->swapchainImageViews[i], NULL);
    }
    vkDestroySwapchainKHR(vk->device, vk->swapchain, NULL);
    vkDestroyImageView(vk->device, vk->textureView, NULL);
    vkDestroyImage(vk->device, vk->textureImage, NULL);
    vkFreeMemory(vk->device, vk->textureMemory, NULL);
    
    vk->width = newWidth;
    vk->height = newHeight;
    initSwapchain(vk);
    initTexture(vk);
}

//
// 7. Render Frame
//    Acquire a swapchain image, record a command buffer that clears and draws a full‑screen quad,
//    then submit the command buffer (waiting on the "image available" semaphore and signaling
//    "render finished") and present.
//    (Note: We use the same command buffer that updateTexture() used, but since we wait for idle
//     after updateTexture(), it is safe to re‑record it here.)
//
void renderFrame(VulkanState* vk) {
    // Wait for the previous frame to finish.
    VK_CHECK(vkWaitForFences(vk->device, 1, &vk->inFlightFence, VK_TRUE, UINT64_MAX));
    VK_CHECK(vkResetFences(vk->device, 1, &vk->inFlightFence));
    
    uint32_t imageIndex;
    VkResult result = vkAcquireNextImageKHR(vk->device, vk->swapchain, UINT64_MAX,
                                             vk->imageAvailable, VK_NULL_HANDLE, &imageIndex);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
        VK_CHECK(result);
    
    // Record command buffer.
    VK_CHECK(vkResetCommandBuffer(vk->commandBuffer, 0));
    VkCommandBufferBeginInfo beginInfo = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
    VK_CHECK(vkBeginCommandBuffer(vk->commandBuffer, &beginInfo));
    
    VkClearValue clearValue = { .color = { { 0.0f, 0.0f, 0.0f, 1.0f } } };
    VkRenderPassBeginInfo rpBegin = {
         .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
         .renderPass = vk->renderPass,
         .framebuffer = vk->swapchainFramebuffers[imageIndex],
         .renderArea = { { 0, 0 }, { vk->width, vk->height } },
         .clearValueCount = 1,
         .pClearValues = &clearValue,
    };
    vkCmdBeginRenderPass(vk->commandBuffer, &rpBegin, VK_SUBPASS_CONTENTS_INLINE);
    
    // Set dynamic viewport and scissor.
    VkViewport viewport = {
         .x = 0.0f, .y = 0.0f,
         .width = (float)vk->width, .height = (float)vk->height,
         .minDepth = 0.0f, .maxDepth = 1.0f,
    };
    vkCmdSetViewport(vk->commandBuffer, 0, 1, &viewport);
    VkRect2D scissor = {
         .offset = {0, 0},
         .extent = { vk->width, vk->height },
    };
    vkCmdSetScissor(vk->commandBuffer, 0, 1, &scissor);
    
    vkCmdBindPipeline(vk->commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, vk->pipeline);
    vkCmdBindDescriptorSets(vk->commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
                            vk->pipelineLayout, 0, 1, &vk->descriptorSet, 0, NULL);
    vkCmdDraw(vk->commandBuffer, 4, 1, 0, 0);
    
    vkCmdEndRenderPass(vk->commandBuffer);
    VK_CHECK(vkEndCommandBuffer(vk->commandBuffer));
    
    // Submit the render command buffer.
    VkSubmitInfo submitInfo = {
         .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
         .waitSemaphoreCount = 1,
         .pWaitSemaphores = (VkSemaphore[]){ vk->imageAvailable },
         .pWaitDstStageMask = (VkPipelineStageFlags[]){ VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT },
         .commandBufferCount = 1,
         .pCommandBuffers = &vk->commandBuffer,
         .signalSemaphoreCount = 1,
         .pSignalSemaphores = (VkSemaphore[]){ vk->renderFinished },
    };
    VK_CHECK(vkQueueSubmit(vk->graphicsQueue, 1, &submitInfo, vk->inFlightFence));
    
    VkPresentInfoKHR presentInfo = {
         .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
         .swapchainCount = 1,
         .pSwapchains = &vk->swapchain,
         .pImageIndices = &imageIndex,
         .waitSemaphoreCount = 1,
         .pWaitSemaphores = (VkSemaphore[]){ vk->renderFinished },
    };
    VkResult presResult = vkQueuePresentKHR(vk->graphicsQueue, &presentInfo);
    if (presResult == VK_ERROR_OUT_OF_DATE_KHR || presResult == VK_SUBOPTIMAL_KHR) {
         // The swapchain is no longer valid—recreate it using the current framebuffer size.
         int newWidth, newHeight;
         glfwGetFramebufferSize(vk->window, &newWidth, &newHeight);
         if (newWidth > 0 && newHeight > 0) {
             recreateSwapchain(vk, newWidth, newHeight);
         }
    } else {
         VK_CHECK(presResult);
    }
}

//
// 9. GLFW Callback for Resizing
//
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    if (width < MIN_WINDOW_WIDTH || height < MIN_WINDOW_HEIGHT)
        return;
    VulkanState* vk = (VulkanState*)glfwGetWindowUserPointer(window);
    recreateSwapchain(vk, width, height);
    printf("Resized to %d x %d\n", width, height);
}

//
// 10. Utility: Create Shader Module from SPIR-V File
//
VkShaderModule createShaderModule(VkDevice device, const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Failed to open shader file: %s\n", filename);
        exit(1);
    }
    fseek(file, 0, SEEK_END);
    long codeSize = ftell(file);
    rewind(file);
    char* code = (char*)malloc(codeSize);
    if (fread(code, 1, codeSize, file) != (size_t)codeSize) {
        fprintf(stderr, "Failed to read shader file: %s\n", filename);
        free(code);
        fclose(file);
        exit(1);
    }
    fclose(file);
    
    VkShaderModuleCreateInfo createInfo = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = codeSize,
        .pCode = (const uint32_t*)code,
    };
    VkShaderModule shaderModule;
    VK_CHECK(vkCreateShaderModule(device, &createInfo, NULL, &shaderModule));
    free(code);
    return shaderModule;
}

//
// 11. Utility: Find Suitable Memory Type
//
uint32_t findMemoryType(VkPhysicalDevice physicalDevice, uint32_t typeFilter, VkMemoryPropertyFlags properties) {
    VkPhysicalDeviceMemoryProperties memProps;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProps);
    for (uint32_t i = 0; i < memProps.memoryTypeCount; i++) {
        if ((typeFilter & (1 << i)) && ((memProps.memoryTypes[i].propertyFlags & properties) == properties))
            return i;
    }
    fprintf(stderr, "Failed to find suitable memory type!\n");
    exit(1);
}

//
// 12. Consolidated Initialization: Create Instance/Device, Query Format,
//     Create Pipeline, Swapchain, and Texture, and update the descriptor set.
//
void initVulkanState(VulkanState* vk, GLFWwindow* window, uint32_t width, uint32_t height) {
    vk->window = window;
    vk->width = width;
    vk->height = height;
    initInstanceAndDevice(vk);
    querySwapchainFormat(vk);
    initPipeline(vk);
    initSwapchain(vk);
    initTexture(vk);
}

//
// 13. Main: Create Window, Allocate Pixel Buffer, Initialize Vulkan, and Run Render Loop
//
int main() {
    VulkanState vkState = {0};
    uint32_t initWidth = 640, initHeight = 480;
    
    if (!glfwInit()) {
        fprintf(stderr, "GLFW initialization failed\n");
        return -1;
    }
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);
    
    GLFWwindow* window = glfwCreateWindow(initWidth, initHeight, "Vulkan Framebuffer Demo", NULL, NULL);
    if (!window) {
        fprintf(stderr, "Failed to create GLFW window\n");
        glfwTerminate();
        return -1;
    }
    glfwSetWindowSizeLimits(window, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, GLFW_DONT_CARE, GLFW_DONT_CARE);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    glfwSetWindowUserPointer(window, &vkState);
    
    // Allocate the pixel buffer on the heap.
    vkState.pixels = malloc(MAX_WIDTH * MAX_HEIGHT * 4);
    if (!vkState.pixels) {
        fprintf(stderr, "Failed to allocate pixel buffer\n");
        return -1;
    }
    
    initVulkanState(&vkState, window, initWidth, initHeight);
    
    // Main loop: update pixel data with random colors, update texture, render frame.
    while (!glfwWindowShouldClose(window)) {
        for (uint32_t i = 0; i < vkState.width * vkState.height; i++) {
            int r = rand();
            vkState.pixels[i * 4 + 0] = r % 256;
            vkState.pixels[i * 4 + 1] = (r * r) % 256;
            vkState.pixels[i * 4 + 2] = ((-r) & 0xFF);
            vkState.pixels[i * 4 + 3] = 255;
        }
        
        updateTexture(&vkState);
        renderFrame(&vkState);
        glfwPollEvents();
    }
    
    vkDeviceWaitIdle(vkState.device);
    
    // Cleanup
    for (uint32_t i = 0; i < vkState.swapchainImageCount; i++) {
        vkDestroyFramebuffer(vkState.device, vkState.swapchainFramebuffers[i], NULL);
        vkDestroyImageView(vkState.device, vkState.swapchainImageViews[i], NULL);
    }
    vkDestroySwapchainKHR(vkState.device, vkState.swapchain, NULL);
    vkDestroySampler(vkState.device, vkState.textureSampler, NULL);
    vkDestroyImageView(vkState.device, vkState.textureView, NULL);
    vkDestroyImage(vkState.device, vkState.textureImage, NULL);
    vkFreeMemory(vkState.device, vkState.textureMemory, NULL);
    vkDestroyDescriptorPool(vkState.device, vkState.descriptorPool, NULL);
    vkDestroyDescriptorSetLayout(vkState.device, vkState.descriptorSetLayout, NULL);
    vkDestroyPipeline(vkState.device, vkState.pipeline, NULL);
    vkDestroyPipelineLayout(vkState.device, vkState.pipelineLayout, NULL);
    vkDestroyRenderPass(vkState.device, vkState.renderPass, NULL);
    vkDestroyBuffer(vkState.device, vkState.stagingBuffer, NULL);
    vkFreeMemory(vkState.device, vkState.stagingMemory, NULL);
    vkDestroyFence(vkState.device, vkState.inFlightFence, NULL);
    vkDestroySemaphore(vkState.device, vkState.renderFinished, NULL);
    vkDestroySemaphore(vkState.device, vkState.imageAvailable, NULL);
    vkDestroyCommandPool(vkState.device, vkState.commandPool, NULL);
    vkDestroyDevice(vkState.device, NULL);
    vkDestroySurfaceKHR(vkState.instance, vkState.surface, NULL);
    vkDestroyInstance(vkState.instance, NULL);
    free(vkState.pixels);
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
