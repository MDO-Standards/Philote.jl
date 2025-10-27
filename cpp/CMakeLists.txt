cmake_minimum_required(VERSION 3.23)

project(PhiloteJulia VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options
option(BUILD_EXAMPLES "Build example servers" ON)
option(BUILD_TESTS "Build tests" OFF)

# ============================================================================
# Find Dependencies
# ============================================================================

# Find Julia
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package(Julia REQUIRED)

message(STATUS "Julia executable: ${JULIA_EXECUTABLE}")
message(STATUS "Julia include dirs: ${JULIA_INCLUDE_DIRS}")
message(STATUS "Julia library: ${JULIA_LIBRARY}")

# Find Philote-Cpp
# Assuming Philote-Cpp is in a sibling directory
set(PHILOTE_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Philote-Cpp"
    CACHE PATH "Path to Philote-Cpp directory")

if(NOT EXISTS "${PHILOTE_CPP_DIR}")
    message(FATAL_ERROR
        "Philote-Cpp not found at ${PHILOTE_CPP_DIR}. "
        "Please set PHILOTE_CPP_DIR to the correct path.")
endif()

# Add Philote-Cpp as a subdirectory or find it
# For now, we'll assume Philote-Cpp is already built and installed
find_package(PhiloteCpp REQUIRED
    PATHS "${PHILOTE_CPP_DIR}/build"
    NO_DEFAULT_PATH)

# Find gRPC and Protobuf (same as Philote-Cpp uses)
find_package(Protobuf CONFIG REQUIRED)
find_package(gRPC CONFIG REQUIRED)

# Find yaml-cpp for configuration files
find_package(yaml-cpp REQUIRED)

# ============================================================================
# PhiloteJulia Library
# ============================================================================

add_library(PhiloteJulia STATIC
    src/julia_runtime.cpp
    src/julia_marshal.cpp
    src/julia_explicit.cpp
    src/julia_implicit.cpp
    src/config.cpp
)

target_include_directories(PhiloteJulia PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
    ${JULIA_INCLUDE_DIRS}
)

target_link_libraries(PhiloteJulia PUBLIC
    PhiloteCpp
    ${JULIA_LIBRARY}
    protobuf::libprotobuf
    gRPC::grpc++
    yaml-cpp
)

# ============================================================================
# Examples
# ============================================================================

if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

# ============================================================================
# Tests
# ============================================================================

if(BUILD_TESTS)
    enable_testing()
    find_package(GTest REQUIRED)
    include(GoogleTest)
    add_subdirectory(test)
endif()

# ============================================================================
# Installation
# ============================================================================

install(TARGETS PhiloteJulia
    EXPORT PhiloteJuliaConfig
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(DIRECTORY include/
    DESTINATION include
)

install(EXPORT PhiloteJuliaConfig
    DESTINATION lib/cmake/PhiloteJulia
    NAMESPACE PhiloteJulia::
)
