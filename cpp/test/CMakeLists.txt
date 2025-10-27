# Test suite for PhiloteJulia

# Create test executable
add_executable(philote_julia_tests
    test_main.cpp
    test_julia_runtime.cpp
    test_julia_marshal.cpp
    test_julia_explicit.cpp
)

target_link_libraries(philote_julia_tests
    PhiloteJulia
    GTest::gtest
    GTest::gtest_main
)

target_include_directories(philote_julia_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    ${JULIA_INCLUDE_DIRS}
)

# Discover tests for CTest
gtest_discover_tests(philote_julia_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
)

# Copy test files to build directory
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../examples/paraboloid.jl
    ${CMAKE_CURRENT_BINARY_DIR}/test_paraboloid.jl
    COPYONLY
)
