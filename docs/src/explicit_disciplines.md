# [Explicit Disciplines](@id explicit_disciplines)

This guide provides comprehensive documentation on creating and using explicit disciplines in Philote.jl.

## What Are Explicit Disciplines?

Explicit disciplines compute outputs directly from inputs using a function:

```
outputs = f(inputs)
```

There's no iteration, no solving - just a direct computation. This makes them fast and straightforward to implement.

## When to Use Explicit Disciplines

Use explicit disciplines for:

- **Direct formulas**: Mathematical expressions that can be evaluated directly
- **Lookup tables**: Interpolation from pre-computed data
- **Surrogate models**: Trained machine learning models or response surfaces
- **Algebraic equations**: Any equation where outputs can be calculated in one step
- **Data transformations**: Converting between coordinate systems, units, etc.

## Required Methods

Every explicit discipline must implement these methods:

### 1. `setup!(discipline)`

Declares the discipline's interface:

```julia
function Philote.setup!(discipline::MyDiscipline)
    # Declare inputs
    Philote.add_input!(discipline, "input_name", shape, "units")

    # Declare outputs
    Philote.add_output!(discipline, "output_name", shape, "units")

    # (Optional) Declare options
    Philote.add_option!(discipline, "option_name", "type")

    # (Optional) Declare which partials are available
    Philote.declare_partials!(discipline, "output_name", "input_name")
end
```

### 2. `compute(discipline, inputs)`

Performs the computation:

```julia
function Philote.compute(discipline::MyDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    # Extract inputs
    x = inputs["x"]

    # Perform computation
    y = f(x)

    # Return outputs
    return Dict("y" => y)
end
```

## Optional Methods

### 3. `compute_partials(discipline, inputs)`

Computes analytic gradients (highly recommended for optimization):

```julia
function Philote.compute_partials(discipline::MyDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}})
    # Compute partial derivatives
    dy_dx = ...  # ∂y/∂x

    # Return nested dictionary
    return Dict("y" => Dict("x" => dy_dx))
end
```

### 4. `set_options!(discipline, options)`

Processes configuration options:

```julia
function Philote.set_options!(discipline::MyDiscipline,
                               options::Dict{String, Any})
    if haskey(options, "my_option")
        discipline.my_option = options["my_option"]
    end
end
```

## Complete Example: Paraboloid Discipline

Here's the complete paraboloid example from the package:

```julia
using Philote

# Define the discipline type
mutable struct ParaboloidDiscipline <: Philote.ExplicitDiscipline
    scale_factor::Float64
    offset::Float64

    function ParaboloidDiscipline()
        new(1.0, 0.0)
    end
end

# Declare the interface
function Philote.setup!(discipline::ParaboloidDiscipline)
    # Options
    Philote.add_option!(discipline, "scale_factor", "float")
    Philote.add_option!(discipline, "offset", "float")

    # Inputs
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_input!(discipline, "y", [1], "m")

    # Outputs
    Philote.add_output!(discipline, "f_xy", [1], "m**2")

    # Declare gradients
    Philote.declare_partials!(discipline, "f_xy", "x")
    Philote.declare_partials!(discipline, "f_xy", "y")

    # Set metadata
    meta = Philote.get_metadata(discipline)
    meta.name = "ParaboloidDiscipline"
    meta.version = "0.1.0"
end

# Compute function: f(x, y) = (x - 3)^2 + xy + (y + 4)^2 - 3
function Philote.compute(discipline::ParaboloidDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = inputs["y"][1]

    f_xy = (x - 3.0)^2 + x * y + (y + 4.0)^2 - 3.0
    f_xy = discipline.scale_factor * f_xy + discipline.offset

    return Dict("f_xy" => [f_xy])
end

# Compute gradients
function Philote.compute_partials(discipline::ParaboloidDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = inputs["y"][1]

    # ∂f/∂x = 2(x - 3) + y
    df_dx = discipline.scale_factor * (2.0 * (x - 3.0) + y)

    # ∂f/∂y = x + 2(y + 4)
    df_dy = discipline.scale_factor * (2.0 * (y + 4.0) + x)

    return Dict("f_xy" => Dict("x" => [df_dx], "y" => [df_dy]))
end

# Configure options
function Philote.set_options!(discipline::ParaboloidDiscipline,
                               options::Dict{String, <:Any})
    haskey(options, "scale_factor") && (discipline.scale_factor = Float64(options["scale_factor"]))
    haskey(options, "offset") && (discipline.offset = Float64(options["offset"]))
end
```

## Advanced Topics

### Working with Arrays

For vector and matrix inputs/outputs:

```julia
function Philote.setup!(discipline::VectorDiscipline)
    # 3D vector input
    Philote.add_input!(discipline, "position", [3], "m")

    # 3x3 matrix output (stored as 9-element vector in row-major order)
    Philote.add_output!(discipline, "rotation", [9], "unitless")
end

function Philote.compute(discipline::VectorDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    pos = inputs["position"]  # length-3 array
    x, y, z = pos[1], pos[2], pos[3]

    # Compute 3x3 matrix and flatten
    rotation_matrix = compute_rotation(x, y, z)  # returns 3x3 matrix
    rotation_flat = vec(transpose(rotation_matrix))  # flatten to 9 elements

    return Dict("rotation" => rotation_flat)
end
```

### Sparse Jacobians

If not all outputs depend on all inputs, only declare the non-zero partials:

```julia
function Philote.setup!(discipline::SparseDiscipline)
    Philote.add_input!(discipline, "x1", [1], "m")
    Philote.add_input!(discipline, "x2", [1], "m")
    Philote.add_output!(discipline, "y1", [1], "m")
    Philote.add_output!(discipline, "y2", [1], "m")

    # y1 only depends on x1
    Philote.declare_partials!(discipline, "y1", "x1")

    # y2 depends on both
    Philote.declare_partials!(discipline, "y2", "x1")
    Philote.declare_partials!(discipline, "y2", "x2")
end
```

This tells the optimization framework that ∂y1/∂x2 is zero, avoiding unnecessary computations.

### Gradient Checking

Always verify your analytic gradients against finite differences:

```julia
function check_partials(discipline, inputs; epsilon=1e-6, tolerance=1e-5)
    analytic = Philote.compute_partials(discipline, inputs)

    for (out_name, out_partials) in analytic
        for (in_name, analytic_grad) in out_partials
            # Perturb input
            inputs_pert = copy(inputs)
            inputs_pert[in_name] = inputs[in_name] .+ epsilon

            # Finite difference
            f0 = Philote.compute(discipline, inputs)[out_name]
            f1 = Philote.compute(discipline, inputs_pert)[out_name]
            fd_grad = (f1 .- f0) ./ epsilon

            # Check error
            error = maximum(abs.(analytic_grad .- fd_grad))
            if error > tolerance
                @warn "Gradient mismatch for ∂$out_name/∂$in_name" error
            else
                @info "✓ ∂$out_name/∂$in_name verified" error
            end
        end
    end
end
```

### Performance Tips

1. **Avoid allocations in `compute()`**: Pre-allocate arrays if possible
2. **Use `@inbounds`**: When you're sure array accesses are safe
3. **Consider `@simd`**: For vectorizable loops
4. **Type stability**: Ensure all functions return consistent types

Example of optimized compute:

```julia
function Philote.compute(discipline::OptimizedDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"]
    n = length(x)

    # Pre-allocate output
    y = Vector{Float64}(undef, n)

    # Vectorized loop
    @inbounds @simd for i in 1:n
        y[i] = x[i]^2 + 2.0 * x[i]
    end

    return Dict("y" => y)
end
```

### Using Automatic Differentiation

For complex functions, consider using automatic differentiation:

```julia
using ForwardDiff

function Philote.compute_partials(discipline::ComplexDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}})
    # Define a function that computes the output for a given input
    function f(x_val)
        temp_inputs = copy(inputs)
        temp_inputs["x"] = [x_val]
        return Philote.compute(discipline, temp_inputs)["y"][1]
    end

    # Use ForwardDiff to compute derivative
    x = inputs["x"][1]
    dy_dx = ForwardDiff.derivative(f, x)

    return Dict("y" => Dict("x" => [dy_dx]))
end
```

## Common Patterns

### Multiple Inputs and Outputs

```julia
function Philote.setup!(discipline::MultiIODiscipline)
    # Multiple inputs
    Philote.add_input!(discipline, "mach", [1], "unitless")
    Philote.add_input!(discipline, "alpha", [1], "deg")
    Philote.add_input!(discipline, "altitude", [1], "m")

    # Multiple outputs
    Philote.add_output!(discipline, "lift", [1], "N")
    Philote.add_output!(discipline, "drag", [1], "N")
    Philote.add_output!(discipline, "moment", [1], "N*m")
end
```

### Conditional Logic

```julia
function Philote.compute(discipline::ConditionalDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]

    # Different computation based on input value
    if x < 0.0
        y = -x^2
    else
        y = sqrt(x)
    end

    return Dict("y" => [y])
end
```

### Calling External Functions

```julia
function Philote.compute(discipline::ExternalDiscipline,
                         inputs::Dict{String, <:AbstractArray{Float64}})
    # Call some external library or complex function
    result = my_external_function(inputs["x"], discipline.config)

    return Dict("output" => [result])
end
```

## Best Practices

1. **Always implement gradients**: Critical for optimization performance
2. **Check gradient accuracy**: Use finite differences to verify
3. **Document your math**: Include formulas in docstrings
4. **Handle edge cases**: Check for division by zero, domain errors, etc.
5. **Use consistent units**: Document and stick to a unit system
6. **Test thoroughly**: Write unit tests for your disciplines
7. **Version your disciplines**: Use semantic versioning in metadata

## Troubleshooting

### "KeyError" when accessing inputs

Make sure the input name in `compute()` matches exactly what you declared in `setup!()`:

```julia
# In setup!:
Philote.add_input!(discipline, "velocity", [1], "m/s")

# In compute (must match exactly):
v = inputs["velocity"]  # ✓ Correct
v = inputs["vel"]        # ✗ KeyError
```

### Gradient errors

If optimization reports gradient errors:

1. Verify partials with finite differences
2. Check for typos in partial derivative formulas
3. Ensure you're returning the correct dictionary structure
4. Make sure all declared partials are actually returned

### Performance issues

If `compute()` is slow:

1. Profile your code with `@time` or `@benchmark`
2. Check for type instabilities with `@code_warntype`
3. Avoid unnecessary allocations
4. Consider pre-computing expensive operations

## Next Steps

- Learn about [Implicit Disciplines](@ref implicit_disciplines) for iterative solvers
- See [Integration](@ref integration) to serve your discipline via gRPC
- Check the [API Reference](@ref) for complete function signatures
