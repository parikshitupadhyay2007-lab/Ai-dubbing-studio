
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

set(LLAMA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp")
set(WHISPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/whisper.cpp")
set(ESPEAK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/espeak-ng")

foreach(DEPENDENCY_DIR IN ITEMS
    LLAMA_DIR
    WHISPER_DIR
    ESPEAK_DIR
)
    if(NOT EXISTS "${${DEPENDENCY_DIR}}/CMakeLists.txt")
        message(FATAL_ERROR
            "Missing native dependency: ${${DEPENDENCY_DIR}}"
        )
    endif()
endforeach()

# Shared native build configuration.

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)

# OtakuMind / llama.cpp.

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)

add_subdirectory(
    "${LLAMA_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/llama-build"
)

if(NOT TARGET ggml)
    message(FATAL_ERROR "Missing GGML target")
endif()

# Whisper transcription.

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_FFMPEG OFF CACHE BOOL "" FORCE)
set(WHISPER_OPENVINO OFF CACHE BOOL "" FORCE)

set(WHISPER_USE_SYSTEM_GGML ON CACHE BOOL "" FORCE)

add_subdirectory(
    "${WHISPER_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/whisper-build"
)

# eSpeak NG phonemization.
#
# Language data is compiled separately on the Linux host.
# Do not build eSpeak's host-data target as part of the
# Android application target.

set(USE_LIBSONIC OFF CACHE BOOL "" FORCE)
set(USE_LIBPCAUDIO OFF CACHE BOOL "" FORCE)
set(USE_MBROLA OFF CACHE BOOL "" FORCE)
set(USE_SPEECHPLAYER OFF CACHE BOOL "" FORCE)
set(USE_ASYNC OFF CACHE BOOL "" FORCE)
set(USE_KLATT OFF CACHE BOOL "" FORCE)

add_subdirectory(
    "${ESPEAK_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/espeak-build"
    EXCLUDE_FROM_ALL
)

if(NOT TARGET espeak-ng OR NOT TARGET ucd)
    message(FATAL_ERROR "Missing eSpeak NG or Unicode library target")
endif()

# The upstream data target is ALL and executes espeak-ng-bin.
# That executable is cross-compiled for ARM64 and cannot run on the build host.
# Language data is already compiled by prepare-espeak-data.sh on Linux.
set_property(TARGET data PROPERTY EXCLUDE_FROM_ALL TRUE)
set_property(TARGET espeak-ng-bin PROPERTY EXCLUDE_FROM_ALL TRUE)

# eSpeak exports src/include/compat as a PUBLIC include directory.
# Its wctype.h shadows the Android NDK standard header in C++ consumers.
# Keep eSpeak's own PRIVATE compilation settings, but expose only the
# public API headers to our JNI target.
set_target_properties(espeak-ng PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ESPEAK_DIR}/src/include"
)

find_library(ANDROID_LOG_LIB log)

# Existing OtakuDub native engine.

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

# Separate JNI library loaded by OfflinePhonemizer.kt.

add_library(
    otakudub_phonemizer
    SHARED
    otakudub_phonemizer.cpp
)

target_include_directories(
    otakudub_phonemizer
    PRIVATE
    "${ESPEAK_DIR}/src/include"
)

target_link_libraries(
    otakudub_phonemizer
    PRIVATE
    $<TARGET_FILE:espeak-ng>
    $<TARGET_FILE:ucd>
    ${ANDROID_LOG_LIB}
)

# Link the built archive directly to avoid inheriting eSpeak's compile usage requirements.
add_dependencies(otakudub_phonemizer espeak-ng ucd)

# eSpeak also adds compat through directory-scoped include settings.
# Explicitly restrict this C++ JNI translation unit to the public API
# include directory; compat/wctype.h must not shadow the NDK wctype.h.
set_property(TARGET otakudub_phonemizer PROPERTY INCLUDE_DIRECTORIES
    "${ESPEAK_DIR}/src/include"
)
set_property(TARGET otakudub_phonemizer PROPERTY INTERFACE_INCLUDE_DIRECTORIES "")
get_target_property(PHONEMIZER_INCLUDES otakudub_phonemizer INCLUDE_DIRECTORIES)
message(STATUS "Phonemizer direct includes: ${PHONEMIZER_INCLUDES}")

