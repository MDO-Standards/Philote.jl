/**
 * @file test_julia_runtime.cpp
 * @brief Tests for JuliaRuntime class
 */

#include <gtest/gtest.h>
#include "julia_runtime.h"
#include <julia.h>

using namespace philote;

class JuliaRuntimeTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Runtime is already initialized in main
        runtime_ = &JuliaRuntime::Instance();
    }

    JuliaRuntime* runtime_;
};

TEST_F(JuliaRuntimeTest, Singleton) {
    // Verify singleton pattern
    JuliaRuntime& instance1 = JuliaRuntime::Instance();
    JuliaRuntime& instance2 = JuliaRuntime::Instance();

    EXPECT_EQ(&instance1, &instance2);
}

TEST_F(JuliaRuntimeTest, IsInitialized) {
    // Should be initialized from main
    EXPECT_TRUE(runtime_->IsInitialized());
}

TEST_F(JuliaRuntimeTest, EvalSimpleExpression) {
    // Evaluate a simple Julia expression
    jl_value_t* result = runtime_->Eval("2 + 2");

    ASSERT_NE(result, nullptr);
    EXPECT_TRUE(jl_is_int64(result));
    EXPECT_EQ(jl_unbox_int64(result), 4);
}

TEST_F(JuliaRuntimeTest, EvalStringExpression) {
    // Evaluate string concatenation
    jl_value_t* result = runtime_->Eval("\"Hello\" * \" \" * \"World\"");

    ASSERT_NE(result, nullptr);
    EXPECT_TRUE(jl_is_string(result));
    std::string str(jl_string_ptr(result));
    EXPECT_EQ(str, "Hello World");
}

TEST_F(JuliaRuntimeTest, EvalArrayCreation) {
    // Create an array
    jl_value_t* result = runtime_->Eval("[1.0, 2.0, 3.0]");

    ASSERT_NE(result, nullptr);
    EXPECT_TRUE(jl_is_array(result));

    jl_array_t* arr = (jl_array_t*)result;
    EXPECT_EQ(jl_array_len(arr), 3);

    double* data = (double*)jl_array_data(arr);
    EXPECT_DOUBLE_EQ(data[0], 1.0);
    EXPECT_DOUBLE_EQ(data[1], 2.0);
    EXPECT_DOUBLE_EQ(data[2], 3.0);
}

TEST_F(JuliaRuntimeTest, InvalidExpressionThrows) {
    // Invalid syntax should throw
    EXPECT_THROW(
        runtime_->Eval("this is not valid julia"),
        JuliaException
    );
}

TEST_F(JuliaRuntimeTest, GetFunctionFromBase) {
    // Get a function from Base module
    jl_function_t* sqrt_fn = runtime_->GetFunction(jl_base_module, "sqrt");

    ASSERT_NE(sqrt_fn, nullptr);
    EXPECT_TRUE(jl_is_function((jl_value_t*)sqrt_fn));

    // Test calling the function
    jl_value_t* arg = jl_box_float64(16.0);
    jl_value_t* result = jl_call1(sqrt_fn, arg);

    runtime_->CheckException();
    EXPECT_TRUE(jl_is_float64(result));
    EXPECT_DOUBLE_EQ(jl_unbox_float64(result), 4.0);
}

TEST_F(JuliaRuntimeTest, GetFunctionFromMain) {
    // Define a function in Main and retrieve it
    runtime_->Eval("test_double(x) = 2 * x");

    jl_function_t* fn = runtime_->GetFunction("test_double");
    ASSERT_NE(fn, nullptr);

    // Call the function
    jl_value_t* arg = jl_box_int64(21);
    jl_value_t* result = jl_call1(fn, arg);

    runtime_->CheckException();
    EXPECT_TRUE(jl_is_int64(result));
    EXPECT_EQ(jl_unbox_int64(result), 42);
}

TEST_F(JuliaRuntimeTest, GetNonExistentFunctionThrows) {
    EXPECT_THROW(
        runtime_->GetFunction(jl_base_module, "this_function_does_not_exist"),
        JuliaException
    );
}

TEST_F(JuliaRuntimeTest, LoadPhiloteModule) {
    // Load the Philote module from the source
    std::string philote_path = "../src/Philote.jl";

    EXPECT_NO_THROW({
        runtime_->Eval("push!(LOAD_PATH, \"../\")");
        runtime_->Eval("using Philote");
    });

    // Verify we can get Philote module
    jl_value_t* philote_module = runtime_->Eval("Philote");
    ASSERT_NE(philote_module, nullptr);
    EXPECT_TRUE(jl_is_module(philote_module));
}

TEST_F(JuliaRuntimeTest, ExceptionHandling) {
    // Cause an error
    try {
        runtime_->Eval("error(\"Test error message\")");
        FAIL() << "Should have thrown JuliaException";
    } catch (const JuliaException& e) {
        std::string msg = e.what();
        EXPECT_TRUE(msg.find("Test error message") != std::string::npos);
    }

    // After exception, runtime should still work
    jl_value_t* result = runtime_->Eval("1 + 1");
    EXPECT_EQ(jl_unbox_int64(result), 2);
}

TEST_F(JuliaRuntimeTest, GCRootManagement) {
    // Create a Julia array
    jl_value_t* arr = runtime_->Eval("[1.0, 2.0, 3.0]");
    ASSERT_NE(arr, nullptr);

    // Add to GC roots
    EXPECT_NO_THROW(runtime_->AddGCRoot(arr));

    // Force garbage collection
    jl_gc_collect(JL_GC_FULL);

    // Array should still be valid
    EXPECT_TRUE(jl_is_array(arr));
    EXPECT_EQ(jl_array_len((jl_array_t*)arr), 3);

    // Remove from GC roots
    EXPECT_NO_THROW(runtime_->RemoveGCRoot(arr));
}

TEST_F(JuliaRuntimeTest, MultipleGCRoots) {
    jl_value_t* val1 = runtime_->Eval("\"string1\"");
    jl_value_t* val2 = runtime_->Eval("\"string2\"");
    jl_value_t* val3 = runtime_->Eval("[1, 2, 3]");

    runtime_->AddGCRoot(val1);
    runtime_->AddGCRoot(val2);
    runtime_->AddGCRoot(val3);

    jl_gc_collect(JL_GC_FULL);

    EXPECT_TRUE(jl_is_string(val1));
    EXPECT_TRUE(jl_is_string(val2));
    EXPECT_TRUE(jl_is_array(val3));

    runtime_->RemoveGCRoot(val1);
    runtime_->RemoveGCRoot(val2);
    runtime_->RemoveGCRoot(val3);
}

TEST_F(JuliaRuntimeTest, CheckExceptionWhenNone) {
    // Should not throw when no exception
    EXPECT_NO_THROW(runtime_->CheckException());
    EXPECT_FALSE(runtime_->HasException());
}

TEST_F(JuliaRuntimeTest, HasExceptionAfterError) {
    try {
        runtime_->Eval("error(\"test\")");
    } catch (...) {
        // Exception was thrown and cleared
    }

    // Exception should have been cleared
    EXPECT_FALSE(runtime_->HasException());
}
