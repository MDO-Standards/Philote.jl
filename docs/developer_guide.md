# Developer Guide {#developer_guide}

[TOC]

## Introduction

This guide explains the internal architecture of Philote-Julia for developers who want to:
- Understand how the system works
- Contribute to the project
- Extend functionality
- Debug issues

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     User's Julia Discipline                  │
│              (implements Philote interface)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────┐
│               Philote.jl Module (src/Philote.jl)             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Abstract Types & Interface                             │ │
│  │ - ExplicitDiscipline / ImplicitDiscipline              │ │
│  │ - add_input!(), add_output!(), declare_partials!()     │ │
│  │ - compute(), compute_partials()                        │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Metadata Management                                    │ │
│  │ - DisciplineMetadata struct                            │ │
│  │ - DISCIPLINE_METADATA global dict                      │ │
│  │ - get_metadata() function                              │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │ Julia C API
┌──────────────────────────┴──────────────────────────────────┐
│              C++ Wrapper (cpp/)                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ JuliaRuntime (julia_runtime.h/cpp)                     │ │
│  │ - Singleton pattern                                    │ │
│  │ - jl_init() / jl_atexit_hook()                         │ │
│  │ - Module loading                                       │ │
│  │ - GC root management                                   │ │
│  │ - Exception handling                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ JuliaMarshal (julia_marshal.h/cpp)                     │ │
│  │ - Variable ↔ jl_array_t                                │ │
│  │ - Variables ↔ Dict{String, Array}                      │ │
│  │ - Partials ↔ Dict{String, Dict{String, Array}}        │ │
│  │ - Type validation                                      │ │
│  │ - Shape preservation                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ JuliaExplicitDiscipline (julia_explicit.h/cpp)         │ │
│  │ - Inherits philote::ExplicitDiscipline                 │ │
│  │ - LoadDiscipline()                                     │ │
│  │ - ExtractMetadata()                                    │ │
│  │ - Compute() / ComputePartials()                        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────┐
│         Philote-Cpp gRPC Server Infrastructure               │
│         (DisciplineService, ExplicitService, etc.)           │
└──────────────────────────────────────────────────────────────┘
```

## Julia Interface Design

### Metadata Storage Pattern

The Julia interface uses a global dictionary to store metadata:

```julia
const DISCIPLINE_METADATA = Dict{UInt, DisciplineMetadata}()

function get_metadata(discipline::AbstractDiscipline)
    id = objectid(discipline)
    if !haskey(DISCIPLINE_METADATA, id)
        DISCIPLINE_METADATA[id] = DisciplineMetadata()
    end
    return DISCIPLINE_METADATA[id]
end
```

**Why this design?**
- Separates data from behavior
- Allows metadata inspection from C++
- Avoids requiring users to manage metadata fields
- Uses `objectid()` for unique identification

### Multiple Dispatch

Julia's multiple dispatch makes the interface elegant:

```julia
# Generic fallback (throws error)
function setup!(discipline::AbstractDiscipline)
    error("setup! must be implemented for $(typeof(discipline))")
end

# User implementation
function setup!(discipline::MyDiscipline)
    add_input!(discipline, "x", [1], "m")
end
```

This allows:
- Clear separation of interface and implementation
- Type-specific behavior
- Compile-time method resolution

## C++ Wrapper Implementation

### JuliaRuntime: Singleton Pattern

```cpp
class JuliaRuntime {
public:
    static JuliaRuntime& Instance() {
        static JuliaRuntime instance;  // Meyers' Singleton
        return instance;
    }

private:
    JuliaRuntime();  // Private constructor
    ~JuliaRuntime();
    JuliaRuntime(const JuliaRuntime&) = delete;  // No copy
    JuliaRuntime& operator=(const JuliaRuntime&) = delete;
};
```

**Design decisions:**
- Thread-safe since C++11
- Lazy initialization
- Single point of access
- Manages Julia lifecycle

### Julia Initialization Sequence

```cpp
void JuliaRuntime::Initialize() {
    if (initialized_) return;  // Guard against double init

    jl_init();  // Initialize Julia

    if (HasException()) {
        std::string msg = GetExceptionMessage();
        jl_atexit_hook(0);
        throw JuliaException("Failed to initialize: " + msg);
    }

    initialized_ = true;
}
```

**Critical points:**
- Must be called from main thread
- Only called once
- Exception handling prevents partial init
- Shutdown via `jl_atexit_hook(0)`

### GC Root Management

Julia's GC can collect objects C++ still references:

```cpp
void JuliaRuntime::AddGCRoot(jl_value_t* value) {
    gc_roots_.push_back(value);
    JL_GC_PUSH1(&value);  // Protect from GC
}
```

**Current limitation:**
The simplified implementation doesn't properly manage JL_GC_PUSH/POP scopes. A production version should use:

```cpp
// Better approach: maintain Julia-side array of roots
jl_value_t* gc_roots_array_;  // Julia array

void AddGCRoot(jl_value_t* value) {
    jl_array_ptr_1d_push(gc_roots_array_, value);
}
```

## Data Marshaling

### Type System Mapping

| C++ Type | Julia Type | Notes |
|----------|-----------|-------|
| `philote::Variable` | `Array{Float64}` | Flattened array |
| `philote::Variables` | `Dict{String, Array{Float64}}` | Map of arrays |
| `philote::Partials` | `Dict{String, Dict{String, Array}}` | Nested map |
| `std::vector<int64_t>` | `Vector{Int64}` | Shape vectors |
| `std::string` | `String` | Variable names |

### Variable to Julia Array

```cpp
jl_array_t* JuliaMarshal::ToJuliaArray(const Variable& var) {
    std::vector<size_t> shape = var.Shape();
    size_t ndims = shape.size();

    // Get Float64 array type
    jl_value_t* array_type = jl_apply_array_type(
        (jl_value_t*)jl_float64_type, ndims);

    // Allocate Julia array
    jl_array_t* arr = jl_alloc_array_nd(
        (jl_value_t*)array_type,
        shape.data(),
        ndims);

    // Copy data (column-major order)
    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < var.Size(); i++) {
        data[i] = var(i);
    }

    return arr;
}
```

**Key points:**
- Julia uses column-major ordering
- `jl_alloc_array_nd` allocates with shape
- Direct memory access via `jl_array_data`
- Data copy (not zero-copy)

### Julia Array to Variable

```cpp
void JuliaMarshal::FromJuliaArray(jl_array_t* array, Variable& var) {
    // Validation
    if (!jl_is_array(array)) {
        throw JuliaException("Value is not a Julia array");
    }

    // Get data pointer
    double* data = (double*)jl_array_data(array);
    size_t length = jl_array_len(array);

    // Size check
    if (length != var.Size()) {
        throw JuliaException("Array size mismatch");
    }

    // Copy data
    for (size_t i = 0; i < length; i++) {
        var(i) = data[i];
    }
}
```

### Dictionary Marshaling

```cpp
jl_value_t* JuliaMarshal::ToJuliaDict(const Variables& vars) {
    // Create empty Dict
    jl_function_t* dict_fn = jl_get_function(jl_base_module, "Dict");
    jl_value_t* dict = jl_call0(dict_fn);

    JL_GC_PUSH1(&dict);  // Protect during population

    for (const auto& [name, var] : vars) {
        jl_array_t* arr = ToJuliaArray(var);
        SetDictValue(dict, name, (jl_value_t*)arr);
    }

    JL_GC_POP();
    return dict;
}
```

**Dictionary operations:**
- Create via `Dict()` call
- Set via `setindex!(dict, value, key)`
- Get via `getindex(dict, key)`
- Keys via `keys(dict)` then `collect()`

## JuliaExplicitDiscipline Implementation

### Lifecycle Flow

```
Constructor
    ↓
Initialize Julia Runtime
    ↓
LoadDiscipline()
  - Load .jl file
  - Create instance
  - Cache function pointers
    ↓
Setup() [called by Philote]
  - Call Julia setup!()
  - ExtractMetadata()
    - Read inputs from metadata
    - Read outputs from metadata
    - Read partials from metadata
  - Populate C++ discipline
    ↓
Compute() [called by gRPC]
  - Marshal inputs to Julia
  - Call Julia compute()
  - Marshal outputs to C++
    ↓
Destructor
  - Remove GC roots
```

### Module Loading

```cpp
jl_module_t* JuliaRuntime::LoadModule(const std::string& filepath) {
    // Build include expression
    std::string expr = "include(\"" + filepath + "\")";

    // Evaluate
    jl_value_t* result = jl_eval_string(expr.c_str());
    CheckException();

    // Return Main module
    return jl_main_module;
}
```

**Why Main module?**
- `include()` evaluates in Main scope
- User types defined in Main
- Functions accessible from Main

### Function Pointer Caching

```cpp
void JuliaExplicitDiscipline::LoadDiscipline() {
    // ...

    // Cache function pointers (avoid repeated lookups)
    jl_value_t* philote_module = jl_eval_string("Philote");

    setup_fn_ = jl_get_function((jl_module_t*)philote_module, "setup!");
    compute_fn_ = jl_get_function((jl_module_t*)philote_module, "compute");
    compute_partials_fn_ = jl_get_function(
        (jl_module_t*)philote_module, "compute_partials");
    get_metadata_fn_ = jl_get_function(
        (jl_module_t*)philote_module, "get_metadata");
}
```

**Performance benefit:**
- Function lookup is expensive
- Cache once, reuse many times
- Especially important in hot paths

### Metadata Extraction

```cpp
void JuliaExplicitDiscipline::ExtractMetadata() {
    // Get metadata from Julia
    jl_value_t* meta = jl_call1(get_metadata_fn_, discipline_obj_);

    // Extract inputs (field 0)
    jl_value_t* inputs_dict = jl_get_nth_field(meta, 0);
    std::vector<std::string> input_names = JuliaMarshal::GetDictKeys(inputs_dict);

    for (const std::string& name : input_names) {
        jl_value_t* tuple = JuliaMarshal::GetDictValue(inputs_dict, name);

        // tuple = (shape, units)
        jl_value_t* shape_vec = jl_get_nth_field(tuple, 0);
        jl_value_t* units_str = jl_get_nth_field(tuple, 1);

        std::vector<int64_t> shape = JuliaMarshal::FromJuliaVector(shape_vec);
        std::string units(jl_string_ptr(units_str));

        // Add to C++ discipline
        AddInput(name, shape, units);
    }

    // Similar for outputs and partials...
}
```

**Metadata structure:**
```julia
struct DisciplineMetadata
    inputs::Dict{String, Tuple{Vector{Int64}, String}}   # field 0
    outputs::Dict{String, Tuple{Vector{Int64}, String}}  # field 1
    residuals::Dict{String, Tuple{Vector{Int64}, String}}  # field 2
    options::Dict{String, String}  # field 3
    partials::Vector{Tuple{String, String}}  # field 4
    name::String  # field 5
    version::String  # field 6
end
```

## Build System

### CMake Structure

```cmake
PhiloteJulia/
  CMakeLists.txt              # Main build file
  cmake/
    FindJulia.cmake           # Julia detection
  include/
    *.h                       # Public headers
  src/
    *.cpp                     # Implementation
  examples/
    CMakeLists.txt            # Examples build
    *.cpp                     # Example servers
```

### FindJulia.cmake

```cmake
# Find Julia executable
find_program(JULIA_EXECUTABLE julia)

# Get include directory
execute_process(
    COMMAND ${JULIA_EXECUTABLE} -E
        "joinpath(Sys.BINDIR, Base.INCLUDEDIR, \"julia\")"
    OUTPUT_VARIABLE JULIA_INCLUDE_DIRS
)

# Get library directory
execute_process(
    COMMAND ${JULIA_EXECUTABLE} -E
        "joinpath(Sys.BINDIR, Base.LIBDIR)"
    OUTPUT_VARIABLE JULIA_LIBRARY_DIR
)

# Find library
find_library(JULIA_LIBRARY
    NAMES julia libjulia
    PATHS ${JULIA_LIBRARY_DIR}
)
```

**Why execute_process?**
- Julia installation location varies
- Query Julia itself for paths
- Platform-independent

### Library Linking

```cmake
target_link_libraries(PhiloteJulia PUBLIC
    PhiloteCpp         # Philote infrastructure
    ${JULIA_LIBRARY}   # Julia runtime
    gRPC::grpc++       # gRPC
    protobuf::libprotobuf  # Protocol Buffers
)
```

## Exception Handling

### Julia to C++ Exception Translation

```cpp
void JuliaRuntime::CheckException() const {
    if (jl_exception_occurred()) {
        std::string msg = GetExceptionMessage();
        throw JuliaException(msg);
    }
}

std::string JuliaRuntime::GetExceptionMessage() const {
    jl_value_t* ex = jl_exception_occurred();

    // Call showerror to get string representation
    jl_value_t* string_val = jl_call2(
        jl_get_function(jl_base_module, "string"),
        jl_get_function(jl_base_module, "sprint"),
        jl_get_function(jl_base_module, "showerror")
    );

    if (jl_is_string(string_val)) {
        return std::string(jl_string_ptr(string_val));
    }

    return "Unknown Julia exception";
}
```

### Error Propagation

```
Julia Error
    ↓
jl_exception_occurred() != nullptr
    ↓
GetExceptionMessage()
    ↓
throw JuliaException(msg)
    ↓
C++ catch block
    ↓
gRPC Status::INTERNAL
    ↓
Client receives error
```

## Thread Safety

### Current Limitations

**Julia is single-threaded:**
- All Julia calls must be from initialization thread
- No concurrent Julia operations
- Thread-local state in Julia runtime

**Implications:**
- Server handles one request at a time
- No parallel discipline evaluations
- Acceptable for most MDO workflows

### Future Multi-threading

Potential approaches:
1. **Multiple Julia runtimes** (one per thread)
   - Complex initialization
   - Memory overhead

2. **Julia task-based parallelism** (within Julia)
   - Use `@threads` or `@async`
   - Keep C++ single-threaded

3. **Process-based parallelism**
   - Multiple server processes
   - Load balancer

## Performance Considerations

### Bottlenecks

1. **Julia compilation** (first run)
   - JIT compilation on first call
   - Solution: Precompilation, PackageCompiler

2. **Data marshaling**
   - Array copying overhead
   - Solution: Minimize large arrays, batch operations

3. **GC pauses**
   - Frequent allocations trigger GC
   - Solution: Pre-allocate, reuse arrays

### Optimization Strategies

**Function caching:**
```cpp
// Cache lookups (done once)
static jl_function_t* dict_fn = jl_get_function(jl_base_module, "Dict");

// Reuse in hot path
jl_value_t* dict = jl_call0(dict_fn);
```

**Pre-allocation:**
```julia
mutable struct MyDiscipline <: ExplicitDiscipline
    # Pre-allocate working arrays
    work_array::Vector{Float64}

    function MyDiscipline()
        new(zeros(1000))  # Reuse this
    end
end

function compute(d::MyDiscipline, inputs)
    # Reuse pre-allocated array
    d.work_array .= some_computation(inputs)
    # ...
end
```

**Batching:**
```cpp
// Batch multiple evaluations
for (int i = 0; i < n; i++) {
    // Prepare all inputs
}
// Single Julia call with all inputs
// Process all outputs
```

## Contributing

### Development Workflow

1. **Fork and clone**
   ```bash
   git clone https://github.com/yourusername/Philote-Julia.git
   cd Philote-Julia
   ```

2. **Create branch**
   ```bash
   git checkout -b feature/my-feature
   ```

3. **Make changes**
   - Add tests
   - Update documentation
   - Follow style guide

4. **Test**
   ```bash
   julia --project=. test/runtests.jl
   cd cpp/build && ctest
   ```

5. **Commit**
   ```bash
   git commit -m "Add feature X

   - Detailed description
   - Why this change
   - Breaking changes (if any)"
   ```

6. **Submit PR**
   - Clear description
   - Link to issues
   - Screenshots if UI changes

### Code Style

**Julia:**
- Follow [Blue Style Guide](https://github.com/invenia/BlueStyle)
- 4-space indentation
- Snake_case for functions

**C++:**
- Follow [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)
- CamelCase for classes
- snake_case for functions

### Testing Guidelines

**Every PR must include:**
- Unit tests for new functions
- Integration test if adding features
- Documentation updates
- CHANGELOG entry

## Debugging

### Julia Side

```julia
# Enable debug printing
@debug "Input values" x y

# Breakpoint (with Debugger.jl)
using Debugger
@bp

# Stack traces
try
    # ...
catch e
    @error "Error occurred" exception=(e, catch_backtrace())
end
```

### C++ Side

```cpp
// Print Julia values
jl_value_t* val = ...;
jl_call1(jl_get_function(jl_base_module, "println"), val);

// GDB debugging
# Compile with -g
cmake .. -DCMAKE_BUILD_TYPE=Debug

# Run with GDB
gdb ./bin/paraboloid_server
```

### Common Issues

**Segfault on Julia call:**
- Check GC roots
- Verify types before casting
- Use `jl_typeof()` to inspect

**Type mismatch:**
```cpp
// Check type
if (!jl_is_array(value)) {
    throw std::runtime_error("Expected array");
}

// Print type
jl_value_t* type = jl_typeof(value);
jl_call1(jl_get_function(jl_base_module, "println"), type);
```

## Extending the System

### Adding New Variable Types

To support discrete variables:

1. **Julia side:**
```julia
# Add discrete_data field to metadata
discrete_inputs::Dict{String, Tuple{Vector{Int64}, String}}
```

2. **C++ side:**
```cpp
// Add marshaling
jl_array_t* ToJuliaIntArray(const Variable& var);
void FromJuliaIntArray(jl_array_t* array, Variable& var);
```

### Adding Implicit Support

1. **Create JuliaImplicitDiscipline class**
2. **Inherit from ImplicitDiscipline**
3. **Implement residual methods**
4. **Extract residual metadata**

See `IMPLEMENTATION_ROADMAP.md` for details.

## References

- [Julia C API Documentation](https://docs.julialang.org/en/v1/base/c/)
- [Julia Embedding Manual](https://docs.julialang.org/en/v1/manual/embedding/)
- [Philote-Cpp Documentation](../../Philote-Cpp/README.md)
- [gRPC C++ Guide](https://grpc.io/docs/languages/cpp/)

## Next Steps

- Try modifying `examples/paraboloid.jl`
- Add a new discipline type
- Implement zero-copy marshaling
- Add multi-threading support
- Write a pure Julia server
