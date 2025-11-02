#include "julia_runtime.h"
#include <algorithm>
#include <iostream>

namespace philote {

// JuliaThreadAdopter implementation
JuliaThreadAdopter::JuliaThreadAdopter() {
    std::cout << "[JuliaThreadAdopter] Constructor called" << std::endl;
    gcframe_ = JuliaRuntime::Instance().AdoptThread();
    std::cout << "[JuliaThreadAdopter] Constructor complete" << std::endl;
}

JuliaThreadAdopter::~JuliaThreadAdopter() {
    JuliaRuntime::Instance().ReleaseThread(gcframe_);
}

// JuliaRuntime implementation
JuliaRuntime& JuliaRuntime::Instance() {
    static JuliaRuntime instance;
    return instance;
}

JuliaRuntime::JuliaRuntime() : initialized_(false) {}

JuliaRuntime::~JuliaRuntime() {
    if (initialized_) {
        Shutdown();
    }
}

void JuliaRuntime::Initialize() {
    if (initialized_) {
        return; // Already initialized
    }

    // Initialize Julia
    jl_init();

    if (HasException()) {
        std::string msg = GetExceptionMessage();
        jl_atexit_hook(0);
        throw JuliaException("Failed to initialize Julia: " + msg);
    }

    initialized_ = true;
}

void JuliaRuntime::Shutdown() {
    if (!initialized_) {
        return;
    }

    // Clear all GC roots
    gc_roots_.clear();

    // Shutdown Julia
    jl_atexit_hook(0);

    initialized_ = false;
}

jl_module_t* JuliaRuntime::LoadModule(const std::string& filepath) {
    if (!initialized_) {
        throw JuliaException("Julia runtime not initialized");
    }

    // Build Julia expression to include the file
    std::string expr = "include(\"" + filepath + "\")";

    // Evaluate the include statement
    jl_value_t* result = jl_eval_string(expr.c_str());
    CheckException();

    // The result should be the Main module
    // Return it as a module
    return jl_main_module;
}

jl_function_t* JuliaRuntime::GetFunction(jl_module_t* module,
                                         const std::string& name) {
    if (!initialized_) {
        throw JuliaException("Julia runtime not initialized");
    }

    jl_function_t* func = jl_get_function(module, name.c_str());

    if (func == nullptr || HasException()) {
        throw JuliaException("Function '" + name + "' not found in module");
    }

    return func;
}

jl_function_t* JuliaRuntime::GetFunction(const std::string& name) {
    return GetFunction(jl_main_module, name);
}

void JuliaRuntime::AddGCRoot(jl_value_t* value) {
    if (value == nullptr) {
        return;
    }

    // Add to our tracking list
    gc_roots_.push_back(value);

    // Protect from GC using Julia's GC root system
    // Note: In production, you may want to use jl_gc_add_ptr_finalizer
    // or maintain a Julia-side array of roots
    JL_GC_PUSH1(&value);
}

void JuliaRuntime::RemoveGCRoot(jl_value_t* value) {
    if (value == nullptr) {
        return;
    }

    // Remove from tracking list
    auto it = std::find(gc_roots_.begin(), gc_roots_.end(), value);
    if (it != gc_roots_.end()) {
        gc_roots_.erase(it);
    }

    // Note: Corresponding JL_GC_POP() would be needed in a real implementation
    // This simplified version relies on Julia's GC to clean up
}

bool JuliaRuntime::HasException() const {
    return jl_exception_occurred() != nullptr;
}

std::string JuliaRuntime::GetExceptionMessage() const {
    jl_value_t* ex = jl_exception_occurred();
    if (ex == nullptr) {
        return "";
    }

    // Get string representation of exception
    jl_value_t* string_val = jl_call2(
        jl_get_function(jl_base_module, "string"),
        jl_get_function(jl_base_module, "sprint"),
        jl_get_function(jl_base_module, "showerror")
    );

    if (string_val != nullptr && jl_is_string(string_val)) {
        return std::string(jl_string_ptr(string_val));
    }

    // Fallback: try to get type name
    jl_value_t* ex_type = jl_typeof(ex);
    if (ex_type != nullptr) {
        jl_datatype_t* dt = (jl_datatype_t*)ex_type;
        jl_sym_t* name = dt->name->name;
        return std::string(jl_symbol_name(name));
    }

    return "Unknown Julia exception";
}

void JuliaRuntime::ClearException() {
    // Julia doesn't have a direct API to clear exceptions
    // But they are cleared on next successful evaluation
    jl_exception_clear();
}

void JuliaRuntime::CheckException() const {
    if (HasException()) {
        std::string msg = GetExceptionMessage();
        throw JuliaException(msg);
    }
}

jl_gcframe_t** JuliaRuntime::AdoptThread() {
    std::cout << "[Julia] AdoptThread() called" << std::endl;

    if (!initialized_) {
        throw JuliaException("Julia runtime not initialized");
    }

    std::cout << "[Julia] Calling jl_adopt_thread()..." << std::endl;

    // Adopt this thread for Julia
    // Note: jl_adopt_thread() returns the previous pgcstack value
    // For a non-Julia thread, this will set up Julia runtime for this thread
    jl_gcframe_t** gcframe = jl_adopt_thread();

    std::cout << "[Julia] Thread adopted successfully, gcframe=" << gcframe << std::endl;
    return gcframe;
}

void JuliaRuntime::ReleaseThread(jl_gcframe_t** gcframe) {
    // Only release if we actually adopted the thread
    if (gcframe != nullptr) {
        // Note: Julia doesn't have a public jl_release_thread API
        // The thread will be released when Julia shuts down
        // For now, we just track that we're done with this thread's Julia work
    }
}

jl_value_t* JuliaRuntime::Eval(const std::string& expr) {
    if (!initialized_) {
        throw JuliaException("Julia runtime not initialized");
    }

    jl_value_t* result = jl_eval_string(expr.c_str());
    CheckException();

    return result;
}

} // namespace philote
