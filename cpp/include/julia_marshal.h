#ifndef PHILOTE_JULIA_MARSHAL_H
#define PHILOTE_JULIA_MARSHAL_H

#include <julia.h>
#include <variable.h>
#include <string>
#include <map>
#include <vector>

namespace philote {

/**
 * @brief Data marshaling utilities for converting between C++ and Julia types
 *
 * This class handles bidirectional conversion of:
 * - philote::Variable ↔ Julia Array{Float64}
 * - philote::Variables (Dict) ↔ Julia Dict{String, Array{Float64}}
 * - philote::Partials ↔ Julia Dict{String, Dict{String, Array{Float64}}}
 *
 * All methods are static since marshaling is stateless.
 */
class JuliaMarshal {
public:
    // ========================================================================
    // C++ → Julia conversions
    // ========================================================================

    /**
     * @brief Convert a Variable to a Julia Array
     *
     * Creates a Julia Array{Float64} with the same shape and data as the
     * C++ Variable.
     *
     * @param var C++ Variable to convert
     * @return Julia array (jl_array_t*)
     */
    static jl_array_t* ToJuliaArray(const Variable& var);

    /**
     * @brief Convert Variables dictionary to Julia Dict
     *
     * Creates a Julia Dict{String, Array{Float64}} from the C++ Variables map.
     *
     * @param vars C++ Variables map
     * @return Julia dictionary (jl_value_t*)
     */
    static jl_value_t* ToJuliaDict(const Variables& vars);

    /**
     * @brief Convert Partials to nested Julia Dict
     *
     * Creates a Julia Dict{String, Dict{String, Array{Float64}}} from the
     * C++ Partials map.
     *
     * @param partials C++ Partials map
     * @return Julia nested dictionary (jl_value_t*)
     */
    static jl_value_t* ToJuliaDict(const Partials& partials);

    /**
     * @brief Convert a C++ vector to Julia Vector
     *
     * @param vec C++ vector of integers
     * @return Julia Vector{Int64}
     */
    static jl_value_t* ToJuliaVector(const std::vector<int64_t>& vec);

    // ========================================================================
    // Julia → C++ conversions
    // ========================================================================

    /**
     * @brief Convert a Julia Array to a Variable
     *
     * Extracts data from a Julia Array{Float64} and copies it into the
     * provided C++ Variable.
     *
     * @param array Julia array (jl_array_t*)
     * @param var Target C++ Variable (must be pre-allocated with correct size)
     */
    static void FromJuliaArray(jl_array_t* array, Variable& var);

    /**
     * @brief Convert Julia Dict to Variables
     *
     * Extracts data from Julia Dict{String, Array{Float64}} and populates
     * the C++ Variables map.
     *
     * @param dict Julia dictionary
     * @param vars Target C++ Variables map
     */
    static void FromJuliaDict(jl_value_t* dict, Variables& vars);

    /**
     * @brief Convert nested Julia Dict to Partials
     *
     * Extracts data from Julia Dict{String, Dict{String, Array{Float64}}}
     * and populates the C++ Partials map.
     *
     * @param dict Julia nested dictionary
     * @param partials Target C++ Partials map
     */
    static void FromJuliaDict(jl_value_t* dict, Partials& partials);

    /**
     * @brief Convert Julia Vector to C++ vector
     *
     * @param vec Julia Vector{Int64}
     * @return C++ vector of integers
     */
    static std::vector<int64_t> FromJuliaVector(jl_value_t* vec);

    // ========================================================================
    // Options marshaling
    // ========================================================================

    /**
     * @brief Convert an option value to Julia value
     *
     * Converts a value based on its type string. Supported types:
     * - "float": converts to Julia Float64
     * - "int": converts to Julia Int64
     * - "bool": converts to Julia Bool
     * - "string": converts to Julia String
     *
     * @param value String representation of the value
     * @param type Type string ("float", "int", "bool", "string")
     * @return Julia value (jl_value_t*)
     */
    static jl_value_t* OptionValueToJulia(const std::string& value,
                                         const std::string& type);

    /**
     * @brief Convert options map to Julia Dict
     *
     * Creates a Julia Dict{String, Any} from C++ options. The options
     * are specified as a map of name => (value, type) pairs.
     *
     * @param options Map of option name => (value string, type string)
     * @return Julia dictionary (jl_value_t*)
     */
    static jl_value_t* OptionsToJuliaDict(
        const std::map<std::string, std::pair<std::string, std::string>>& options);

    // ========================================================================
    // Helper functions
    // ========================================================================

    /**
     * @brief Get the shape of a Julia array
     *
     * @param array Julia array
     * @return Vector of dimensions
     */
    static std::vector<size_t> GetArrayShape(jl_array_t* array);

    /**
     * @brief Check if a Julia value is a dictionary
     *
     * @param value Julia value to check
     * @return true if value is a Dict
     */
    static bool IsDict(jl_value_t* value);

    /**
     * @brief Check if a Julia value is an array
     *
     * @param value Julia value to check
     * @return true if value is an Array
     */
    static bool IsArray(jl_value_t* value);

    /**
     * @brief Get dictionary keys as strings
     *
     * @param dict Julia dictionary
     * @return Vector of key strings
     */
    static std::vector<std::string> GetDictKeys(jl_value_t* dict);

    /**
     * @brief Get value from dictionary by key
     *
     * @param dict Julia dictionary
     * @param key Key string
     * @return Value from dictionary, or nullptr if not found
     */
    static jl_value_t* GetDictValue(jl_value_t* dict, const std::string& key);

    /**
     * @brief Set value in dictionary
     *
     * @param dict Julia dictionary
     * @param key Key string
     * @param value Value to set
     */
    static void SetDictValue(jl_value_t* dict,
                            const std::string& key,
                            jl_value_t* value);

private:
    // Cache commonly used Julia types and functions
    static jl_function_t* GetDictFunction();
    static jl_function_t* GetKeysFunction();
    static jl_function_t* GetGetindexFunction();
    static jl_function_t* GetSetindexFunction();
};

} // namespace philote

#endif // PHILOTE_JULIA_MARSHAL_H
