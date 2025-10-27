# C++ Wrapper for Julia Disciplines

This directory contains C++ code that wraps Julia Philote disciplines and serves them via gRPC using the Philote-Cpp infrastructure.

## Overview

The C++ wrapper enables you to:
1. Write disciplines in Julia using the high-level Philote.jl interface
2. Wrap them with minimal C++ code
3. Serve them via gRPC to any Philote client

This approach combines:
- ✓ Julia's ease of use for mathematical modeling
- ✓ C++'s performance and gRPC infrastructure
- ✓ Full Philote protocol compatibility
- ✓ Interoperability with any Philote client (C++, Python, etc.)

## Architecture

```
Julia Discipline (paraboloid.jl)
        ↓
JuliaExplicitDiscipline (C++ wrapper)
        ↓
Philote-Cpp gRPC Server
        ↓
Network (gRPC/Protobuf)
        ↓
Any Philote Client
```

## Components

### Core Components

#### `julia_runtime.h/cpp`
Singleton managing the Julia runtime lifecycle:
- Initialization and shutdown
- Module loading
- GC root management
- Exception handling

#### `julia_marshal.h/cpp`
Data marshaling layer for type conversions:
- `Variable` ↔ `Array{Float64}`
- `Variables` ↔ `Dict{String, Array{Float64}}`
- `Partials` ↔ `Dict{String, Dict{String, Array{Float64}}}`

#### `julia_explicit.h/cpp`
Main wrapper class for explicit disciplines:
- Loads Julia discipline at runtime
- Extracts metadata automatically
- Implements Philote Discipline interface
- Handles all RPC calls

## Prerequisites

- **Julia** ≥ 1.6
- **Philote-Cpp** (built and installed)
- **CMake** ≥ 3.23
- **gRPC** and **Protocol Buffers**
- C++17 compatible compiler

## Building

### 1. Install Dependencies

**Julia:**
```bash
# macOS
brew install julia

# Linux
wget https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-1.9.3-linux-x86_64.tar.gz
tar -xvzf julia-1.9.3-linux-x86_64.tar.gz
sudo mv julia-1.9.3 /opt/
sudo ln -s /opt/julia-1.9.3/bin/julia /usr/local/bin/julia
```

**Philote-Cpp:**
```bash
cd ../Philote-Cpp
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/local
cmake --build .
cmake --install .
```

### 2. Build PhiloteJulia

```bash
cd Philote-Julia/cpp
mkdir build && cd build

cmake .. \
    -DPHILOTE_CPP_DIR=../../Philote-Cpp \
    -DBUILD_EXAMPLES=ON

cmake --build .
```

### 3. Run Example

```bash
# From the build directory
./bin/paraboloid_server
```

The server will load the Julia paraboloid discipline and start listening on `localhost:50051`.

### 4. Run Tests

Build with tests enabled:

```bash
cd Philote-Julia/cpp
mkdir build && cd build

cmake .. \
    -DPHILOTE_CPP_DIR=../../Philote-Cpp \
    -DBUILD_TESTS=ON

cmake --build .
```

Run tests with CTest:

```bash
ctest --output-on-failure
```

Or run the test executable directly:

```bash
./philote_julia_tests
```

The test suite includes:
- **JuliaRuntime tests**: Initialization, module loading, GC management, exception handling
- **JuliaMarshal tests**: Bidirectional data conversion, round-trip tests for scalars/vectors/matrices/dictionaries
- **JuliaExplicitDiscipline tests**: Full integration tests using the paraboloid example, gradient accuracy checks

## Usage

### 1. Create a Julia Discipline

```julia
# my_discipline.jl
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    MyDiscipline() = new()
end

function Philote.setup!(d::MyDiscipline)
    Philote.add_input!(d, "x", [1], "m")
    Philote.add_output!(d, "y", [1], "m**2")
    Philote.declare_partials!(d, "y", "x")
end

function Philote.compute(d::MyDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = x^2
    return Dict("y" => [y])
end

function Philote.compute_partials(d::MyDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    dy_dx = 2.0 * x
    return Dict("y" => Dict("x" => [dy_dx]))
end
```

### 2. Create a C++ Server

```cpp
#include "julia_explicit.h"
#include <grpc++/grpc++.h>

int main() {
    std::string address("localhost:50051");

    // Create Julia-wrapped discipline
    philote::JuliaExplicitDiscipline discipline(
        "path/to/my_discipline.jl",
        "MyDiscipline"
    );

    // Build gRPC server
    grpc::ServerBuilder builder;
    builder.AddListeningPort(address, grpc::InsecureServerCredentials());
    discipline.RegisterServices(builder);

    // Start server
    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
    std::cout << "Server listening on " << address << std::endl;

    server->Wait();
    return 0;
}
```

### 3. Build and Run

Add to `CMakeLists.txt`:
```cmake
add_executable(my_server my_server.cpp)
target_link_libraries(my_server PhiloteJulia)
```

Build and run:
```bash
cmake --build .
./my_server
```

### 4. Connect with a Client

```cpp
// C++ client
#include <philote/explicit.h>

int main() {
    philote::ExplicitClient client;
    auto channel = grpc::CreateChannel("localhost:50051",
                                      grpc::InsecureChannelCredentials());
    client.ConnectChannel(channel);
    client.Setup();

    // Set inputs
    philote::Variables inputs;
    inputs["x"] = philote::Variable(philote::kInput, {1});
    inputs["x"](0) = 3.0;

    // Compute
    auto outputs = client.ComputeFunction(inputs);
    std::cout << "y = " << outputs["f_xy"](0) << std::endl;

    return 0;
}
```

## API Reference

### JuliaExplicitDiscipline

```cpp
class JuliaExplicitDiscipline : public philote::ExplicitDiscipline {
public:
    /**
     * @brief Construct wrapper for Julia discipline
     *
     * @param filepath Path to .jl file
     * @param typename Julia type name (must be ExplicitDiscipline subtype)
     */
    JuliaExplicitDiscipline(const std::string& filepath,
                           const std::string& typename);

    // Inherited from ExplicitDiscipline:
    void Setup() override;
    void SetupPartials() override;
    void Compute(const Variables& inputs, Variables& outputs) override;
    void ComputePartials(const Variables& inputs, Partials& partials) override;
};
```

### JuliaRuntime (Singleton)

```cpp
class JuliaRuntime {
public:
    static JuliaRuntime& Instance();

    void Initialize();
    void Shutdown();
    bool IsInitialized() const;

    jl_module_t* LoadModule(const std::string& filepath);
    jl_function_t* GetFunction(jl_module_t* module, const std::string& name);

    void AddGCRoot(jl_value_t* value);
    void RemoveGCRoot(jl_value_t* value);

    void CheckException() const;
};
```

### JuliaMarshal

```cpp
class JuliaMarshal {
public:
    // C++ → Julia
    static jl_array_t* ToJuliaArray(const Variable& var);
    static jl_value_t* ToJuliaDict(const Variables& vars);
    static jl_value_t* ToJuliaDict(const Partials& partials);

    // Julia → C++
    static void FromJuliaArray(jl_array_t* array, Variable& var);
    static void FromJuliaDict(jl_value_t* dict, Variables& vars);
    static void FromJuliaDict(jl_value_t* dict, Partials& partials);
};
```

## CMake Integration

To use PhiloteJulia in your project:

```cmake
find_package(PhiloteJulia REQUIRED)

add_executable(my_app main.cpp)
target_link_libraries(my_app PhiloteJulia::PhiloteJulia)
```

Or as a subdirectory:

```cmake
add_subdirectory(path/to/Philote-Julia/cpp)

add_executable(my_app main.cpp)
target_link_libraries(my_app PhiloteJulia)
```

## Examples

### Example 1: Paraboloid

See `examples/paraboloid_server.cpp` for a complete example wrapping the paraboloid discipline.

Run:
```bash
cd build
./bin/paraboloid_server
```

### Example 2: Custom Discipline

Create your discipline in Julia, then wrap it:

```cpp
philote::JuliaExplicitDiscipline discipline(
    "../my_models/aerodynamics.jl",
    "WingAnalysis"
);
```

## Troubleshooting

### Julia Not Found

If CMake can't find Julia:
```bash
cmake .. -DJULIA_EXECUTABLE=/path/to/julia
```

### Module Load Errors

Ensure Julia can find the Philote module:
```julia
# Test manually
julia> push!(LOAD_PATH, "/path/to/Philote-Julia")
julia> using Philote
```

### Runtime Errors

Enable Julia exception details:
```cpp
try {
    discipline.Compute(inputs, outputs);
} catch (const philote::JuliaException& e) {
    std::cerr << "Julia error: " << e.what() << std::endl;
}
```

### GC Issues

If you see segfaults related to Julia objects:
- Ensure all Julia values used in C++ are GC-rooted
- Use `JL_GC_PUSH/POP` macros for stack protection
- Call `JuliaRuntime::AddGCRoot()` for long-lived objects

## Performance Tips

1. **Precompile Julia code**: Julia's first-run compilation can be slow
2. **Batch operations**: Group multiple evaluations when possible
3. **Minimize marshaling**: Large arrays incur copy overhead
4. **Use GC wisely**: Protect objects from GC but clean up when done

## Limitations

- **Thread Safety**: All Julia calls must be from the initialization thread
- **GC Overhead**: Frequent allocations can trigger GC pauses
- **Startup Time**: Julia initialization adds ~1-2 seconds

## Contributing

Contributions welcome! Areas for improvement:
- Implicit discipline support
- Better error messages
- Performance optimization
- Zero-copy marshaling
- Multi-threading support

## License

See [LICENSE](../LICENSE) file.

## Related Documentation

- [Philote-Julia README](../README.md)
- [Implementation Roadmap](../IMPLEMENTATION_ROADMAP.md)
- [Philote-Cpp Documentation](../../Philote-Cpp/README.md)
