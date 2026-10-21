
cmake_minimum_required(VERSION 3.22.1)

project(otakudub_native LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build specifically for Android ARM64.
if(NOT ANDROID)
    message(FATAL_ERROR "OtakuDub native engine requires Android.")
endif()

if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
    message(FATAL_ERROR "Only arm64-v8a is supported.")
endif()

# llama.cpp will be added as a native dependency.
set(LLAMA_CPP_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp"
)

if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "Missing llama.cpp source directory: ${LLAMA_CPP_DIR}"
    )
endif()

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)

add_subdirectory(
    "${LLAMA_CPP_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/llama-build"
)

add_library(
    otakudub_native
    SHARED
    otakudub_jni.cpp
)

find_library(
    ANDROID_LOG_LIB
    log
)

target_link_libraries(
    otakudub_native
    PRIVATE
    llama
    ${ANDROID_LOG_LIB}
)
