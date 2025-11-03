# [Tutorial: Your First Discipline](@id tutorial)

This tutorial will guide you through creating your first Philote discipline step-by-step. We'll build an explicit discipline that computes a simple paraboloid function.

## Prerequisites

Make sure you have Philote.jl installed:

```julia
using Pkg
Pkg.add("Philote")
```

## The Problem

We'll implement a discipline that computes the paraboloid function:

```
f(x, y) = (x - 3)² + xy + (y + 4)² - 3
```

This function takes two inputs (`x` and `y`) and produces one output (`f`). We'll also compute the analytic gradients (partial derivatives).

## Step 1: Import Philote

Start by importing the Philote module:

```julia
using Philote
```

## Step 2: Define the Discipline Struct

Create a struct that inherits from `ExplicitDiscipline`:

```julia
mutable struct ParaboloidDiscipline <: Philote.ExplicitDiscipline
    scale_factor::Float64
    offset::Float64

    function ParaboloidDiscipline()
        new(1.0, 0.0)
    end
end
```

**Key points:**
- Use `mutable struct` if you need to store configuration state (like `scale_factor` and `offset`)
- Inherit from `Philote.ExplicitDiscipline` for an explicit formulation
- The constructor initializes default values for any internal fields

## Step 3: Implement `setup!()`

The `setup!()` function declares your discipline's interface - its inputs, outputs, options, and derivatives:

```julia
function Philote.setup!(discipline::ParaboloidDiscipline)
    # Declare options (configuration parameters)
    Philote.add_option!(discipline, "scale_factor", "float")
    Philote.add_option!(discipline, "offset", "float")

    # Declare inputs
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_input!(discipline, "y", [1], "m")

    # Declare outputs
    Philote.add_output!(discipline, "f_xy", [1], "m**2")

    # Declare which partials (derivatives) are available
    Philote.declare_partials!(discipline, "f_xy", "x")
    Philote.declare_partials!(discipline, "f_xy", "y")

    # (Optional) Set discipline metadata
    meta = Philote.get_metadata(discipline)
    meta.name = "ParaboloidDiscipline"
    meta.version = "0.1.0"
end
```

**Understanding the parameters:**
- `add_input!(discipline, name, shape, units)`: Declares an input variable
  - `shape = [1]` means a scalar value
  - `units = "m"` is for documentation (not enforced)
- `add_output!(discipline, name, shape, units)`: Declares an output variable
- `add_option!(discipline, name, type)`: Declares a configuration option
- `declare_partials!(output, input)`: Declares that ∂output/∂input is available

## Step 4: Implement `compute()`

The `compute()` function performs the actual calculation:

```julia
function Philote.compute(discipline::ParaboloidDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    # Extract scalar inputs
    x = inputs["x"][1]
    y = inputs["y"][1]

    # Compute paraboloid function
    f_xy = (x - 3.0)^2 + x * y + (y + 4.0)^2 - 3.0

    # Apply scaling and offset
    f_xy = discipline.scale_factor * f_xy + discipline.offset

    # Return outputs as dictionary
    return Dict("f_xy" => [f_xy])
end
```

**Key points:**
- Input values come as a `Dict{String, Array{Float64}}`
- Even scalars are arrays, so use `[1]` to extract the value
- Return a dictionary mapping output names to arrays
- You can access discipline fields (like `scale_factor`) directly

## Step 5: Implement `compute_partials()`

For gradient-based optimization, implement the derivatives:

```julia
function Philote.compute_partials(discipline::ParaboloidDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}})
    # Extract inputs
    x = inputs["x"][1]
    y = inputs["y"][1]

    # Compute partial derivatives
    # ∂f/∂x = 2(x - 3) + y
    df_dx = 2.0 * (x - 3.0) + y

    # ∂f/∂y = x + 2(y + 4)
    df_dy = x + 2.0 * (y + 4.0)

    # Apply scaling (derivative of offset is zero)
    df_dx = discipline.scale_factor * df_dx
    df_dy = discipline.scale_factor * df_dy

    # Return nested dictionary: output -> input -> derivative
    return Dict("f_xy" => Dict("x" => [df_dx],
                               "y" => [df_dy]))
end
```

**Key points:**
- Return a nested dictionary: `Dict{output_name => Dict{input_name => gradient}}`
- Derivatives are also arrays (even for scalars)
- Only compute derivatives you declared in `setup!()`

## Step 6: (Optional) Implement `set_options!()`

If you want custom option processing, implement `set_options!()`:

```julia
function Philote.set_options!(discipline::ParaboloidDiscipline,
                               options::Dict{String, Any})
    # Process each option
    if haskey(options, "scale_factor")
        discipline.scale_factor = Float64(options["scale_factor"])
    end

    if haskey(options, "offset")
        discipline.offset = Float64(options["offset"])
    end
end
```

**Note:** This function is optional. If you don't need custom validation or processing, you can skip it.

## Step 7: Use Your Discipline

Now you can use your discipline:

```julia
# Create an instance
disc = ParaboloidDiscipline()

# Initialize it (calls setup!)
Philote.setup!(disc)

# Set options if needed
Philote.set_options!(disc, Dict("scale_factor" => 2.0, "offset" => 1.0))

# Prepare inputs
inputs = Dict("x" => [2.0], "y" => [3.0])

# Compute outputs
outputs = Philote.compute(disc, inputs)
println("f_xy = ", outputs["f_xy"][1])  # Should print the result

# Compute gradients
partials = Philote.compute_partials(disc, inputs)
println("∂f/∂x = ", partials["f_xy"]["x"][1])
println("∂f/∂y = ", partials["f_xy"]["y"][1])
```

## Complete Example

Here's the complete discipline in one file:

```julia
using Philote

mutable struct ParaboloidDiscipline <: Philote.ExplicitDiscipline
    scale_factor::Float64
    offset::Float64
    ParaboloidDiscipline() = new(1.0, 0.0)
end

function Philote.setup!(discipline::ParaboloidDiscipline)
    Philote.add_option!(discipline, "scale_factor", "float")
    Philote.add_option!(discipline, "offset", "float")
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_input!(discipline, "y", [1], "m")
    Philote.add_output!(discipline, "f_xy", [1], "m**2")
    Philote.declare_partials!(discipline, "f_xy", "x")
    Philote.declare_partials!(discipline, "f_xy", "y")
end

function Philote.compute(discipline::ParaboloidDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    x, y = inputs["x"][1], inputs["y"][1]
    f_xy = discipline.scale_factor * ((x - 3.0)^2 + x * y + (y + 4.0)^2 - 3.0) + discipline.offset
    return Dict("f_xy" => [f_xy])
end

function Philote.compute_partials(discipline::ParaboloidDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}})
    x, y = inputs["x"][1], inputs["y"][1]
    df_dx = discipline.scale_factor * (2.0 * (x - 3.0) + y)
    df_dy = discipline.scale_factor * (x + 2.0 * (y + 4.0))
    return Dict("f_xy" => Dict("x" => [df_dx], "y" => [df_dy]))
end

function Philote.set_options!(discipline::ParaboloidDiscipline,
                               options::Dict{String, Any})
    haskey(options, "scale_factor") && (discipline.scale_factor = Float64(options["scale_factor"]))
    haskey(options, "offset") && (discipline.offset = Float64(options["offset"]))
end
```

## Testing Your Discipline

You can verify your gradients using finite differences:

```julia
function check_gradients(discipline, inputs; epsilon=1e-6)
    # Compute analytic gradients
    analytic = Philote.compute_partials(discipline, inputs)

    # Compute finite difference approximation
    for (output_name, output_partials) in analytic
        for (input_name, analytic_grad) in output_partials
            # Perturb input
            inputs_plus = copy(inputs)
            inputs_plus[input_name] = inputs[input_name] .+ epsilon

            # Compute outputs
            f_base = Philote.compute(discipline, inputs)[output_name]
            f_plus = Philote.compute(discipline, inputs_plus)[output_name]

            # Finite difference
            fd_grad = (f_plus .- f_base) ./ epsilon

            # Compare
            error = maximum(abs.(analytic_grad .- fd_grad))
            println("∂$output_name/∂$input_name: error = $error")
        end
    end
end

# Run check
disc = ParaboloidDiscipline()
Philote.setup!(disc)
check_gradients(disc, Dict("x" => [2.0], "y" => [3.0]))
```

## Next Steps

Congratulations! You've created your first Philote discipline. Now you can:

1. Learn about [Explicit Disciplines](@ref explicit_disciplines) in more detail
2. Explore [Implicit Disciplines](@ref implicit_disciplines) for iterative solvers
3. Read about [Integration with Philote-Python](@ref integration) to serve your discipline via gRPC
4. Browse the [API Reference](@ref) for complete documentation

## Common Patterns

### Working with Vector Inputs

For multi-dimensional inputs:

```julia
Philote.add_input!(discipline, "position", [3], "m")  # 3D vector

# In compute:
pos = inputs["position"]  # [x, y, z] as an array
x, y, z = pos[1], pos[2], pos[3]
```

### Multiple Outputs

```julia
function Philote.setup!(discipline::MyDiscipline)
    Philote.add_output!(discipline, "lift", [1], "N")
    Philote.add_output!(discipline, "drag", [1], "N")
end

function Philote.compute(discipline::MyDiscipline, inputs)
    # ... compute values ...
    return Dict("lift" => [L], "drag" => [D])
end
```

### Sparse Jacobians

If not all outputs depend on all inputs, only declare the partials that exist:

```julia
# If output1 doesn't depend on input2, don't declare it:
Philote.declare_partials!(discipline, "output1", "input1")  # Yes
# Don't declare partials!(discipline, "output1", "input2")  # No - skip it
```

This completes the tutorial! You now have all the tools to create your own disciplines.
