cmake_minimum_required(VERSION 3.22.1)
project(talkies_whisper_android LANGUAGES C CXX)

set(LLAMA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/llama.cpp")
set(WHISPER_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/whisper.cpp")

set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_UI OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${LLAMA_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/llama.cpp" EXCLUDE_FROM_ALL)

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_CURL OFF CACHE BOOL "" FORCE)

add_subdirectory("${WHISPER_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/whisper.cpp" EXCLUDE_FROM_ALL)

add_library(talkies_whisper SHARED whisper_jni.cpp s1_mini_jni.cpp)
target_include_directories(talkies_whisper PRIVATE
    "${WHISPER_ROOT}/include"
    "${LLAMA_ROOT}/include"
)
target_link_libraries(talkies_whisper PRIVATE whisper llama android log)

# ---------------------------------------------------------------------------
# Phonon-2 through CrispASR's Parakeet TDT backend -> libtalkies_phonon.so
#
# CrispASR pins its own ggml fork, defines `ggml` and `whisper` targets that collide with the
# llama.cpp and whisper.cpp targets above, and resolves paths from CMAKE_SOURCE_DIR, so it is
# configured as its own top-level project. Only the `parakeet` target and its dependencies are
# compiled; the other CrispASR backends are configured but never built or linked. Every
# configure-time download CrispASR or ggml offers is forced off: the build stays offline and the
# runtime has no network path.
# ---------------------------------------------------------------------------
include(ExternalProject)

set(CRISPASR_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/CrispASR")
if(NOT EXISTS "${CRISPASR_ROOT}/src/parakeet.h" OR NOT EXISTS "${CRISPASR_ROOT}/ggml/CMakeLists.txt")
    message(FATAL_ERROR
        "CrispASR sources are missing at '${CRISPASR_ROOT}'. From the repository root run:\n"
        "    git submodule update --init --recursive")
endif()

set(CRISPASR_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/crispasr")
set(CRISPASR_DISABLED_OPTIONS
    CRISPASR_BUILD_TESTS CRISPASR_BUILD_EXAMPLES CRISPASR_BUILD_SERVER
    CRISPASR_CURL CRISPASR_SDL2 CRISPASR_FFMPEG
    CRISPASR_OPUS CRISPASR_OPUS_FETCH CRISPASR_AMR CRISPASR_AMR_FETCH
    CRISPASR_C2PA_FETCH CRISPASR_MEDIA_NDK CRISPASR_MEL_BLAS
    CRISPASR_ALL_WARNINGS CRISPASR_FATAL_WARNINGS CRISPASR_COREML CRISPASR_OPENVINO
    GGML_NATIVE GGML_OPENMP GGML_OPENMP_FETCH GGML_BACKEND_DL GGML_CPU_KLEIDIAI GGML_LLAMAFILE
    GGML_CUDA GGML_METAL GGML_OPENCL GGML_VULKAN GGML_BLAS GGML_RPC
    GGML_BUILD_TESTS GGML_BUILD_EXAMPLES GGML_CCACHE
    BUILD_SHARED_LIBS
)
set(CRISPASR_CMAKE_ARGS
    "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
    "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
    "-DANDROID_ABI=${ANDROID_ABI}"
    "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DCRISPASR_NO_C2PA_NATIVE=ON"
    "-DCMAKE_DISABLE_FIND_PACKAGE_OpenMP=ON"
    "-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON"
    "-DCMAKE_DISABLE_FIND_PACKAGE_BLAS=ON"
    "-DCMAKE_DISABLE_FIND_PACKAGE_Git=ON"
    "-Wno-dev"
)
foreach(option IN LISTS CRISPASR_DISABLED_OPTIONS)
    list(APPEND CRISPASR_CMAKE_ARGS "-D${option}=OFF")
endforeach()
# Match the STL and page-size settings AGP gives the main project.
foreach(setting ANDROID_STL ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES)
    if(DEFINED ${setting} AND NOT "${${setting}}" STREQUAL "")
        list(APPEND CRISPASR_CMAKE_ARGS "-D${setting}=${${setting}}")
    endif()
endforeach()

set(CRISPASR_ARCHIVES
    "${CRISPASR_BINARY_DIR}/src/libparakeet.a"
    "${CRISPASR_BINARY_DIR}/src/libcrispasr-core.a"
    "${CRISPASR_BINARY_DIR}/ggml/src/libggml.a"
    "${CRISPASR_BINARY_DIR}/ggml/src/libggml-cpu.a"
    "${CRISPASR_BINARY_DIR}/ggml/src/libggml-base.a"
)
ExternalProject_Add(crispasr_parakeet
    SOURCE_DIR "${CRISPASR_ROOT}"
    BINARY_DIR "${CRISPASR_BINARY_DIR}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${CRISPASR_CMAKE_ARGS}
    BUILD_COMMAND "${CMAKE_COMMAND}" --build "${CRISPASR_BINARY_DIR}" --target parakeet
    BUILD_BYPRODUCTS ${CRISPASR_ARCHIVES}
    INSTALL_COMMAND ""
    # Rebuild-check the pinned sources on every build; the inner Ninja build is incremental.
    BUILD_ALWAYS ON
    UPDATE_COMMAND ""
    DOWNLOAD_COMMAND ""
)

add_library(talkies_phonon SHARED phonon_jni.cpp)
add_dependencies(talkies_phonon crispasr_parakeet)
target_include_directories(talkies_phonon PRIVATE
    "${CRISPASR_ROOT}/src"
    "${CRISPASR_ROOT}/include"
    "${CRISPASR_ROOT}/ggml/include"
)
target_link_libraries(talkies_phonon PRIVATE
    "-Wl,--start-group" ${CRISPASR_ARCHIVES} "-Wl,--end-group"
    log dl m
)
set_target_properties(talkies_phonon PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/phonon_exports.map;${CRISPASR_ARCHIVES}"
)
# Export only the JNI entry points so CrispASR's ggml fork and whisper_* symbols cannot interpose
# on, or be interposed by, the whisper.cpp and llama.cpp copies in libtalkies_whisper.so.
target_link_options(talkies_phonon PRIVATE
    "-Wl,--exclude-libs,ALL"
    "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/phonon_exports.map"
    "-Wl,--gc-sections"
)
