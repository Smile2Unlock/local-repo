cmake_minimum_required(VERSION 3.14)
project(eui_neo_core VERSION 0.3.6)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# 禁用 HTTPS 证书验证，解决国内或代理环境下下载 Github 源码失败的问题
set(CMAKE_TLS_VERIFY OFF)

# 禁用 GLFW 测试、示例和文档以加快构建速度
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)

include(FetchContent)

# GLFW
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    glfw
    URL https://github.com/glfw/glfw/archive/refs/tags/3.4.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    TIMEOUT 30
    TLS_VERIFY OFF
)
FetchContent_MakeAvailable(glfw)

# GLAD 使用静态库
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    glad
    URL https://github.com/libigl/libigl-glad/archive/refs/heads/master.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    TIMEOUT 30
    TLS_VERIFY OFF
)
FetchContent_MakeAvailable(glad)

find_package(OpenGL REQUIRED)
find_package(CURL QUIET)

# 库目标：只编译 core 下的 4 个 cpp 文件
add_library(eui_neo_core STATIC
    core/image.cpp
    core/network.cpp
    core/platform.cpp
    core/text.cpp
)

target_include_directories(eui_neo_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(eui_neo_core PUBLIC glfw glad OpenGL::GL)

if(CURL_FOUND)
    target_link_libraries(eui_neo_core PUBLIC CURL::libcurl)
    target_compile_definitions(eui_neo_core PUBLIC EUI_HAS_CURL=1)
elseif(WIN32)
    target_link_libraries(eui_neo_core PUBLIC urlmon)
endif()

if(WIN32)
    target_compile_definitions(eui_neo_core PUBLIC GLFW_INCLUDE_NONE=1)
endif()
