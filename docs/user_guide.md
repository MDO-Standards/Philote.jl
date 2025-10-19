# User Guide {#user_guide}

[TOC]

## Introduction

This guide teaches you how to create Julia MDO disciplines and deploy them as gRPC servers.

### Who This Guide Is For

- Engineers developing MDO analyses
- Researchers integrating computational models
- Anyone wanting to expose Julia code as a web service

### What You'll Learn

- Creating explicit and implicit disciplines
- Working with inputs, outputs, and gradients
- Deploying disciplines as gRPC servers
- Testing and debugging

## Creating Your First Discipline

### Step 1: Define the Discipline Type

Every discipline starts by subtyping `Philote.ExplicitDiscipline` or `Philote.ImplicitDiscipline`:

```julia
using Philote

mutable struct RectangleArea <: Philote.ExplicitDiscipline
    RectangleArea() = new()
end
```

### Step 2: Implement `setup!()`

Declare all inputs, outputs, and optionally partials:

```julia
function Philote.setup!(discipline::RectangleArea)
    # Inputs
    Philote.add_input!(discipline, "width", [1], "m")
    Philote.add_input!(discipline, "height", [1], "m")

    # Outputs
    Philote.add_output!(discipline, "area", [1], "m**2")

    # Partials (optional, for gradients)
    Philote.declare_partials!(discipline, "area", "width")
    Philote.declare_partials!(discipline, "area", "height")
end
```

### Step 3: Implement `compute()`

Define the forward computation:

```julia
function Philote.compute(discipline::RectangleArea,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    width = inputs["width"][1]
    height = inputs["height"][1]

    area = width * height

    return Dict("area" => [area])
end
```

### Step 4: Implement `compute_partials()` (Optional)

Provide analytical gradients:

```julia
function Philote.compute_partials(discipline::RectangleArea,
                                  inputs::Dict{String, <:AbstractArray{Float64}})
    width = inputs["width"][1]
    height = inputs["height"][1]

    return Dict(
        "area" => Dict(
            "width" => [height],    # ∂area/∂width = height
            "height" => [width]     # ∂area/∂height = width
        )
    )
end
```

### Step 5: Test Your Discipline

Add test code:

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    discipline = RectangleArea()
    Philote.setup!(discipline)

    inputs = Dict("width" => [3.0], "height" => [4.0])
    outputs = Philote.compute(discipline, inputs)

    println("Area: $(outputs["area"][1]) m²")
    # Output: Area: 12.0 m²
end
```

Run it:
```bash
julia rectangle_area.jl
```

## Explicit Disciplines

Explicit disciplines compute outputs directly: `outputs = f(inputs)`.

### Variable Shapes

Variables can be scalars, vectors, or multi-dimensional arrays:

```julia
# Scalar
Philote.add_input!(d, "temperature", [1], "K")

# Vector (10 elements)
Philote.add_input!(d, "pressures", [10], "Pa")

# 2D matrix (3×4)
Philote.add_input!(d, "stiffness", [3, 4], "N/m")

# 3D array
Philote.add_input!(d, "field", [2, 3, 4], "")
```

### Working with Arrays

Julia receives arrays flattened. Reshape as needed:

```julia
function Philote.compute(d::MyDiscipline, inputs)
    # Scalar
    scalar = inputs["scalar"][1]

    # Vector (already correct shape)
    vector = inputs["vector"]

    # Matrix - need to reshape
    matrix = reshape(inputs["matrix"], 3, 4)

    # Operate on them
    result = scalar * sum(vector) + sum(matrix)

    return Dict("result" => [result])
end
```

### Units

Units follow a simple syntax:

| Example | Meaning |
|---------|---------|
| `"m"` | meters |
| `"kg"` | kilograms |
| `"m/s"` | meters per second |
| `"m**2"` | square meters |
| `"kg*m/s**2"` | Newtons |
| `""` | dimensionless |

### Example: Paraboloid

See `examples/paraboloid.jl` for a complete working example:

```julia
f(x, y) = (x - 3)² + xy + (y + 4)² - 3
```

## Implicit Disciplines

Implicit disciplines solve residual equations: `R(inputs, outputs) = 0`.

### When to Use

Use implicit disciplines for:
- Iterative solvers
- Coupled systems
- Equilibrium calculations
- Nonlinear systems

### Template

```julia
mutable struct ImplicitExample <: Philote.ImplicitDiscipline
    max_iter::Int
    tolerance::Float64

    ImplicitExample() = new(100, 1e-6)
end

function Philote.setup!(d::ImplicitExample)
    Philote.add_input!(d, "x", [1], "")
    Philote.add_output!(d, "y", [1], "")
    Philote.add_residual!(d, "R_y", [1], "")
end

function Philote.compute_residuals(d::ImplicitExample, inputs)
    x = inputs["x"][1]
    y = inputs["y"][1]

    # R(x, y) = y² - x = 0
    R_y = y^2 - x

    return Dict("R_y" => [R_y])
end

function Philote.solve_residuals(d::ImplicitExample, inputs)
    x = inputs["x"][1]

    # Solve y² - x = 0 → y = √x
    y = sqrt(x)

    return Dict("y" => [y])
end
```

## Deploying as a gRPC Server

### Building the C++ Wrapper

1. **Navigate to cpp directory:**
   ```bash
   cd cpp
   mkdir build && cd build
   ```

2. **Configure CMake:**
   ```bash
   cmake .. -DPHILOTE_CPP_DIR=../../Philote-Cpp -DBUILD_EXAMPLES=ON
   ```

3. **Build:**
   ```bash
   cmake --build .
   ```

### Creating a Server

Create `my_server.cpp`:

```cpp
#include "julia_explicit.h"
#include <grpc++/grpc++.h>

int main() {
    philote::JuliaExplicitDiscipline discipline(
        "path/to/my_discipline.jl",
        "MyDiscipline"
    );

    grpc::ServerBuilder builder;
    builder.AddListeningPort("localhost:50051",
                            grpc::InsecureServerCredentials());
    discipline.RegisterServices(builder);

    auto server = builder.BuildAndStart();
    std::cout << "Server listening on localhost:50051\n";

    server->Wait();
    return 0;
}
```

Add to `CMakeLists.txt`:

```cmake
add_executable(my_server my_server.cpp)
target_link_libraries(my_server PhiloteJulia)
```

Build and run:

```bash
cmake --build .
./bin/my_server
```

### Running the Example

```bash
cd cpp/build
./bin/paraboloid_server
```

Output:
```
Loading Julia module from: ../../examples/paraboloid.jl
Creating Julia discipline instance: ParaboloidDiscipline
Server listening on localhost:50051
```

## Testing

### Unit Testing in Julia

```julia
using Test

@testset "RectangleArea Tests" begin
    d = RectangleArea()
    Philote.setup!(d)

    inputs = Dict("width" => [3.0], "height" => [4.0])
    outputs = Philote.compute(d, inputs)

    @test outputs["area"][1] ≈ 12.0

    partials = Philote.compute_partials(d, inputs)
    @test partials["area"]["width"][1] ≈ 4.0
    @test partials["area"]["height"][1] ≈ 3.0
end
```

### Integration Testing

Test your server with a client:

```python
import grpc
from philote import ExplicitClient

channel = grpc.insecure_channel('localhost:50051')
client = ExplicitClient(channel)

inputs = {'x': [2.0], 'y': [3.0]}
outputs = client.compute(inputs)
print(f"Result: {outputs}")
```

## Best Practices

### 1. Descriptive Names

```julia
# Good
Philote.add_input!(d, "wing_area", [1], "m**2")

# Bad
Philote.add_input!(d, "x1", [1], "m**2")
```

### 2. Input Validation

```julia
function Philote.compute(d::MyDiscipline, inputs)
    x = inputs["x"][1]

    if x < 0
        error("Input 'x' must be non-negative, got $x")
    end

    return Dict("result" => [sqrt(x)])
end
```

### 3. Documentation

```julia
"""
    MyDiscipline <: ExplicitDiscipline

Computes aerodynamic forces using vortex lattice method.

# Inputs
- `airspeed`: Freestream velocity [m/s]
- `angle_of_attack`: Wing angle [rad]

# Outputs
- `lift`: Lift force [N]
- `drag`: Drag force [N]
"""
mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    # ...
end
```

### 4. Error Handling

```julia
function Philote.compute(d::MyDiscipline, inputs)
    try
        result = my_computation(inputs)
        return Dict("output" => [result])
    catch e
        @error "Computation failed" exception=(e, catch_backtrace())
        rethrow()
    end
end
```

## Common Patterns

### External Code Integration

```julia
# Wrap existing function
function my_existing_analysis(x, y)
    # Complex computation
    return result
end

function Philote.compute(d::MyDiscipline, inputs)
    x = inputs["x"][1]
    y = inputs["y"][1]
    result = my_existing_analysis(x, y)
    return Dict("result" => [result])
end
```

### Using Julia Packages

```julia
using LinearAlgebra
using DifferentialEquations

function Philote.compute(d::MyDiscipline, inputs)
    A = reshape(inputs["matrix"], 3, 3)
    eigenvalues = eigvals(A)
    return Dict("eigenvalues" => eigenvalues)
end
```

### File-Based Analysis

```julia
function Philote.compute(d::MyDiscipline, inputs)
    # Write input file
    open("input.dat", "w") do io
        println(io, inputs["param1"][1])
    end

    # Run external program
    run(`./my_analysis input.dat output.dat`)

    # Read output
    result = parse(Float64, readline("output.dat"))

    return Dict("result" => [result])
end
```

## Troubleshooting

### Common Issues

**Q: Module not found**

A: Ensure Philote is in your load path:
```julia
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
```

**Q: Shape mismatch**

A: Remember to flatten matrix outputs:
```julia
matrix_output = [1 2; 3 4]
return Dict("output" => vec(matrix_output))  # Flatten
```

**Q: Server won't start**

A: Check:
- Julia is in PATH
- Discipline file path is correct
- Type name matches Julia struct name

### Debug Mode

Test your discipline directly in Julia first:

```julia
discipline = MyDiscipline()
Philote.setup!(discipline)

inputs = Dict("x" => [1.0])
@show inputs

outputs = Philote.compute(discipline, inputs)
@show outputs
```

## Next Steps

- Read the @ref developer_guide for internals
- Try the @ref tutorials for hands-on practice
- Explore the [API Reference](modules.html)
- Check out `examples/` for more complex cases
