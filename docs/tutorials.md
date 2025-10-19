# Tutorials {#tutorials}

[TOC]

## Tutorial 1: Rectangle Area (10 minutes)

Learn the basics by creating a simple discipline that computes rectangle area.

### What You'll Learn
- Basic discipline structure
- Input/output declaration
- Simple computation
- Analytical gradients

### Step 1: Create the File

Create `tutorial1_rectangle.jl`:

```julia
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote

mutable struct RectangleArea <: Philote.ExplicitDiscipline
    RectangleArea() = new()
end
```

### Step 2: Declare Variables

```julia
function Philote.setup!(discipline::RectangleArea)
    # Two scalar inputs
    Philote.add_input!(discipline, "width", [1], "m")
    Philote.add_input!(discipline, "height", [1], "m")

    # One scalar output
    Philote.add_output!(discipline, "area", [1], "m**2")

    # Declare gradients
    Philote.declare_partials!(discipline, "area", "width")
    Philote.declare_partials!(discipline, "area", "height")
end
```

### Step 3: Implement Computation

```julia
function Philote.compute(discipline::RectangleArea,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    width = inputs["width"][1]
    height = inputs["height"][1]

    area = width * height

    return Dict("area" => [area])
end
```

### Step 4: Add Gradients

```julia
function Philote.compute_partials(discipline::RectangleArea,
                                  inputs::Dict{String, <:AbstractArray{Float64}})
    width = inputs["width"][1]
    height = inputs["height"][1]

    # ∂area/∂width = height
    # ∂area/∂height = width

    return Dict(
        "area" => Dict(
            "width" => [height],
            "height" => [width]
        )
    )
end
```

### Step 5: Test

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    println("=== Rectangle Area Discipline ===\n")

    d = RectangleArea()
    Philote.setup!(d)

    inputs = Dict("width" => [3.0], "height" => [4.0])
    println("Inputs: width=3.0 m, height=4.0 m")

    outputs = Philote.compute(d, inputs)
    println("Area: $(outputs["area"][1]) m²")

    partials = Philote.compute_partials(d, inputs)
    println("∂area/∂width = $(partials["area"]["width"][1])")
    println("∂area/∂height = $(partials["area"]["height"][1])")
end
```

### Run It

```bash
julia tutorial1_rectangle.jl
```

Expected output:
```
=== Rectangle Area Discipline ===

Inputs: width=3.0 m, height=4.0 m
Area: 12.0 m²
∂area/∂width = 4.0
∂area/∂height = 3.0
```

---

## Tutorial 2: Vector Operations (15 minutes)

Learn to work with vector inputs and outputs.

### What You'll Learn
- Vector variables
- Reshaping arrays
- Vector operations

### The Problem

Compute the mean and standard deviation of a data vector.

### Implementation

```julia
using Statistics

mutable struct VectorStats <: Philote.ExplicitDiscipline
    VectorStats() = new()
end

function Philote.setup!(d::VectorStats)
    # Vector input (10 elements)
    Philote.add_input!(d, "data", [10], "")

    # Scalar outputs
    Philote.add_output!(d, "mean", [1], "")
    Philote.add_output!(d, "std", [1], "")

    # Gradients
    Philote.declare_partials!(d, "mean", "data")
    Philote.declare_partials!(d, "std", "data")
end

function Philote.compute(d::VectorStats,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    data = inputs["data"]  # Already a vector

    m = mean(data)
    s = std(data)

    return Dict("mean" => [m], "std" => [s])
end

function Philote.compute_partials(d::VectorStats,
                                  inputs::Dict{String, <:AbstractArray{Float64}})
    data = inputs["data"]
    n = length(data)

    # ∂mean/∂data_i = 1/n
    dmean_ddata = fill(1.0/n, n)

    # ∂std/∂data_i = (data_i - mean) / (std * n)
    m = mean(data)
    s = std(data)
    dstd_ddata = (data .- m) ./ (s * n)

    return Dict(
        "mean" => Dict("data" => dmean_ddata),
        "std" => Dict("data" => dstd_ddata)
    )
end
```

### Test It

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    d = VectorStats()
    Philote.setup!(d)

    data = collect(1.0:10.0)  # [1, 2, 3, ..., 10]
    inputs = Dict("data" => data)

    outputs = Philote.compute(d, inputs)
    println("Mean: $(outputs["mean"][1])")
    println("Std: $(outputs["std"][1])")
end
```

---

## Tutorial 3: Matrix Operations (20 minutes)

Work with 2D matrices.

### What You'll Learn
- Matrix inputs
- Reshaping flattened arrays
- Linear algebra operations

### The Problem

Compute eigenvalues of a symmetric matrix.

### Implementation

```julia
using LinearAlgebra

mutable struct EigenAnalysis <: Philote.ExplicitDiscipline
    matrix_size::Int

    EigenAnalysis() = new(3)
end

function Philote.setup!(d::EigenAnalysis)
    n = d.matrix_size

    # Matrix input (n×n, stored flattened)
    Philote.add_input!(d, "matrix", [n, n], "")

    # Vector output (n eigenvalues)
    Philote.add_output!(d, "eigenvalues", [n], "")
end

function Philote.compute(d::EigenAnalysis,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    n = d.matrix_size

    # Reshape flattened input to matrix
    matrix_flat = inputs["matrix"]
    matrix = reshape(matrix_flat, n, n)

    # Compute eigenvalues
    eigvals_result = eigvals(matrix)

    return Dict("eigenvalues" => eigvals_result)
end
```

### Test It

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    d = EigenAnalysis()
    Philote.setup!(d)

    # Create a symmetric matrix
    A = [4.0 1.0 0.0;
         1.0 3.0 1.0;
         0.0 1.0 2.0]

    inputs = Dict("matrix" => vec(A))  # Flatten

    outputs = Philote.compute(d, inputs)
    println("Eigenvalues: $(outputs["eigenvalues"])")
end
```

---

## Tutorial 4: Discipline with Options (25 minutes)

Add configuration options to your discipline.

### What You'll Learn
- Declaring options
- Handling different types
- Conditional behavior

### Implementation

```julia
mutable struct ConfigurableDiscipline <: Philote.ExplicitDiscipline
    scale_factor::Float64
    use_offset::Bool
    offset_value::Float64
    method::String

    function ConfigurableDiscipline()
        new(1.0, false, 0.0, "linear")
    end
end

function Philote.setup!(d::ConfigurableDiscipline)
    # Declare options
    Philote.add_option!(d, "scale_factor", "float")
    Philote.add_option!(d, "use_offset", "bool")
    Philote.add_option!(d, "offset_value", "float")
    Philote.add_option!(d, "method", "string")

    # Variables
    Philote.add_input!(d, "x", [1], "")
    Philote.add_output!(d, "y", [1], "")
end

function set_options!(d::ConfigurableDiscipline, options::Dict{String, <:Any})
    if haskey(options, "scale_factor")
        d.scale_factor = Float64(options["scale_factor"])
    end
    if haskey(options, "use_offset")
        d.use_offset = Bool(options["use_offset"])
    end
    if haskey(options, "offset_value")
        d.offset_value = Float64(options["offset_value"])
    end
    if haskey(options, "method")
        d.method = String(options["method"])
    end
end

function Philote.compute(d::ConfigurableDiscipline,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]

    # Choose method
    if d.method == "linear"
        y = x
    elseif d.method == "quadratic"
        y = x^2
    elseif d.method == "cubic"
        y = x^3
    else
        error("Unknown method: $(d.method)")
    end

    # Apply scale and offset
    y = d.scale_factor * y
    if d.use_offset
        y += d.offset_value
    end

    return Dict("y" => [y])
end
```

### Test Different Configurations

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    d = ConfigurableDiscipline()
    Philote.setup!(d)

    inputs = Dict("x" => [2.0])

    # Test 1: Default
    println("Default:")
    println("  y = $(Philote.compute(d, inputs)["y"][1])")

    # Test 2: With scaling
    set_options!(d, Dict("scale_factor" => 3.0))
    println("\nWith scale_factor=3.0:")
    println("  y = $(Philote.compute(d, inputs)["y"][1])")

    # Test 3: Quadratic with offset
    set_options!(d, Dict(
        "method" => "quadratic",
        "use_offset" => true,
        "offset_value" => 10.0
    ))
    println("\nQuadratic with offset:")
    println("  y = $(Philote.compute(d, inputs)["y"][1])")
end
```

---

## Tutorial 5: External Code Integration (30 minutes)

Wrap existing Julia code as a discipline.

### What You'll Learn
- Wrapping existing functions
- File I/O in disciplines
- Error handling

### Scenario

You have an existing aerodynamics function:

```julia
# existing_aero.jl
function compute_lift_drag(velocity, angle, wing_area)
    # Complex aerodynamics computation
    CL = 2π * sind(angle)  # Simplified lift coefficient
    CD = 0.05 + 0.01 * sind(angle)^2  # Simplified drag

    q = 0.5 * 1.225 * velocity^2  # Dynamic pressure
    lift = CL * q * wing_area
    drag = CD * q * wing_area

    return lift, drag
end
```

### Wrap It

```julia
include("existing_aero.jl")

mutable struct AeroDiscipline <: Philote.ExplicitDiscipline
    air_density::Float64

    AeroDiscipline() = new(1.225)
end

function Philote.setup!(d::AeroDiscipline)
    Philote.add_input!(d, "velocity", [1], "m/s")
    Philote.add_input!(d, "angle_of_attack", [1], "deg")
    Philote.add_input!(d, "wing_area", [1], "m**2")

    Philote.add_output!(d, "lift", [1], "N")
    Philote.add_output!(d, "drag", [1], "N")
end

function Philote.compute(d::AeroDiscipline,
                        inputs::Dict{String, <:AbstractArray{Float64}})
    v = inputs["velocity"][1]
    alpha = inputs["angle_of_attack"][1]
    S = inputs["wing_area"][1]

    # Call existing function
    lift, drag = compute_lift_drag(v, alpha, S)

    return Dict("lift" => [lift], "drag" => [drag])
end
```

---

## Tutorial 6: Deploying to gRPC (45 minutes)

Put it all together and create a deployable server.

### What You'll Learn
- Building C++ wrapper
- Creating server executable
- Testing with a client

### Step 1: Create Julia Discipline

Use any discipline from previous tutorials, e.g., `tutorial1_rectangle.jl`.

### Step 2: Create C++ Server

`rectangle_server.cpp`:

```cpp
#include "julia_explicit.h"
#include <grpc++/grpc++.h>
#include <iostream>

int main() {
    std::string address("localhost:50052");

    try {
        philote::JuliaExplicitDiscipline discipline(
            "../tutorial1_rectangle.jl",
            "RectangleArea"
        );

        grpc::ServerBuilder builder;
        builder.AddListeningPort(address,
                                grpc::InsecureServerCredentials());
        discipline.RegisterServices(builder);

        auto server = builder.BuildAndStart();
        std::cout << "Rectangle server listening on " << address << "\n";
        std::cout << "Press Ctrl+C to stop\n";

        server->Wait();

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
```

### Step 3: Add to CMake

In `cpp/examples/CMakeLists.txt`:

```cmake
add_executable(rectangle_server rectangle_server.cpp)
target_link_libraries(rectangle_server PhiloteJulia)
```

### Step 4: Build

```bash
cd cpp/build
cmake --build .
```

### Step 5: Run Server

```bash
./bin/rectangle_server
```

### Step 6: Test with Python Client

```python
import grpc
from philote import ExplicitClient

# Connect
channel = grpc.insecure_channel('localhost:50052')
client = ExplicitClient(channel)

# Setup
client.setup()

# Compute
inputs = {'width': [5.0], 'height': [3.0]}
outputs = client.compute(inputs)

print(f"Area: {outputs['area'][0]} m²")

# Gradients
partials = client.compute_partials(inputs)
print(f"∂area/∂width: {partials['area']['width'][0]}")
print(f"∂area/∂height: {partials['area']['height'][0]}")
```

---

## Tutorial 7: Debugging (20 minutes)

Learn debugging techniques.

### Technique 1: Print Debugging

```julia
function Philote.compute(d::MyDiscipline, inputs)
    @show inputs  # Print all inputs

    x = inputs["x"][1]
    @show x  # Print specific value

    y = expensive_computation(x)
    @show y

    return Dict("y" => [y])
end
```

### Technique 2: Assertions

```julia
function Philote.compute(d::MyDiscipline, inputs)
    x = inputs["x"][1]

    @assert x >= 0 "x must be non-negative"
    @assert x <= 100 "x must be <= 100"

    return Dict("y" => [sqrt(x)])
end
```

### Technique 3: Try-Catch

```julia
function Philote.compute(d::MyDiscipline, inputs)
    try
        result = risky_computation(inputs)
        return Dict("y" => [result])
    catch e
        @error "Computation failed" exception=(e, catch_backtrace())
        rethrow()
    end
end
```

### Technique 4: Unit Tests

```julia
using Test

@testset "MyDiscipline Tests" begin
    d = MyDiscipline()
    Philote.setup!(d)

    # Test normal case
    inputs = Dict("x" => [4.0])
    outputs = Philote.compute(d, inputs)
    @test outputs["y"][1] ≈ 16.0

    # Test edge case
    inputs = Dict("x" => [0.0])
    outputs = Philote.compute(d, inputs)
    @test outputs["y"][1] ≈ 0.0

    # Test error case
    inputs = Dict("x" => [-1.0])
    @test_throws DomainError Philote.compute(d, inputs)
end
```

---

## Next Steps

- Review the @ref user_guide for detailed information
- Study `examples/paraboloid.jl` for a complete example
- Read the @ref developer_guide to understand internals
- Check the [API Reference](modules.html) for complete documentation

## Quick Reference

### Discipline Template

```julia
mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    # Fields
end

function Philote.setup!(d::MyDiscipline)
    # Declare variables
end

function Philote.compute(d::MyDiscipline, inputs)
    # Compute outputs
end

function Philote.compute_partials(d::MyDiscipline, inputs)
    # Compute gradients (optional)
end
```

### Common Operations

```julia
# Scalar variable
Philote.add_input!(d, "name", [1], "units")

# Vector variable
Philote.add_input!(d, "name", [n], "units")

# Matrix variable
Philote.add_input!(d, "name", [m, n], "units")

# Extract scalar
val = inputs["name"][1]

# Extract vector
vec = inputs["name"]

# Extract matrix
mat = reshape(inputs["name"], m, n)

# Return outputs
return Dict("output_name" => [value])

# Return gradients
return Dict("output" => Dict("input" => [derivative]))
```
