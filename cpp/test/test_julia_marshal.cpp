/**
 * @file test_julia_marshal.cpp
 * @brief Tests for JuliaMarshal data conversion utilities
 */

#include <gtest/gtest.h>
#include "julia_marshal.h"
#include "julia_runtime.h"
#include <philote/variable.h>
#include <julia.h>
#include <cmath>

using namespace philote;

class JuliaMarshalTest : public ::testing::Test {
protected:
    void SetUp() override {
        runtime_ = &JuliaRuntime::Instance();
    }

    JuliaRuntime* runtime_;
};

// ============================================================================
// Variable → Julia Array conversions
// ============================================================================

TEST_F(JuliaMarshalTest, ToJuliaArray_Scalar) {
    // Create a scalar variable
    Variable var(kInput, {1});
    var(0) = 42.0;

    // Convert to Julia array
    jl_array_t* arr = JuliaMarshal::ToJuliaArray(var);

    ASSERT_NE(arr, nullptr);
    EXPECT_TRUE(jl_is_array((jl_value_t*)arr));
    EXPECT_EQ(jl_array_ndims(arr), 1);
    EXPECT_EQ(jl_array_len(arr), 1);

    double* data = (double*)jl_array_data(arr);
    EXPECT_DOUBLE_EQ(data[0], 42.0);
}

TEST_F(JuliaMarshalTest, ToJuliaArray_Vector) {
    // Create a vector variable
    Variable var(kInput, {5});
    for (size_t i = 0; i < 5; i++) {
        var(i) = i * 1.5;
    }

    // Convert to Julia array
    jl_array_t* arr = JuliaMarshal::ToJuliaArray(var);

    ASSERT_NE(arr, nullptr);
    EXPECT_EQ(jl_array_ndims(arr), 1);
    EXPECT_EQ(jl_array_len(arr), 5);

    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < 5; i++) {
        EXPECT_DOUBLE_EQ(data[i], i * 1.5);
    }
}

TEST_F(JuliaMarshalTest, ToJuliaArray_Matrix) {
    // Create a 2x3 matrix variable
    Variable var(kInput, {2, 3});
    for (size_t i = 0; i < 6; i++) {
        var(i) = i + 10.0;
    }

    // Convert to Julia array
    jl_array_t* arr = JuliaMarshal::ToJuliaArray(var);

    ASSERT_NE(arr, nullptr);
    EXPECT_EQ(jl_array_ndims(arr), 2);
    EXPECT_EQ(jl_array_dim(arr, 0), 2);
    EXPECT_EQ(jl_array_dim(arr, 1), 3);
    EXPECT_EQ(jl_array_len(arr), 6);

    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < 6; i++) {
        EXPECT_DOUBLE_EQ(data[i], i + 10.0);
    }
}

TEST_F(JuliaMarshalTest, ToJuliaArray_3DTensor) {
    // Create a 2x3x4 tensor
    Variable var(kInput, {2, 3, 4});
    for (size_t i = 0; i < 24; i++) {
        var(i) = sqrt(i + 1.0);
    }

    // Convert to Julia array
    jl_array_t* arr = JuliaMarshal::ToJuliaArray(var);

    ASSERT_NE(arr, nullptr);
    EXPECT_EQ(jl_array_ndims(arr), 3);
    EXPECT_EQ(jl_array_dim(arr, 0), 2);
    EXPECT_EQ(jl_array_dim(arr, 1), 3);
    EXPECT_EQ(jl_array_dim(arr, 2), 4);

    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < 24; i++) {
        EXPECT_DOUBLE_EQ(data[i], sqrt(i + 1.0));
    }
}

// ============================================================================
// Julia Array → Variable conversions
// ============================================================================

TEST_F(JuliaMarshalTest, FromJuliaArray_Scalar) {
    // Create Julia array
    jl_value_t* arr_val = runtime_->Eval("[99.5]");
    jl_array_t* arr = (jl_array_t*)arr_val;

    // Convert to Variable
    Variable var(kInput, {1});
    JuliaMarshal::FromJuliaArray(arr, var);

    EXPECT_DOUBLE_EQ(var(0), 99.5);
}

TEST_F(JuliaMarshalTest, FromJuliaArray_Vector) {
    // Create Julia array
    jl_value_t* arr_val = runtime_->Eval("[1.0, 2.0, 3.0, 4.0]");
    jl_array_t* arr = (jl_array_t*)arr_val;

    // Convert to Variable
    Variable var(kInput, {4});
    JuliaMarshal::FromJuliaArray(arr, var);

    EXPECT_DOUBLE_EQ(var(0), 1.0);
    EXPECT_DOUBLE_EQ(var(1), 2.0);
    EXPECT_DOUBLE_EQ(var(2), 3.0);
    EXPECT_DOUBLE_EQ(var(3), 4.0);
}

TEST_F(JuliaMarshalTest, FromJuliaArray_Matrix) {
    // Create Julia 2x3 matrix
    jl_value_t* arr_val = runtime_->Eval("reshape([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 2, 3)");
    jl_array_t* arr = (jl_array_t*)arr_val;

    // Convert to Variable (C++ stores flattened, column-major like Julia)
    Variable var(kInput, {2, 3});
    JuliaMarshal::FromJuliaArray(arr, var);

    // Check values
    for (size_t i = 0; i < 6; i++) {
        EXPECT_DOUBLE_EQ(var(i), i + 1.0);
    }
}

// ============================================================================
// Round-trip tests
// ============================================================================

TEST_F(JuliaMarshalTest, RoundTrip_Scalar) {
    Variable original(kInput, {1});
    original(0) = 3.14159;

    // C++ → Julia → C++
    jl_array_t* julia_arr = JuliaMarshal::ToJuliaArray(original);
    Variable result(kInput, {1});
    JuliaMarshal::FromJuliaArray(julia_arr, result);

    EXPECT_DOUBLE_EQ(result(0), original(0));
}

TEST_F(JuliaMarshalTest, RoundTrip_Vector) {
    Variable original(kInput, {10});
    for (size_t i = 0; i < 10; i++) {
        original(i) = sin(i * 0.5);
    }

    // Round trip
    jl_array_t* julia_arr = JuliaMarshal::ToJuliaArray(original);
    Variable result(kInput, {10});
    JuliaMarshal::FromJuliaArray(julia_arr, result);

    for (size_t i = 0; i < 10; i++) {
        EXPECT_DOUBLE_EQ(result(i), original(i));
    }
}

TEST_F(JuliaMarshalTest, RoundTrip_Matrix) {
    Variable original(kInput, {3, 4});
    for (size_t i = 0; i < 12; i++) {
        original(i) = i * i * 0.1;
    }

    // Round trip
    jl_array_t* julia_arr = JuliaMarshal::ToJuliaArray(original);
    Variable result(kInput, {3, 4});
    JuliaMarshal::FromJuliaArray(julia_arr, result);

    for (size_t i = 0; i < 12; i++) {
        EXPECT_DOUBLE_EQ(result(i), original(i));
    }
}

// ============================================================================
// Variables dictionary conversions
// ============================================================================

TEST_F(JuliaMarshalTest, ToJuliaDict_Variables) {
    Variables vars;
    vars["x"] = Variable(kInput, {1});
    vars["x"](0) = 5.0;
    vars["y"] = Variable(kInput, {2});
    vars["y"](0) = 10.0;
    vars["y"](1) = 20.0;

    // Convert to Julia Dict
    jl_value_t* dict = JuliaMarshal::ToJuliaDict(vars);

    ASSERT_NE(dict, nullptr);
    EXPECT_TRUE(JuliaMarshal::IsDict(dict));

    // Check keys
    std::vector<std::string> keys = JuliaMarshal::GetDictKeys(dict);
    EXPECT_EQ(keys.size(), 2);
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "x") != keys.end());
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "y") != keys.end());

    // Check values
    jl_value_t* x_val = JuliaMarshal::GetDictValue(dict, "x");
    ASSERT_NE(x_val, nullptr);
    EXPECT_TRUE(jl_is_array(x_val));
    jl_array_t* x_arr = (jl_array_t*)x_val;
    EXPECT_EQ(jl_array_len(x_arr), 1);
    double* x_data = (double*)jl_array_data(x_arr);
    EXPECT_DOUBLE_EQ(x_data[0], 5.0);

    jl_value_t* y_val = JuliaMarshal::GetDictValue(dict, "y");
    ASSERT_NE(y_val, nullptr);
    jl_array_t* y_arr = (jl_array_t*)y_val;
    EXPECT_EQ(jl_array_len(y_arr), 2);
    double* y_data = (double*)jl_array_data(y_arr);
    EXPECT_DOUBLE_EQ(y_data[0], 10.0);
    EXPECT_DOUBLE_EQ(y_data[1], 20.0);
}

TEST_F(JuliaMarshalTest, FromJuliaDict_Variables) {
    // Create Julia Dict
    runtime_->Eval("test_dict = Dict(\"a\" => [1.0], \"b\" => [2.0, 3.0, 4.0])");
    jl_value_t* dict = runtime_->Eval("test_dict");

    // Convert to C++ Variables
    Variables vars;
    vars["a"] = Variable(kInput, {1});
    vars["b"] = Variable(kInput, {3});

    JuliaMarshal::FromJuliaDict(dict, vars);

    EXPECT_DOUBLE_EQ(vars["a"](0), 1.0);
    EXPECT_DOUBLE_EQ(vars["b"](0), 2.0);
    EXPECT_DOUBLE_EQ(vars["b"](1), 3.0);
    EXPECT_DOUBLE_EQ(vars["b"](2), 4.0);
}

TEST_F(JuliaMarshalTest, RoundTrip_Variables) {
    Variables original;
    original["x"] = Variable(kInput, {1});
    original["x"](0) = 123.456;
    original["y"] = Variable(kInput, {3});
    original["y"](0) = 1.0;
    original["y"](1) = 2.0;
    original["y"](2) = 3.0;
    original["z"] = Variable(kInput, {2, 2});
    original["z"](0) = 11.0;
    original["z"](1) = 12.0;
    original["z"](2) = 21.0;
    original["z"](3) = 22.0;

    // Round trip
    jl_value_t* julia_dict = JuliaMarshal::ToJuliaDict(original);
    Variables result;
    result["x"] = Variable(kInput, {1});
    result["y"] = Variable(kInput, {3});
    result["z"] = Variable(kInput, {2, 2});
    JuliaMarshal::FromJuliaDict(julia_dict, result);

    EXPECT_DOUBLE_EQ(result["x"](0), original["x"](0));
    for (size_t i = 0; i < 3; i++) {
        EXPECT_DOUBLE_EQ(result["y"](i), original["y"](i));
    }
    for (size_t i = 0; i < 4; i++) {
        EXPECT_DOUBLE_EQ(result["z"](i), original["z"](i));
    }
}

// ============================================================================
// Partials (nested dict) conversions
// ============================================================================

TEST_F(JuliaMarshalTest, ToJuliaDict_Partials) {
    Partials partials;
    partials["f"] = std::map<std::string, Variable>();
    partials["f"]["x"] = Variable(kInput, {1});
    partials["f"]["x"](0) = 2.0;
    partials["f"]["y"] = Variable(kInput, {1});
    partials["f"]["y"](0) = 3.0;

    // Convert to nested Julia Dict
    jl_value_t* dict = JuliaMarshal::ToJuliaDict(partials);

    ASSERT_NE(dict, nullptr);
    EXPECT_TRUE(JuliaMarshal::IsDict(dict));

    // Get inner dict
    jl_value_t* f_dict = JuliaMarshal::GetDictValue(dict, "f");
    ASSERT_NE(f_dict, nullptr);
    EXPECT_TRUE(JuliaMarshal::IsDict(f_dict));

    // Check values
    jl_value_t* df_dx = JuliaMarshal::GetDictValue(f_dict, "x");
    ASSERT_NE(df_dx, nullptr);
    double* data_x = (double*)jl_array_data((jl_array_t*)df_dx);
    EXPECT_DOUBLE_EQ(data_x[0], 2.0);

    jl_value_t* df_dy = JuliaMarshal::GetDictValue(f_dict, "y");
    ASSERT_NE(df_dy, nullptr);
    double* data_y = (double*)jl_array_data((jl_array_t*)df_dy);
    EXPECT_DOUBLE_EQ(data_y[0], 3.0);
}

TEST_F(JuliaMarshalTest, FromJuliaDict_Partials) {
    // Create nested Julia Dict
    runtime_->Eval("partials_dict = Dict(\"f\" => Dict(\"x\" => [5.0], \"y\" => [7.0]))");
    jl_value_t* dict = runtime_->Eval("partials_dict");

    // Convert to C++ Partials
    Partials partials;
    partials["f"] = std::map<std::string, Variable>();
    partials["f"]["x"] = Variable(kInput, {1});
    partials["f"]["y"] = Variable(kInput, {1});

    JuliaMarshal::FromJuliaDict(dict, partials);

    EXPECT_DOUBLE_EQ(partials["f"]["x"](0), 5.0);
    EXPECT_DOUBLE_EQ(partials["f"]["y"](0), 7.0);
}

TEST_F(JuliaMarshalTest, RoundTrip_Partials) {
    Partials original;
    original["f"] = std::map<std::string, Variable>();
    original["f"]["x"] = Variable(kInput, {1});
    original["f"]["x"](0) = -2.0;
    original["f"]["y"] = Variable(kInput, {1});
    original["f"]["y"](0) = 13.0;
    original["g"] = std::map<std::string, Variable>();
    original["g"]["x"] = Variable(kInput, {2});
    original["g"]["x"](0) = 0.5;
    original["g"]["x"](1) = 1.5;

    // Round trip
    jl_value_t* julia_dict = JuliaMarshal::ToJuliaDict(original);
    Partials result;
    result["f"] = std::map<std::string, Variable>();
    result["f"]["x"] = Variable(kInput, {1});
    result["f"]["y"] = Variable(kInput, {1});
    result["g"] = std::map<std::string, Variable>();
    result["g"]["x"] = Variable(kInput, {2});
    JuliaMarshal::FromJuliaDict(julia_dict, result);

    EXPECT_DOUBLE_EQ(result["f"]["x"](0), original["f"]["x"](0));
    EXPECT_DOUBLE_EQ(result["f"]["y"](0), original["f"]["y"](0));
    EXPECT_DOUBLE_EQ(result["g"]["x"](0), original["g"]["x"](0));
    EXPECT_DOUBLE_EQ(result["g"]["x"](1), original["g"]["x"](1));
}

// ============================================================================
// Helper function tests
// ============================================================================

TEST_F(JuliaMarshalTest, GetArrayShape) {
    jl_array_t* arr = (jl_array_t*)runtime_->Eval("reshape(1:24, 2, 3, 4)");

    std::vector<size_t> shape = JuliaMarshal::GetArrayShape(arr);

    EXPECT_EQ(shape.size(), 3);
    EXPECT_EQ(shape[0], 2);
    EXPECT_EQ(shape[1], 3);
    EXPECT_EQ(shape[2], 4);
}

TEST_F(JuliaMarshalTest, IsDict) {
    jl_value_t* dict = runtime_->Eval("Dict(\"a\" => 1)");
    jl_value_t* array = runtime_->Eval("[1, 2, 3]");
    jl_value_t* number = runtime_->Eval("42");

    EXPECT_TRUE(JuliaMarshal::IsDict(dict));
    EXPECT_FALSE(JuliaMarshal::IsDict(array));
    EXPECT_FALSE(JuliaMarshal::IsDict(number));
}

TEST_F(JuliaMarshalTest, IsArray) {
    jl_value_t* array = runtime_->Eval("[1.0, 2.0, 3.0]");
    jl_value_t* dict = runtime_->Eval("Dict(\"a\" => 1)");
    jl_value_t* number = runtime_->Eval("42.0");

    EXPECT_TRUE(JuliaMarshal::IsArray(array));
    EXPECT_FALSE(JuliaMarshal::IsArray(dict));
    EXPECT_FALSE(JuliaMarshal::IsArray(number));
}

TEST_F(JuliaMarshalTest, GetDictKeys) {
    jl_value_t* dict = runtime_->Eval("Dict(\"x\" => 1, \"y\" => 2, \"z\" => 3)");

    std::vector<std::string> keys = JuliaMarshal::GetDictKeys(dict);

    EXPECT_EQ(keys.size(), 3);
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "x") != keys.end());
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "y") != keys.end());
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "z") != keys.end());
}

TEST_F(JuliaMarshalTest, SetAndGetDictValue) {
    jl_value_t* dict = runtime_->Eval("Dict{String, Any}()");
    jl_value_t* value = runtime_->Eval("[1.0, 2.0, 3.0]");

    // Set value
    JuliaMarshal::SetDictValue(dict, "test_key", value);

    // Get value back
    jl_value_t* retrieved = JuliaMarshal::GetDictValue(dict, "test_key");

    ASSERT_NE(retrieved, nullptr);
    EXPECT_TRUE(jl_is_array(retrieved));
    EXPECT_EQ(jl_array_len((jl_array_t*)retrieved), 3);
}
