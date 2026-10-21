
cmake_minimum_required(VERSION 3.22.1)

project(otakudub_native LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT ANDROID)
    message(FATAL_ERROR "Android is required")
endif()

if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
    message(FATAL_ERROR "ARM64 is required")
endif()

set(LLAMA_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp"
)

set(WHISPER_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/whisper.cpp"
)

foreach(SOURCE_DIR IN ITEMS LLAMA_DIR WHISPER_DIR)
    if(NOT EXISTS "${${SOURCE_DIR}}/CMakeLists.txt")
        message(FATAL_ERROR
            "Missing native dependency: ${${SOURCE_DIR}}"
        )
    endif()
endforeach()

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_FFMPEG OFF CACHE BOOL "" FORCE)
set(WHISPER_OPENVINO OFF CACHE BOOL "" FORCE)

set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)

# Build llama.cpp and whisper.cpp in isolated CMake scopes.
# Their GGML dependency versions must not share target names.

add_subdirectory(
    "${LLAMA_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/llama-build"
)

# Reuse GGML only when Whisper explicitly supports
# the version supplied by the pinned llama.cpp revision.
# Otherwise, a separate native-library build is required.

if(NOT TARGET ggml)
    message(FATAL_ERROR
        "Expected GGML target is missing from llama.cpp"
    )
endif()

set(WHISPER_USE_SYSTEM_GGML ON CACHE BOOL "" FORCE)

add_subdirectory(
    "${WHISPER_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/whisper-build"
)

find_library(ANDROID_LOG_LIB log)

add_library(
    otakudub_native
    SHARED
    otakudub_jni.cpp
    otakudub_whisper.cpp
)

target_include_directories(
    otakudub_native
    PRIVATE
    "${LLAMA_DIR}/include"
    "${WHISPER_DIR}/include"
)

target_link_libraries(
    otakudub_native
    PRIVATE
    llama
    whisper
    ${ANDROID_LOG_LIB}
)
