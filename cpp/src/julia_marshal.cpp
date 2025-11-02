#include "julia_marshal.h"
#include "julia_runtime.h"
#include <cstring>

namespace philote {

// ============================================================================
// C++ → Julia conversions
// ============================================================================

jl_array_t* JuliaMarshal::ToJuliaArray(const Variable& var) {
    std::vector<size_t> shape = var.Shape();
    size_t ndims = shape.size();

    // Get Float64 array type
    jl_value_t* array_type = jl_apply_array_type(
        (jl_value_t*)jl_float64_type, ndims);

    // Allocate Julia array with the given shape
    jl_array_t* arr = jl_alloc_array_nd(
        (jl_value_t*)array_type,
        shape.data(),
        ndims);

    JuliaRuntime::Instance().CheckException();

    // Copy data from C++ to Julia
    // Note: Julia uses column-major ordering, same as Fortran
    double* data = jl_array_data(arr, double);
    for (size_t i = 0; i < var.Size(); i++) {
        data[i] = var(i);
    }

    return arr;
}

jl_value_t* JuliaMarshal::ToJuliaDict(const Variables& vars) {
    // Create empty Dict{String, Array{Float64}}
    jl_function_t* dict_fn = GetDictFunction();
    jl_value_t* dict = jl_call0(dict_fn);
    JuliaRuntime::Instance().CheckException();

    // Protect dictionary from GC during population
    JL_GC_PUSH1(&dict);

    // Populate dictionary
    for (const auto& [name, var] : vars) {
        jl_array_t* arr = ToJuliaArray(var);
        jl_value_t* key = jl_cstr_to_string(name.c_str());

        // dict[key] = arr
        SetDictValue(dict, name, (jl_value_t*)arr);
    }

    JL_GC_POP();

    return dict;
}

jl_value_t* JuliaMarshal::ToJuliaDict(const Partials& partials) {
    // Create outer Dict{String, Dict{String, Array{Float64}}}
    jl_function_t* dict_fn = GetDictFunction();
    jl_value_t* outer_dict = jl_call0(dict_fn);
    JuliaRuntime::Instance().CheckException();

    JL_GC_PUSH1(&outer_dict);

    // Group partials by output name
    std::map<std::string, std::map<std::string, const Variable*>> grouped;
    for (const auto& [key_pair, var] : partials) {
        const std::string& output = key_pair.first;
        const std::string& input = key_pair.second;
        grouped[output][input] = &var;
    }

    // Build nested dictionaries
    for (const auto& [output, input_map] : grouped) {
        jl_value_t* inner_dict = jl_call0(dict_fn);
        JL_GC_PUSH1(&inner_dict);

        for (const auto& [input, var_ptr] : input_map) {
            jl_array_t* arr = ToJuliaArray(*var_ptr);
            SetDictValue(inner_dict, input, (jl_value_t*)arr);
        }

        SetDictValue(outer_dict, output, inner_dict);
        JL_GC_POP(); // inner_dict
    }

    JL_GC_POP(); // outer_dict

    return outer_dict;
}

jl_value_t* JuliaMarshal::ToJuliaVector(const std::vector<int64_t>& vec) {
    // Create Julia Vector{Int64}
    jl_value_t* array_type = jl_apply_array_type((jl_value_t*)jl_int64_type, 1);
    jl_array_t* arr = jl_alloc_array_1d(array_type, vec.size());

    JuliaRuntime::Instance().CheckException();

    // Copy data
    int64_t* data = jl_array_data(arr, int64_t);
    std::memcpy(data, vec.data(), vec.size() * sizeof(int64_t));

    return (jl_value_t*)arr;
}

// ============================================================================
// Julia → C++ conversions
// ============================================================================

void JuliaMarshal::FromJuliaArray(jl_array_t* array, Variable& var) {
    if (array == nullptr) {
        throw JuliaException("Null Julia array");
    }

    // Verify it's a Float64 array
    if (!jl_is_array(array)) {
        throw JuliaException("Value is not a Julia array");
    }

    // Get array data
    double* data = jl_array_data(array, double);
    size_t length = jl_array_len(array);

    // Check size matches
    if (length != var.Size()) {
        throw JuliaException("Array size mismatch: expected " +
                           std::to_string(var.Size()) + ", got " +
                           std::to_string(length));
    }

    // Copy data from Julia to C++
    for (size_t i = 0; i < length; i++) {
        var(i) = data[i];
    }
}

void JuliaMarshal::FromJuliaDict(jl_value_t* dict, Variables& vars) {
    if (dict == nullptr) {
        throw JuliaException("Null Julia dictionary");
    }

    if (!IsDict(dict)) {
        throw JuliaException("Value is not a Julia dictionary");
    }

    // Get dictionary keys
    std::vector<std::string> keys = GetDictKeys(dict);

    // Extract each key-value pair
    for (const std::string& key : keys) {
        jl_value_t* value = GetDictValue(dict, key);

        if (jl_is_array(value)) {
            jl_array_t* arr = (jl_array_t*)value;

            // Get shape for Variable creation
            std::vector<size_t> shape = GetArrayShape(arr);

            // Check if variable already exists in map
            if (vars.find(key) == vars.end()) {
                // Create new variable with correct shape
                std::vector<size_t> shape_sizet = shape;
                vars[key] = Variable(philote::kOutput, shape_sizet);
            }

            // Copy data from Julia array
            FromJuliaArray(arr, vars[key]);
        }
    }
}

void JuliaMarshal::FromJuliaDict(jl_value_t* dict, Partials& partials) {
    if (dict == nullptr) {
        throw JuliaException("Null Julia dictionary");
    }

    if (!IsDict(dict)) {
        throw JuliaException("Value is not a Julia dictionary");
    }

    // Get outer dictionary keys (output names)
    std::vector<std::string> output_keys = GetDictKeys(dict);

    for (const std::string& output : output_keys) {
        jl_value_t* inner_dict = GetDictValue(dict, output);

        if (!IsDict(inner_dict)) {
            throw JuliaException("Expected nested dictionary for output: " + output);
        }

        // Get inner dictionary keys (input names)
        std::vector<std::string> input_keys = GetDictKeys(inner_dict);

        for (const std::string& input : input_keys) {
            jl_value_t* value = GetDictValue(inner_dict, input);

            if (jl_is_array(value)) {
                jl_array_t* arr = (jl_array_t*)value;
                std::vector<size_t> shape = GetArrayShape(arr);

                // Create key pair
                auto key_pair = std::make_pair(output, input);

                // Create or get variable
                if (partials.find(key_pair) == partials.end()) {
                    partials[key_pair] = Variable(philote::kPartial, shape);
                }

                // Copy data
                FromJuliaArray(arr, partials[key_pair]);
            }
        }
    }
}

std::vector<int64_t> JuliaMarshal::FromJuliaVector(jl_value_t* vec) {
    if (!jl_is_array(vec)) {
        throw JuliaException("Value is not a Julia array");
    }

    jl_array_t* arr = (jl_array_t*)vec;
    size_t length = jl_array_len(arr);

    std::vector<int64_t> result;
    result.reserve(length);

    int64_t* data = jl_array_data(arr, int64_t);
    for (size_t i = 0; i < length; i++) {
        result.push_back(data[i]);
    }

    return result;
}

// ============================================================================
// Helper functions
// ============================================================================

std::vector<size_t> JuliaMarshal::GetArrayShape(jl_array_t* array) {
    size_t ndims = jl_array_ndims(array);
    std::vector<size_t> shape;
    shape.reserve(ndims);

    for (size_t i = 0; i < ndims; i++) {
        shape.push_back(jl_array_dim(array, i));
    }

    return shape;
}

bool JuliaMarshal::IsDict(jl_value_t* value) {
    if (value == nullptr) {
        return false;
    }

    // Check if the type is a Dict
    jl_value_t* dict_type = jl_eval_string("Dict");
    jl_value_t* value_type = jl_typeof(value);

    // Check if value's type is a subtype of Dict
    jl_function_t* isa_fn = jl_get_function(jl_base_module, "isa");
    jl_value_t* result = jl_call2(isa_fn, value, dict_type);

    return jl_unbox_bool(result);
}

bool JuliaMarshal::IsArray(jl_value_t* value) {
    return value != nullptr && jl_is_array(value);
}

std::vector<std::string> JuliaMarshal::GetDictKeys(jl_value_t* dict) {
    std::vector<std::string> result;

    // Call keys(dict)
    jl_function_t* keys_fn = GetKeysFunction();
    jl_value_t* keys = jl_call1(keys_fn, dict);
    JuliaRuntime::Instance().CheckException();

    // Convert iterator to array: collect(keys)
    jl_function_t* collect_fn = jl_get_function(jl_base_module, "collect");
    jl_value_t* keys_array = jl_call1(collect_fn, keys);
    JuliaRuntime::Instance().CheckException();

    if (!jl_is_array(keys_array)) {
        return result;
    }

    jl_array_t* arr = (jl_array_t*)keys_array;
    size_t length = jl_array_len(arr);

    for (size_t i = 0; i < length; i++) {
        jl_value_t* key = jl_array_ptr_ref(arr, i);
        if (jl_is_string(key)) {
            result.push_back(std::string(jl_string_ptr(key)));
        }
    }

    return result;
}

jl_value_t* JuliaMarshal::GetDictValue(jl_value_t* dict, const std::string& key) {
    // Call getindex(dict, key) which is dict[key]
    jl_function_t* getindex_fn = GetGetindexFunction();
    jl_value_t* key_str = jl_cstr_to_string(key.c_str());

    jl_value_t* value = jl_call2(getindex_fn, dict, key_str);
    JuliaRuntime::Instance().CheckException();

    return value;
}

void JuliaMarshal::SetDictValue(jl_value_t* dict,
                                const std::string& key,
                                jl_value_t* value) {
    // Call setindex!(dict, value, key) which is dict[key] = value
    jl_function_t* setindex_fn = GetSetindexFunction();
    jl_value_t* key_str = jl_cstr_to_string(key.c_str());

    jl_call3(setindex_fn, dict, value, key_str);
    JuliaRuntime::Instance().CheckException();
}

// ============================================================================
// Options marshaling
// ============================================================================

jl_value_t* JuliaMarshal::OptionValueToJulia(const std::string& value,
                                             const std::string& type) {
    if (type == "float") {
        // Parse as double
        double val = std::stod(value);
        return jl_box_float64(val);
    }
    else if (type == "int") {
        // Parse as int64
        int64_t val = std::stoll(value);
        return jl_box_int64(val);
    }
    else if (type == "bool") {
        // Parse as boolean
        bool val = (value == "true" || value == "1" || value == "True" || value == "TRUE");
        return jl_box_bool(val);
    }
    else if (type == "string") {
        // Convert to Julia string
        return jl_cstr_to_string(value.c_str());
    }
    else {
        throw JuliaException("Unknown option type: " + type);
    }
}

jl_value_t* JuliaMarshal::OptionsToJuliaDict(
    const std::map<std::string, std::pair<std::string, std::string>>& options) {

    // Create empty Dict{String, Any}
    jl_function_t* dict_fn = GetDictFunction();
    jl_value_t* dict = jl_call0(dict_fn);
    JuliaRuntime::Instance().CheckException();

    // Protect from GC
    JL_GC_PUSH1(&dict);

    // Add each option to the dictionary
    for (const auto& [name, value_type_pair] : options) {
        const std::string& value_str = value_type_pair.first;
        const std::string& type_str = value_type_pair.second;

        // Convert value to Julia based on type
        jl_value_t* julia_value = OptionValueToJulia(value_str, type_str);

        // Add to dictionary: dict[name] = julia_value
        SetDictValue(dict, name, julia_value);
    }

    JL_GC_POP();
    return dict;
}

// ============================================================================
// Cached Julia functions
// ============================================================================

jl_function_t* JuliaMarshal::GetDictFunction() {
    static jl_function_t* dict_fn = jl_get_function(jl_base_module, "Dict");
    return dict_fn;
}

jl_function_t* JuliaMarshal::GetKeysFunction() {
    static jl_function_t* keys_fn = jl_get_function(jl_base_module, "keys");
    return keys_fn;
}

jl_function_t* JuliaMarshal::GetGetindexFunction() {
    static jl_function_t* getindex_fn = jl_get_function(jl_base_module, "getindex");
    return getindex_fn;
}

jl_function_t* JuliaMarshal::GetSetindexFunction() {
    static jl_function_t* setindex_fn = jl_get_function(jl_base_module, "setindex!");
    return setindex_fn;
}

} // namespace philote
