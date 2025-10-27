/**
 * @file test_main.cpp
 * @brief Main test entry point for PhiloteJulia tests
 */

#include <gtest/gtest.h>
#include "julia_runtime.h"

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);

    // Initialize Julia runtime for all tests
    philote::JuliaRuntime::Instance().Initialize();

    int result = RUN_ALL_TESTS();

    // Cleanup Julia runtime
    philote::JuliaRuntime::Instance().Shutdown();

    return result;
}
