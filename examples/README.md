# Philote.jl Examples

This directory contains example implementations of Philote disciplines in Julia.

## Examples

### paraboloid.jl - Explicit Discipline

A simple explicit discipline that computes a paraboloid function: `f(x, y) = (x-3)^2 + x*y + (y+4)^2`

**Type**: Explicit discipline (outputs = f(inputs))

**Inputs**:
- `x` (scalar, m)
- `y` (scalar, m)

**Outputs**:
- `f_xy` (scalar, m^2)

**Features**:
- Demonstrates basic explicit discipline structure
- Implements analytic gradients via `compute_partials`
- Simple two-variable nonlinear function

### quadratic.jl - Implicit Discipline

An implicit discipline that solves the quadratic equation: `a*x^2 + b*x + c = 0`

**Type**: Implicit discipline (residuals(inputs, outputs) = 0)

**Inputs**:
- `a` (scalar, unitless) - quadratic coefficient
- `b` (scalar, unitless) - linear coefficient
- `c` (scalar, unitless) - constant term

**Outputs**:
- `x` (scalar, unitless) - solution

**Residuals**:
- `r` (scalar, unitless) - `r = a*x^2 + b*x + c`

**Features**:
- Demonstrates implicit discipline with residual equations
- Implements `solve_residuals` using quadratic formula
- Implements `residual_partials` for gradient-based optimization
- Shows how to handle solver options

## Using the Examples

### Loading in Julia

```julia
using Philote

# Load the example file
include("examples/paraboloid.jl")

# Create discipline instance
disc = ParaboloidDiscipline()

# Setup the discipline
Philote.setup!(disc)

# Get metadata
metadata = Philote.get_metadata(disc)
println("Discipline: ", metadata.name)
println("Inputs: ", keys(metadata.inputs))
println("Outputs: ", keys(metadata.outputs))

# Compute outputs
inputs = Dict("x" => [1.0], "y" => [2.0])
outputs = Philote.compute(disc, inputs)
println("f_xy = ", outputs["f_xy"][1])

# Compute gradients
partials = Philote.compute_partials(disc, inputs)
println("df/dx = ", partials["f_xy"]["x"][1,1])
println("df/dy = ", partials["f_xy"]["y"][1,1])
```

### Testing the Examples

You can test the examples by running Julia's test suite:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

## Serving via gRPC

To serve these disciplines via gRPC for use in MDO frameworks, use [Philote-Python](https://github.com/mdo-standards/Philote-Python) with the Julia wrapper:

```bash
# Install Philote-Python with Julia support
pip install philote-mdo[julia]

# Serve a discipline
philote-julia-serve config.yaml
```

See the Philote-Python documentation for details on creating configuration files and serving Julia disciplines.

## Creating Your Own Disciplines

### Explicit Discipline Template

```julia
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    # Add any internal state here
    function MyDiscipline()
        new()
    end
end

function Philote.setup!(discipline::MyDiscipline)
    # Declare inputs
    Philote.add_input!(discipline, "input1", [1], "units")

    # Declare outputs
    Philote.add_output!(discipline, "output1", [1], "units")

    # Declare partials (for gradient computation)
    Philote.declare_partials!(discipline, "output1", "input1")
end

function Philote.compute(discipline::MyDiscipline, inputs::Dict{String,Array})
    # Extract inputs
    input1 = inputs["input1"][1]

    # Compute outputs
    output1 = f(input1)  # Your computation here

    # Return outputs
    return Dict("output1" => [output1])
end

function Philote.compute_partials(discipline::MyDiscipline, inputs::Dict{String,Array})
    # Extract inputs
    input1 = inputs["input1"][1]

    # Compute gradients
    d_output1_d_input1 = df_dinput1(input1)  # Your gradient here

    # Return partials (Jacobian matrices)
    return Dict(
        "output1" => Dict(
            "input1" => reshape([d_output1_d_input1], 1, 1)
        )
    )
end
```

### Implicit Discipline Template

```julia
using Philote

mutable struct MyImplicitDiscipline <: Philote.ImplicitDiscipline
    # Add any internal state here
    function MyImplicitDiscipline()
        new()
    end
end

function Philote.setup!(discipline::MyImplicitDiscipline)
    # Declare inputs
    Philote.add_input!(discipline, "input1", [1], "units")

    # Declare outputs (unknowns to solve for)
    Philote.add_output!(discipline, "output1", [1], "units")

    # Declare residuals
    Philote.add_residual!(discipline, "residual1", [1], "units")

    # Declare partials
    Philote.declare_partials!(discipline, "residual1", "input1")
    Philote.declare_partials!(discipline, "residual1", "output1")
end

function Philote.compute_residuals(discipline::MyImplicitDiscipline,
                                   inputs::Dict{String,Array},
                                   outputs::Dict{String,Array})
    # Extract inputs and outputs
    input1 = inputs["input1"][1]
    output1 = outputs["output1"][1]

    # Compute residual (should be zero when solved)
    r = residual_function(input1, output1)

    return Dict("residual1" => [r])
end

function Philote.solve_residuals(discipline::MyImplicitDiscipline,
                                 inputs::Dict{String,Array},
                                 outputs::Dict{String,Array})
    # Extract inputs
    input1 = inputs["input1"][1]

    # Solve for outputs
    output1 = solve_for_output(input1)  # Your solver here

    # Update outputs in place
    outputs["output1"][1] = output1
end

function Philote.residual_partials(discipline::MyImplicitDiscipline,
                                   inputs::Dict{String,Array},
                                   outputs::Dict{String,Array})
    # Extract inputs and outputs
    input1 = inputs["input1"][1]
    output1 = outputs["output1"][1]

    # Compute Jacobian of residuals
    dr_dinput1 = compute_dr_dinput1(input1, output1)
    dr_doutput1 = compute_dr_doutput1(input1, output1)

    return Dict(
        "residual1" => Dict(
            "input1" => reshape([dr_dinput1], 1, 1),
            "output1" => reshape([dr_doutput1], 1, 1)
        )
    )
end
```

## Array Dimensions

All variables in Philote are arrays, even scalars:
- Scalars: `[1]` shape - single element array
- Vectors: `[n]` shape - n-element array
- Matrices: `[m, n]` shape - m×n array

Jacobians are 2D arrays where:
- Rows correspond to output/residual elements
- Columns correspond to input/output elements
- For scalar-to-scalar: `reshape([derivative], 1, 1)`

## Reference

See [Philote.jl documentation](../README.md) for the complete API reference.
