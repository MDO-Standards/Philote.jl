# Philote-Julia

Julia interface for creating Philote MDO (Multidisciplinary Design Optimization) disciplines.

## Overview

This library provides tools for creating analysis servers to host disciplines written in Julia. It works in conjunction with [Philote-Cpp](../Philote-Cpp) to enable Julia functions to be wrapped and served via gRPC using the Philote protocol.

## Architecture

The Philote-Julia library uses a hybrid approach:

- **Julia Interface** (this library): Defines the discipline interface and provides utilities for implementing disciplines in Julia
- **C++ Wrapper** (in Philote-Cpp): Embeds the Julia runtime and wraps Julia disciplines as Philote gRPC servers

This approach leverages:
- ✓ Existing stable Philote-Cpp infrastructure (gRPC, Protocol Buffers)
- ✓ Julia's high-level syntax for implementing disciplines
- ✓ Full Philote protocol compatibility
- ✓ Minimal dependencies (just Julia base runtime)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/Philote-Julia.git
cd Philote-Julia
```

2. Activate the Julia environment:
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## Creating a Discipline

### 1. Define Your Discipline Type

Subtype either `ExplicitDiscipline` or `ImplicitDiscipline`:

```julia
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    # Add discipline-specific fields
    scale_factor::Float64

    function MyDiscipline()
        new(1.0)
    end
end
```

### 2. Implement `setup!`

Declare inputs, outputs, options, and partials:

```julia
function Philote.setup!(discipline::MyDiscipline)
    # Declare options
    Philote.add_option!(discipline, "scale_factor", "float")

    # Declare inputs
    Philote.add_input!(discipline, "x", [1], "m")  # scalar
    Philote.add_input!(discipline, "y", [2, 2], "m")  # 2x2 matrix

    # Declare outputs
    Philote.add_output!(discipline, "f", [1], "m**2")

    # Declare partials (optional, for gradient-based optimization)
    Philote.declare_partials!(discipline, "f", "x")
    Philote.declare_partials!(discipline, "f", "y")
end
```

### 3. Implement `compute`

Define the forward computation:

```julia
function Philote.compute(discipline::MyDiscipline,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y_matrix = reshape(inputs["y"], 2, 2)

    # Your computation here
    f = discipline.scale_factor * (x + sum(y_matrix))

    return Dict("f" => [f])
end
```

### 4. Implement `compute_partials` (Optional)

Provide analytical gradients:

```julia
function Philote.compute_partials(discipline::MyDiscipline,
                                  inputs::Dict{String, <:AbstractArray{Float64}})
    # Compute derivatives
    df_dx = discipline.scale_factor
    df_dy = fill(discipline.scale_factor, 4)  # Flattened 2x2 matrix

    return Dict(
        "f" => Dict(
            "x" => [df_dx],
            "y" => df_dy
        )
    )
end
```

## Example: Paraboloid Discipline

See [`examples/paraboloid.jl`](examples/paraboloid.jl) for a complete example implementing the paraboloid function:

```
f(x, y) = (x - 3)² + xy + (y + 4)² - 3
```

Run the example:

```bash
julia examples/paraboloid.jl
```

## Discipline Types

### Explicit Disciplines

For analyses of the form `outputs = f(inputs)`.

**Required methods:**
- `setup!(discipline)`
- `compute(discipline, inputs)`

**Optional methods:**
- `compute_partials(discipline, inputs)`

### Implicit Disciplines

For analyses with residual equations that must be solved iteratively.

**Required methods:**
- `setup!(discipline)`
- `compute_residuals(discipline, inputs)`
- `solve_residuals(discipline, inputs)`

**Optional methods:**
- `compute_residual_partials(discipline, inputs)`

## API Reference

### Discipline Declaration

- `add_input!(discipline, name, shape, units)` - Declare an input variable
- `add_output!(discipline, name, shape, units)` - Declare an output variable
- `add_residual!(discipline, name, shape, units)` - Declare a residual (implicit only)
- `add_option!(discipline, name, type)` - Declare a configuration option
- `declare_partials!(discipline, output, input)` - Declare gradient availability

### Data Types

**Shapes:** Vector of integers, e.g.:
- `[1]` - scalar
- `[3]` - 1D array of length 3
- `[2, 3]` - 2×3 matrix

**Units:** String representation of physical units, e.g.:
- `"m"` - meters
- `"kg"` - kilograms
- `"m**2"` - square meters
- `"m/s"` - meters per second

**Option Types:**
- `"float"` - Floating point number
- `"int"` - Integer
- `"bool"` - Boolean
- `"string"` - String

### Metadata Access

```julia
meta = Philote.get_metadata(discipline)
meta.name = "MyDiscipline"
meta.version = "1.0.0"
```

## C++ Wrapper Integration

The `cpp/` directory contains a complete C++ wrapper that embeds Julia disciplines in gRPC servers.

### Quick Start

1. **Write your Julia discipline** (as shown above)

2. **Build the C++ wrapper:**
```bash
cd cpp
mkdir build && cd build
cmake .. -DPHILOTE_CPP_DIR=../../Philote-Cpp -DBUILD_EXAMPLES=ON
cmake --build .
```

3. **Run the example server:**
```bash
./bin/paraboloid_server
```

The server loads `examples/paraboloid.jl` and serves it via gRPC on `localhost:50051`.

### Create Your Own Server

```cpp
#include "julia_explicit.h"
#include <grpc++/grpc++.h>

int main() {
    // Wrap your Julia discipline
    philote::JuliaExplicitDiscipline discipline(
        "my_discipline.jl",
        "MyDiscipline"
    );

    // Build and start gRPC server
    grpc::ServerBuilder builder;
    builder.AddListeningPort("localhost:50051",
                            grpc::InsecureServerCredentials());
    discipline.RegisterServices(builder);

    auto server = builder.BuildAndStart();
    server->Wait();
}
```

### What the C++ Wrapper Provides

The wrapper includes:
- **JuliaRuntime**: Singleton managing Julia lifecycle
- **JuliaMarshal**: Bidirectional C++/Julia data conversion
- **JuliaExplicitDiscipline**: Wrapper class inheriting from `philote::ExplicitDiscipline`
- **CMake integration**: FindJulia module and build system
- **Example server**: Complete working example

See [`cpp/README.md`](cpp/README.md) for detailed documentation.

### Architecture

```
┌─────────────────────────────────────┐
│   gRPC Client (Any Language)        │
└────────────┬────────────────────────┘
             │ Philote Protocol (gRPC)
┌────────────┴────────────────────────┐
│   C++ Server (Philote-Cpp)          │
│   ┌─────────────────────────────┐   │
│   │ JuliaExplicitDiscipline     │   │
│   │ (C++ wrapper)               │   │
│   └──────────┬──────────────────┘   │
│              │                       │
│   ┌──────────┴──────────────────┐   │
│   │ Data Marshaling Layer       │   │
│   │ (C++ ↔ Julia)               │   │
│   └──────────┬──────────────────┘   │
└──────────────┼──────────────────────┘
               │ Julia C API
┌──────────────┴──────────────────────┐
│   Julia Runtime                     │
│   ┌─────────────────────────────┐   │
│   │ Your Discipline (Julia)     │   │
│   │ - setup!()                  │   │
│   │ - compute()                 │   │
│   │ - compute_partials()        │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Testing

### Julia Tests

Run the Julia test suite:

```bash
julia --project=. test/runtests.jl
```

The Julia tests cover:
- Metadata management
- Explicit discipline interface
- Paraboloid example implementation
- Gradient accuracy (finite difference checks)

### C++ Tests

Build and run the C++ test suite:

```bash
cd cpp
mkdir build && cd build
cmake .. -DPHILOTE_CPP_DIR=../../Philote-Cpp -DBUILD_TESTS=ON
cmake --build .
ctest --output-on-failure
```

Or run the test executable directly:

```bash
./philote_julia_tests
```

The C++ tests cover:
- JuliaRuntime: Initialization, module loading, exception handling
- JuliaMarshal: Bidirectional C++/Julia data conversion
- JuliaExplicitDiscipline: Full discipline integration testing

**Note:** C++ tests require:
- Google Test installed
- Philote-Cpp built and available
- Julia runtime accessible

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Related Projects

- [Philote-Cpp](../Philote-Cpp) - C++ implementation of the Philote MDO standard
- [Philote Protocol](https://github.com/philote/philote) - Philote standard specification
