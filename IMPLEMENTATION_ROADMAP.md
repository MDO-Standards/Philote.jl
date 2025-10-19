# C++ Wrapper Implementation Roadmap

This document outlines the plan for implementing C++ wrappers in Philote-Cpp that embed Julia disciplines and serve them via gRPC.

## Overview

The C++ wrapper will:
1. Embed the Julia runtime using the Julia C API
2. Load Julia discipline modules and instantiate discipline objects
3. Marshal data between C++ `philote::Variables` and Julia `Dict{String, Array{Float64}}`
4. Wrap Julia disciplines as Philote gRPC servers

## Architecture

```
┌─────────────────────────────────────────────────┐
│           gRPC Client (Any Language)            │
└────────────────┬────────────────────────────────┘
                 │ Philote Protocol (gRPC)
┌────────────────┴────────────────────────────────┐
│         C++ Server (Philote-Cpp)                │
│  ┌───────────────────────────────────────────┐  │
│  │   JuliaExplicitDiscipline / Implicit      │  │
│  │   (inherits from ExplicitDiscipline)      │  │
│  └──────────────┬────────────────────────────┘  │
│                 │                                │
│  ┌──────────────┴────────────────────────────┐  │
│  │      JuliaRuntime (Singleton)             │  │
│  │  - Julia initialization                   │  │
│  │  - Module loading                         │  │
│  │  - GC root management                     │  │
│  └──────────────┬────────────────────────────┘  │
│                 │                                │
│  ┌──────────────┴────────────────────────────┐  │
│  │      Data Marshaling Layer                │  │
│  │  - Variables → Julia Dict{String, Array}  │  │
│  │  - Julia Dict → Variables                 │  │
│  │  - Shape/type conversion                  │  │
│  └───────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┘
                 │ Julia C API (jl_call, etc.)
┌────────────────┴────────────────────────────────┐
│              Julia Runtime                      │
│  ┌───────────────────────────────────────────┐  │
│  │   User Discipline (e.g., Paraboloid)      │  │
│  │   - setup!()                              │  │
│  │   - compute()                             │  │
│  │   - compute_partials()                    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Implementation Steps

### Phase 1: Julia Runtime Management

**File:** `Philote-Cpp/include/julia_runtime.h`

```cpp
namespace philote {

class JuliaRuntime {
public:
    // Singleton access
    static JuliaRuntime& Instance();

    // Lifecycle management
    void Initialize();
    void Shutdown();
    bool IsInitialized() const;

    // Module loading
    jl_module_t* LoadModule(const std::string& filepath);
    jl_function_t* GetFunction(jl_module_t* module, const std::string& name);

    // GC root management
    void AddGCRoot(jl_value_t* value);
    void RemoveGCRoot(jl_value_t* value);

    // Error handling
    bool HasException() const;
    std::string GetExceptionMessage() const;
    void ClearException();

private:
    JuliaRuntime();
    ~JuliaRuntime();
    JuliaRuntime(const JuliaRuntime&) = delete;
    JuliaRuntime& operator=(const JuliaRuntime&) = delete;

    bool initialized_;
    std::vector<jl_value_t*> gc_roots_;
};

} // namespace philote
```

**Implementation notes:**
- Use `jl_init()` / `jl_atexit_hook(0)` for initialization/shutdown
- Thread safety: Julia must be called from the thread that initialized it
- GC roots needed to prevent Julia from collecting C++-referenced objects
- Exception handling via `jl_exception_occurred()`

### Phase 2: Data Marshaling Layer

**File:** `Philote-Cpp/include/julia_marshal.h`

```cpp
namespace philote {

class JuliaMarshal {
public:
    // C++ → Julia conversions
    static jl_value_t* ToJuliaDict(const Variables& vars);
    static jl_value_t* ToJuliaDict(const Partials& partials);
    static jl_array_t* ToJuliaArray(const Variable& var);

    // Julia → C++ conversions
    static void FromJuliaDict(jl_value_t* dict, Variables& vars);
    static void FromJuliaDict(jl_value_t* dict, Partials& partials);
    static void FromJuliaArray(jl_array_t* array, Variable& var);

    // Shape and metadata helpers
    static jl_value_t* ToJuliaVector(const std::vector<int64_t>& vec);
    static std::vector<int64_t> FromJuliaVector(jl_value_t* vec);

private:
    // Julia type references (cached for performance)
    static jl_datatype_t* dict_type_;
    static jl_datatype_t* array_type_;
};

} // namespace philote
```

**Key conversions:**

```cpp
// Variables → Dict{String, Array{Float64}}
jl_value_t* ToJuliaDict(const Variables& vars) {
    jl_function_t* dict_fn = jl_get_function(jl_base_module, "Dict");
    jl_value_t* dict = jl_call0(dict_fn);

    for (const auto& [name, var] : vars) {
        jl_array_t* arr = ToJuliaArray(var);
        // dict[name] = arr
        jl_set_nth_field(dict, ...);
    }

    return dict;
}

// Variable → Array{Float64}
jl_array_t* ToJuliaArray(const Variable& var) {
    std::vector<size_t> shape = var.Shape();
    jl_value_t* array_type = jl_apply_array_type(
        (jl_value_t*)jl_float64_type, shape.size());

    jl_array_t* arr = jl_alloc_array_nd(
        array_type, shape.data(), shape.size());

    // Copy data
    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < var.Size(); i++) {
        data[i] = var(i);
    }

    return arr;
}
```

### Phase 3: JuliaExplicitDiscipline Class

**File:** `Philote-Cpp/include/julia_explicit.h`

```cpp
namespace philote {

class JuliaExplicitDiscipline : public ExplicitDiscipline {
public:
    JuliaExplicitDiscipline(const std::string& filepath,
                           const std::string& typename);
    virtual ~JuliaExplicitDiscipline();

    // Discipline lifecycle (override from base)
    void Initialize() override;
    void Setup() override;
    void SetupPartials() override;

    // Computation (override from base)
    void Compute(const Variables& inputs, Variables& outputs) override;
    void ComputePartials(const Variables& inputs, Partials& partials) override;

private:
    void LoadDiscipline();
    void ExtractMetadata();
    void CallSetup();

    std::string filepath_;
    std::string typename_;
    jl_module_t* module_;
    jl_value_t* discipline_obj_;
    jl_function_t* setup_fn_;
    jl_function_t* compute_fn_;
    jl_function_t* compute_partials_fn_;
};

} // namespace philote
```

**Implementation flow:**

```cpp
JuliaExplicitDiscipline::JuliaExplicitDiscipline(
    const std::string& filepath,
    const std::string& typename)
    : filepath_(filepath), typename_(typename),
      module_(nullptr), discipline_obj_(nullptr) {

    JuliaRuntime::Instance().Initialize();
    LoadDiscipline();
}

void JuliaExplicitDiscipline::LoadDiscipline() {
    auto& runtime = JuliaRuntime::Instance();

    // Load Julia module
    module_ = runtime.LoadModule(filepath_);

    // Get constructor function
    jl_function_t* constructor = runtime.GetFunction(module_, typename_);

    // Create discipline instance
    discipline_obj_ = jl_call0(constructor);
    runtime.AddGCRoot(discipline_obj_);

    // Cache function pointers
    setup_fn_ = runtime.GetFunction(module_, "setup!");
    compute_fn_ = runtime.GetFunction(module_, "compute");
    compute_partials_fn_ = runtime.GetFunction(module_, "compute_partials");
}

void JuliaExplicitDiscipline::Setup() {
    // Call setup!(discipline)
    jl_call1(setup_fn_, discipline_obj_);

    // Extract metadata from Julia
    ExtractMetadata();
}

void JuliaExplicitDiscipline::ExtractMetadata() {
    // Call Philote.get_metadata(discipline)
    jl_function_t* get_meta_fn = JuliaRuntime::Instance()
        .GetFunction(module_, "get_metadata");
    jl_value_t* meta = jl_call1(get_meta_fn, discipline_obj_);

    // Extract inputs
    jl_value_t* inputs_dict = jl_get_nth_field(meta, 0);
    // For each entry: add_input(name, shape, units)

    // Extract outputs
    jl_value_t* outputs_dict = jl_get_nth_field(meta, 1);
    // For each entry: add_output(name, shape, units)

    // Extract partials
    jl_value_t* partials_vec = jl_get_nth_field(meta, 4);
    // For each entry: declare_partials(output, input)
}

void JuliaExplicitDiscipline::Compute(const Variables& inputs,
                                     Variables& outputs) {
    // Convert inputs to Julia dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    // Call compute(discipline, inputs)
    jl_value_t* outputs_dict = jl_call2(compute_fn_,
                                       discipline_obj_,
                                       inputs_dict);

    // Convert Julia dict to outputs
    JuliaMarshal::FromJuliaDict(outputs_dict, outputs);
}

void JuliaExplicitDiscipline::ComputePartials(const Variables& inputs,
                                             Partials& partials) {
    // Convert inputs to Julia dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    // Call compute_partials(discipline, inputs)
    jl_value_t* partials_dict = jl_call2(compute_partials_fn_,
                                        discipline_obj_,
                                        inputs_dict);

    // Convert nested Julia dict to partials
    JuliaMarshal::FromJuliaDict(partials_dict, partials);
}
```

### Phase 4: JuliaImplicitDiscipline Class

**File:** `Philote-Cpp/include/julia_implicit.h`

Similar to `JuliaExplicitDiscipline` but:
- Inherits from `ImplicitDiscipline`
- Implements `ComputeResiduals()`, `SolveResiduals()`, `ComputeResidualPartials()`
- Calls Julia's `compute_residuals()`, `solve_residuals()`, etc.

### Phase 5: CMake Integration

**File:** `Philote-Cpp/cmake/FindJulia.cmake`

```cmake
# Find Julia installation
find_program(JULIA_EXECUTABLE julia DOC "Julia executable")

if(JULIA_EXECUTABLE)
    # Get Julia version
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} --version
        OUTPUT_VARIABLE JULIA_VERSION_STRING
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # Get Julia include directories
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} -E "joinpath(Sys.BINDIR, Base.INCLUDEDIR, \"julia\")"
        OUTPUT_VARIABLE JULIA_INCLUDE_DIRS
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # Get Julia library path
    execute_process(
        COMMAND ${JULIA_EXECUTABLE} -E "joinpath(Sys.BINDIR, Base.LIBDIR)"
        OUTPUT_VARIABLE JULIA_LIBRARY_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    find_library(JULIA_LIBRARY
        NAMES julia
        PATHS ${JULIA_LIBRARY_DIR}
        NO_DEFAULT_PATH
    )

    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(Julia
        REQUIRED_VARS JULIA_LIBRARY JULIA_INCLUDE_DIRS
        VERSION_VAR JULIA_VERSION_STRING
    )
endif()
```

**Update:** `Philote-Cpp/CMakeLists.txt`

```cmake
option(BUILD_JULIA_SUPPORT "Build Julia discipline support" OFF)

if(BUILD_JULIA_SUPPORT)
    find_package(Julia REQUIRED)

    add_library(PhiloteJulia STATIC
        src/julia/julia_runtime.cpp
        src/julia/julia_marshal.cpp
        src/julia/julia_explicit.cpp
        src/julia/julia_implicit.cpp
    )

    target_include_directories(PhiloteJulia PUBLIC
        ${JULIA_INCLUDE_DIRS}
    )

    target_link_libraries(PhiloteJulia PUBLIC
        PhiloteCpp
        ${JULIA_LIBRARY}
    )
endif()
```

### Phase 6: Example Server

**File:** `Philote-Cpp/examples/julia_paraboloid/julia_paraboloid_server.cpp`

```cpp
#include <philote/julia_explicit.h>
#include <grpc++/grpc++.h>
#include <iostream>

int main() {
    std::string address("localhost:50051");

    // Path to Julia discipline file (relative to execution directory)
    std::string discipline_path =
        "../../../Philote-Julia/examples/paraboloid.jl";

    // Create Julia-wrapped discipline
    philote::JuliaExplicitDiscipline discipline(
        discipline_path,
        "ParaboloidDiscipline"
    );

    // Build and start gRPC server
    grpc::ServerBuilder builder;
    builder.AddListeningPort(address, grpc::InsecureServerCredentials());
    discipline.RegisterServices(builder);

    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());

    std::cout << "Julia Paraboloid server listening on " << address << std::endl;
    std::cout << "Julia discipline loaded from: " << discipline_path << std::endl;

    server->Wait();

    return 0;
}
```

**CMakeLists.txt for example:**

```cmake
if(BUILD_JULIA_SUPPORT)
    add_executable(julia_paraboloid_server
        julia_paraboloid_server.cpp
    )

    target_link_libraries(julia_paraboloid_server
        PhiloteJulia
        PhiloteCpp
        gRPC::grpc++
    )
endif()
```

### Phase 7: Testing

#### Unit Tests

**File:** `Philote-Cpp/test/julia_marshal_test.cpp`

```cpp
TEST(JuliaMarshalTest, VariableToJuliaArray) {
    JuliaRuntime::Instance().Initialize();

    // Create C++ variable
    philote::Variable var(philote::kInput, {2, 3});
    for (size_t i = 0; i < 6; i++) {
        var(i) = i * 1.5;
    }

    // Convert to Julia
    jl_array_t* arr = philote::JuliaMarshal::ToJuliaArray(var);

    // Verify shape
    EXPECT_EQ(jl_array_ndims(arr), 2);
    EXPECT_EQ(jl_array_dim(arr, 0), 2);
    EXPECT_EQ(jl_array_dim(arr, 1), 3);

    // Verify data
    double* data = (double*)jl_array_data(arr);
    for (size_t i = 0; i < 6; i++) {
        EXPECT_DOUBLE_EQ(data[i], i * 1.5);
    }
}

TEST(JuliaMarshalTest, JuliaArrayToVariable) {
    JuliaRuntime::Instance().Initialize();

    // Create Julia array
    jl_value_t* atype = jl_apply_array_type((jl_value_t*)jl_float64_type, 1);
    jl_array_t* arr = jl_alloc_array_1d(atype, 3);
    double* data = (double*)jl_array_data(arr);
    data[0] = 1.0;
    data[1] = 2.0;
    data[2] = 3.0;

    // Convert to C++
    philote::Variable var(philote::kInput, {3});
    philote::JuliaMarshal::FromJuliaArray(arr, var);

    // Verify
    EXPECT_DOUBLE_EQ(var(0), 1.0);
    EXPECT_DOUBLE_EQ(var(1), 2.0);
    EXPECT_DOUBLE_EQ(var(2), 3.0);
}
```

#### Integration Tests

**File:** `Philote-Cpp/test/julia_discipline_test.cpp`

```cpp
TEST(JuliaDisciplineTest, ParaboloidCompute) {
    std::string discipline_path = "path/to/paraboloid.jl";
    philote::JuliaExplicitDiscipline discipline(
        discipline_path, "ParaboloidDiscipline");

    discipline.Setup();

    // Create inputs
    philote::Variables inputs;
    inputs["x"] = philote::Variable(philote::kInput, {1});
    inputs["y"] = philote::Variable(philote::kInput, {1});
    inputs["x"](0) = 1.0;
    inputs["y"](0) = 2.0;

    // Compute
    philote::Variables outputs;
    discipline.Compute(inputs, outputs);

    // Expected: (1-3)^2 + 1*2 + (2+4)^2 - 3 = 4 + 2 + 36 - 3 = 39
    EXPECT_DOUBLE_EQ(outputs["f_xy"](0), 39.0);
}

TEST(JuliaDisciplineTest, ParaboloidGradients) {
    std::string discipline_path = "path/to/paraboloid.jl";
    philote::JuliaExplicitDiscipline discipline(
        discipline_path, "ParaboloidDiscipline");

    discipline.Setup();
    discipline.SetupPartials();

    // Create inputs
    philote::Variables inputs;
    inputs["x"] = philote::Variable(philote::kInput, {1});
    inputs["y"] = philote::Variable(philote::kInput, {1});
    inputs["x"](0) = 1.0;
    inputs["y"](0) = 2.0;

    // Compute partials
    philote::Partials partials;
    discipline.ComputePartials(inputs, partials);

    // Expected: df/dx = 2(1-3) + 2 = -2
    //          df/dy = 2(2+4) + 1 = 13
    EXPECT_DOUBLE_EQ(partials["f_xy"]["x"](0), -2.0);
    EXPECT_DOUBLE_EQ(partials["f_xy"]["y"](0), 13.0);
}
```

#### Interoperability Tests

Test Julia server with C++ client:

```cpp
TEST(InteropTest, CppClientJuliaServer) {
    // Start Julia server in background thread
    std::thread server_thread([]() {
        philote::JuliaExplicitDiscipline discipline(...);
        // Start server
    });

    // Give server time to start
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // Connect C++ client
    philote::ExplicitClient client;
    client.ConnectChannel(...);

    // Test computation
    philote::Variables inputs;
    // ... setup inputs ...
    philote::Variables outputs = client.ComputeFunction(inputs);

    // Verify results
    EXPECT_DOUBLE_EQ(outputs["f_xy"](0), expected_value);

    server_thread.join();
}
```

## Error Handling Strategy

```cpp
class JuliaException : public std::runtime_error {
public:
    explicit JuliaException(const std::string& msg)
        : std::runtime_error("Julia error: " + msg) {}
};

// In each Julia call:
void CheckJuliaException() {
    if (jl_exception_occurred()) {
        jl_value_t* ex = jl_exception_occurred();
        jl_value_t* msg = jl_get_nth_field(ex, 0);
        std::string error_msg = jl_string_ptr(msg);
        throw JuliaException(error_msg);
    }
}
```

## Performance Considerations

1. **GC Pressure**: Minimize allocations in hot paths
2. **Data Copying**: Consider zero-copy approaches where possible
3. **Function Caching**: Cache Julia function pointers after first lookup
4. **Thread Safety**: Ensure all Julia calls from same thread
5. **Precompilation**: Use Julia's precompilation to reduce startup time

## Build Instructions

```bash
# In Philote-Cpp directory
mkdir build && cd build
cmake .. -DBUILD_JULIA_SUPPORT=ON -DBUILD_EXAMPLES=ON
cmake --build .

# Run Julia paraboloid server
./examples/julia_paraboloid/julia_paraboloid_server
```

## Next Steps

1. Implement JuliaRuntime singleton
2. Implement data marshaling layer
3. Implement JuliaExplicitDiscipline
4. Add CMake integration
5. Create example server
6. Write tests
7. Implement JuliaImplicitDiscipline
8. Add documentation

## References

- [Julia Embedding Manual](https://docs.julialang.org/en/v1/manual/embedding/)
- [Julia C API Reference](https://docs.julialang.org/en/v1/base/c/)
- [Philote-Cpp Documentation](../Philote-Cpp/README.md)
