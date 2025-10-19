#ifndef PHILOTE_JULIA_RUNTIME_H
#define PHILOTE_JULIA_RUNTIME_H

#include <julia.h>
#include <string>
#include <vector>
#include <memory>
#include <stdexcept>

namespace philote {

/**
 * @brief Exception thrown when Julia runtime encounters an error
 */
class JuliaException : public std::runtime_error {
public:
    explicit JuliaException(const std::string& msg)
        : std::runtime_error("Julia error: " + msg) {}
};

/**
 * @brief Singleton class managing the Julia runtime lifecycle
 *
 * This class handles:
 * - Julia initialization and shutdown
 * - Module loading
 * - GC root management
 * - Error handling
 *
 * Thread safety: All Julia API calls must be made from the thread
 * that calls Initialize().
 */
class JuliaRuntime {
public:
    /**
     * @brief Get the singleton instance
     */
    static JuliaRuntime& Instance();

    /**
     * @brief Initialize the Julia runtime
     *
     * This must be called before any other Julia operations.
     * Safe to call multiple times (subsequent calls are ignored).
     *
     * @throws JuliaException if initialization fails
     */
    void Initialize();

    /**
     * @brief Shutdown the Julia runtime
     *
     * Cleans up all GC roots and shuts down Julia.
     * After calling this, Initialize() must be called again before
     * using Julia functionality.
     */
    void Shutdown();

    /**
     * @brief Check if Julia runtime is initialized
     */
    bool IsInitialized() const { return initialized_; }

    /**
     * @brief Load a Julia module from a file
     *
     * @param filepath Path to the .jl file
     * @return Pointer to the loaded module
     * @throws JuliaException if loading fails
     */
    jl_module_t* LoadModule(const std::string& filepath);

    /**
     * @brief Get a function from a module
     *
     * @param module Module containing the function
     * @param name Function name
     * @return Pointer to the function
     * @throws JuliaException if function not found
     */
    jl_function_t* GetFunction(jl_module_t* module, const std::string& name);

    /**
     * @brief Get a function from the main module
     *
     * @param name Function name
     * @return Pointer to the function
     * @throws JuliaException if function not found
     */
    jl_function_t* GetFunction(const std::string& name);

    /**
     * @brief Add a Julia value to GC roots
     *
     * Prevents the Julia garbage collector from collecting this value.
     * Must call RemoveGCRoot() when done to avoid memory leaks.
     *
     * @param value Julia value to protect
     */
    void AddGCRoot(jl_value_t* value);

    /**
     * @brief Remove a Julia value from GC roots
     *
     * @param value Julia value to unprotect
     */
    void RemoveGCRoot(jl_value_t* value);

    /**
     * @brief Check if Julia has an active exception
     */
    bool HasException() const;

    /**
     * @brief Get the current exception message
     *
     * @return Exception message string
     */
    std::string GetExceptionMessage() const;

    /**
     * @brief Clear the current exception
     */
    void ClearException();

    /**
     * @brief Check for exception and throw if present
     *
     * @throws JuliaException if Julia has an active exception
     */
    void CheckException() const;

    /**
     * @brief Evaluate a Julia expression string
     *
     * @param expr Julia expression to evaluate
     * @return Result of evaluation
     * @throws JuliaException if evaluation fails
     */
    jl_value_t* Eval(const std::string& expr);

private:
    JuliaRuntime();
    ~JuliaRuntime();

    // Delete copy and move constructors
    JuliaRuntime(const JuliaRuntime&) = delete;
    JuliaRuntime& operator=(const JuliaRuntime&) = delete;
    JuliaRuntime(JuliaRuntime&&) = delete;
    JuliaRuntime& operator=(JuliaRuntime&&) = delete;

    bool initialized_;
    std::vector<jl_value_t*> gc_roots_;
};

} // namespace philote

#endif // PHILOTE_JULIA_RUNTIME_H
