# [Implicit Disciplines](@id implicit_disciplines)

This guide provides comprehensive documentation on creating and using implicit disciplines in Philote.jl.

## What Are Implicit Disciplines?

Implicit disciplines solve a system of residual equations to find outputs:

```
residuals(inputs, outputs) = 0
```

The discipline must find values of `outputs` that make the residuals equal (or close) to zero for given `inputs`. This requires iterative solving.

## When to Use Implicit Disciplines

Use implicit disciplines for:

- **Equilibrium conditions**: Problems where forces, moments, or flows must balance
- **Fixed-point iterations**: Finding x such that f(x) = x
- **Nonlinear systems**: Coupled equations that can't be solved directly
- **Physics-based solvers**: CFD, FEA, and other iterative simulation codes
- **Trim analysis**: Finding control settings that achieve desired states

## Key Differences from Explicit Disciplines

| Aspect | Explicit | Implicit |
|--------|----------|----------|
| Computation | `outputs = f(inputs)` | Solve `R(inputs, outputs) = 0` |
| Speed | Fast (direct) | Slower (iterative) |
| Complexity | Simple | More complex |
| Residuals | None | Must define |
| Jacobian | `∂outputs/∂inputs` | `∂R/∂outputs` and `∂R/∂inputs` |

## Required Methods

Every implicit discipline must implement these methods:

### 1. `setup!(discipline)`

Declares the discipline's interface, including residuals:

```julia
function Philote.setup!(discipline::MyImplicitDiscipline)
    # Declare inputs
    Philote.add_input!(discipline, "input_name", shape, "units")

    # Declare outputs (state variables to be solved for)
    Philote.add_output!(discipline, "output_name", shape, "units")

    # Declare residuals (must equal zero)
    Philote.add_residual!(discipline, "residual_name", shape, "units")

    # Declare Jacobian partials
    Philote.declare_partials!(discipline, "residual_name", "output_name")  # dR/d(state)
    Philote.declare_partials!(discipline, "residual_name", "input_name")   # dR/d(input)
end
```

### 2. `compute_residuals(discipline, inputs, outputs)`

Computes the residual values for given inputs and current output guess:

```julia
function Philote.compute_residuals(discipline::MyImplicitDiscipline,
                                    inputs::Dict{String, <:AbstractArray{Float64}},
                                    outputs::Dict{String, <:AbstractArray{Float64}})
    # Extract inputs and current output values
    x = inputs["x"]
    y = outputs["y"]  # Current guess for output

    # Compute residual
    R = ...  # Should be zero when y is correct

    return Dict("R" => R)
end
```

### 3. `solve_residuals(discipline, inputs, outputs)`

Solves for outputs that make residuals zero (modifies `outputs` in place):

```julia
function Philote.solve_residuals(discipline::MyImplicitDiscipline,
                                  inputs::Dict{String, <:AbstractArray{Float64}},
                                  outputs::Dict{String, <:AbstractArray{Float64}})
    # Extract inputs
    x = inputs["x"]

    # Solve for y such that R(x, y) = 0
    y_solution = solve_somehow(x)

    # Modify outputs dictionary in place
    outputs["y"] .= y_solution

    return nothing  # Must return nothing
end
```

## Optional Methods

### 4. `residual_partials(discipline, inputs, outputs)`

Computes the Jacobian of residuals (highly recommended for optimization):

```julia
function Philote.residual_partials(discipline::MyImplicitDiscipline,
                                    inputs::Dict{String, <:AbstractArray{Float64}},
                                    outputs::Dict{String, <:AbstractArray{Float64}})
    # Compute partial derivatives of residuals
    dR_dy = ...  # ∂R/∂y (with respect to outputs/states)
    dR_dx = ...  # ∂R/∂x (with respect to inputs)

    # Return nested dictionary
    return Dict("R" => Dict("y" => dR_dy, "x" => dR_dx))
end
```

## Complete Example: Quadratic Solver

Here's a complete implicit discipline that solves ax² + bx + c = 0:

```julia
using Philote

# Define the discipline type
mutable struct QuadraticImplicitDiscipline <: Philote.ImplicitDiscipline
    tolerance::Float64
    max_iterations::Int

    function QuadraticImplicitDiscipline()
        new(1e-10, 100)
    end
end

# Declare the interface
function Philote.setup!(discipline::QuadraticImplicitDiscipline)
    # Options
    Philote.add_option!(discipline, "tolerance", "float")
    Philote.add_option!(discipline, "max_iterations", "int")

    # Inputs (coefficients)
    Philote.add_input!(discipline, "a", [1], "1")
    Philote.add_input!(discipline, "b", [1], "1")
    Philote.add_input!(discipline, "c", [1], "1")

    # Outputs (solution)
    Philote.add_output!(discipline, "x", [1], "1")

    # Residuals
    Philote.add_residual!(discipline, "R", [1], "1")

    # Jacobian: partials of residual w.r.t. outputs and inputs
    Philote.declare_partials!(discipline, "R", "x")  # dR/dx
    Philote.declare_partials!(discipline, "R", "a")  # dR/da
    Philote.declare_partials!(discipline, "R", "b")  # dR/db
    Philote.declare_partials!(discipline, "R", "c")  # dR/dc

    # Metadata
    meta = Philote.get_metadata(discipline)
    meta.name = "QuadraticImplicitDiscipline"
    meta.version = "0.1.0"
end

# Compute residual: R(x) = ax² + bx + c
function Philote.compute_residuals(discipline::QuadraticImplicitDiscipline,
                                    inputs::Dict{String, <:AbstractArray{Float64}},
                                    outputs::Dict{String, <:AbstractArray{Float64}})
    a = inputs["a"][1]
    b = inputs["b"][1]
    c = inputs["c"][1]
    x = outputs["x"][1]

    R = a * x^2 + b * x + c

    return Dict("R" => [R])
end

# Solve for x using quadratic formula
function Philote.solve_residuals(discipline::QuadraticImplicitDiscipline,
                                  inputs::Dict{String, <:AbstractArray{Float64}},
                                  outputs::Dict{String, <:AbstractArray{Float64}})
    a = inputs["a"][1]
    b = inputs["b"][1]
    c = inputs["c"][1]

    # Handle degenerate cases
    if abs(a) < 1e-14
        # Linear: bx + c = 0
        if abs(b) < 1e-14
            error("Degenerate equation")
        end
        x = -c / b
    else
        # Quadratic formula
        discriminant = b^2 - 4*a*c
        if discriminant < 0
            error("No real solutions")
        end

        sqrt_disc = sqrt(discriminant)
        x1 = (-b + sqrt_disc) / (2*a)
        x2 = (-b - sqrt_disc) / (2*a)

        # Choose one root (arbitrary for this example)
        x = abs(x1) > abs(x2) ? x1 : x2
    end

    # Modify outputs in place
    outputs["x"][1] = x
    return nothing
end

# Compute Jacobian
function Philote.residual_partials(discipline::QuadraticImplicitDiscipline,
                                    inputs::Dict{String, <:AbstractArray{Float64}},
                                    outputs::Dict{String, <:AbstractArray{Float64}})
    a = inputs["a"][1]
    b = inputs["b"][1]
    x = outputs["x"][1]

    # Derivatives of R = ax² + bx + c
    dR_dx = 2.0 * a * x + b  # ∂R/∂x
    dR_da = x^2              # ∂R/∂a
    dR_db = x                # ∂R/∂b
    dR_dc = 1.0              # ∂R/∂c

    return Dict("R" => Dict(
        "x" => [dR_dx],
        "a" => [dR_da],
        "b" => [dR_db],
        "c" => [dR_dc]
    ))
end

# Configure options
function Philote.set_options!(discipline::QuadraticImplicitDiscipline,
                               options::Dict{String, <:Any})
    haskey(options, "tolerance") && (discipline.tolerance = Float64(options["tolerance"]))
    haskey(options, "max_iterations") && (discipline.max_iterations = Int(options["max_iterations"]))
end
```

## Understanding Residuals and Jacobians

### What is a Residual?

A residual is an equation that must equal zero at the solution. For example:

- **Force balance**: `R = F_applied - F_resistance` (should be zero at equilibrium)
- **Flow conservation**: `R = flow_in - flow_out` (should be zero at steady state)
- **Fixed point**: `R = f(x) - x` (should be zero when x is a fixed point)

### The Jacobian Structure

For implicit disciplines, the Jacobian has two parts:

1. **∂R/∂(outputs)**: How residuals change with state variables
   - Used by solvers to iterate toward solution
   - Critical for Newton-type methods

2. **∂R/∂(inputs)**: How residuals change with inputs
   - Used for sensitivity analysis
   - Needed for gradient-based optimization

## Solving Strategies

### Direct Analytical Solution

When possible, solve directly (like the quadratic example):

```julia
function Philote.solve_residuals(discipline, inputs, outputs)
    # Derive analytical solution
    x_solution = analytical_formula(inputs)
    outputs["x"] .= x_solution
    return nothing
end
```

### Newton's Method

For nonlinear systems without closed-form solutions:

```julia
using LinearAlgebra

function Philote.solve_residuals(discipline, inputs, outputs)
    tol = discipline.tolerance
    max_iter = discipline.max_iterations

    for iter in 1:max_iter
        # Compute residual at current guess
        R = Philote.compute_residuals(discipline, inputs, outputs)

        # Check convergence
        if maximum(abs.(R["R"])) < tol
            return nothing
        end

        # Compute Jacobian (dR/doutputs)
        J = Philote.residual_partials(discipline, inputs, outputs)

        # Newton step: Δx = -J^{-1} * R
        delta_x = -J["R"]["x"] \ R["R"]

        # Update guess
        outputs["x"] .+= delta_x
    end

    error("Failed to converge in $max_iter iterations")
end
```

### Using Existing Solvers

Wrap external solvers or Julia packages:

```julia
using NLsolve

function Philote.solve_residuals(discipline, inputs, outputs)
    # Define residual function for NLsolve
    function residual_func!(R_out, x_guess)
        temp_outputs = Dict("x" => x_guess)
        R_dict = Philote.compute_residuals(discipline, inputs, temp_outputs)
        R_out .= R_dict["R"]
    end

    # Initial guess
    x0 = outputs["x"]

    # Solve
    result = nlsolve(residual_func!, x0, ftol=discipline.tolerance)

    # Update outputs
    outputs["x"] .= result.zero
    return nothing
end
```

## Advanced Topics

### Multiple Residuals and States

For systems with multiple equations:

```julia
function Philote.setup!(discipline::MultiStateDiscipline)
    # 3 inputs
    Philote.add_input!(discipline, "force", [1], "N")

    # 3 states to solve for
    Philote.add_output!(discipline, "x", [1], "m")
    Philote.add_output!(discipline, "y", [1], "m")
    Philote.add_output!(discipline, "z", [1], "m")

    # 3 residuals (one per state)
    Philote.add_residual!(discipline, "R_x", [1], "N")
    Philote.add_residual!(discipline, "R_y", [1], "N")
    Philote.add_residual!(discipline, "R_z", [1], "N")

    # Jacobian structure
    for R in ["R_x", "R_y", "R_z"]
        for state in ["x", "y", "z"]
            Philote.declare_partials!(discipline, R, state)
        end
        Philote.declare_partials!(discipline, R, "force")
    end
end
```

### Sparse Jacobians

If not all residuals depend on all states, declare only non-zero partials:

```julia
# R1 depends only on x1, R2 depends only on x2
Philote.declare_partials!(discipline, "R1", "x1")  # Yes
# Skip: declare_partials!(discipline, "R1", "x2")  # Zero, don't declare

Philote.declare_partials!(discipline, "R2", "x2")  # Yes
# Skip: declare_partials!(discipline, "R2", "x1")  # Zero, don't declare
```

### Convergence Monitoring

Add convergence diagnostics:

```julia
function Philote.solve_residuals(discipline, inputs, outputs)
    for iter in 1:discipline.max_iterations
        R = Philote.compute_residuals(discipline, inputs, outputs)
        norm_R = maximum(abs.(R["R"]))

        @debug "Iteration $iter: ||R|| = $norm_R"

        if norm_R < discipline.tolerance
            @info "Converged in $iter iterations"
            return nothing
        end

        # ... Newton step ...
    end

    @warn "Failed to converge after $(discipline.max_iterations) iterations"
    error("Convergence failure")
end
```

## Jacobian Verification

Always verify your Jacobians using finite differences:

```julia
function check_jacobian(discipline, inputs, outputs; epsilon=1e-6)
    # Compute analytic Jacobian
    J_analytic = Philote.residual_partials(discipline, inputs, outputs)

    # Check dR/d(outputs)
    for (res_name, partials) in J_analytic
        for (out_name, analytic_jac) in partials
            if out_name in keys(outputs)  # It's an output/state
                # Perturb output
                outputs_pert = copy(outputs)
                outputs_pert[out_name] = outputs[out_name] .+ epsilon

                # Finite difference
                R0 = Philote.compute_residuals(discipline, inputs, outputs)[res_name]
                R1 = Philote.compute_residuals(discipline, inputs, outputs_pert)[res_name]
                fd_jac = (R1 .- R0) ./ epsilon

                # Compare
                error = maximum(abs.(analytic_jac .- fd_jac))
                if error > 1e-5
                    @warn "Jacobian error: ∂$res_name/∂$out_name" error
                else
                    @info "✓ ∂$res_name/∂$out_name verified" error
                end
            end
        end
    end
end
```

## Best Practices

1. **Start with simple tests**: Verify your discipline works on simple, known cases
2. **Check convergence**: Monitor iterations and residual norms
3. **Provide good initial guesses**: Store reasonable defaults in `outputs`
4. **Implement gradients**: Critical for optimization frameworks
5. **Verify Jacobians**: Use finite differences to check your derivatives
6. **Handle edge cases**: Check for singularities, non-convergence, etc.
7. **Document residual equations**: Write the math clearly in docstrings

## Troubleshooting

### Convergence Failures

If `solve_residuals` doesn't converge:

1. Check initial guess quality
2. Try different solver parameters (tolerance, max_iterations)
3. Consider damping/relaxation in Newton steps
4. Verify residual equations are correct
5. Check for singularities in the Jacobian

### Incorrect Optimization Results

If optimization gives wrong answers:

1. Verify Jacobians with finite differences
2. Check that all partials are declared
3. Ensure `solve_residuals` actually finds the solution (residuals ≈ 0)
4. Test with analytical solutions if available

### Performance Issues

If solving is too slow:

1. Use better initial guesses (warm-starting)
2. Implement sparse Jacobian structures
3. Use more efficient linear solvers
4. Consider approximations or reduced-order models
5. Profile your code to find bottlenecks

## Next Steps

- Review [Explicit Disciplines](@ref explicit_disciplines) for comparison
- Learn about [Integration](@ref integration) to serve disciplines via gRPC
- Consult the [API Reference](@ref) for complete function documentation
