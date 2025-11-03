# [MDO Concepts](@id concepts)

This page introduces the core concepts of Multidisciplinary Design Optimization (MDO) and how Philote.jl implements them.

## What is a Discipline?

In MDO, a **discipline** is a computational component that represents a specific analysis or simulation. Disciplines take inputs, perform computations, and produce outputs. Examples include:

- Aerodynamics analysis (takes geometry, outputs forces and moments)
- Structural analysis (takes loads, outputs stresses and deflections)
- Propulsion analysis (takes throttle settings, outputs thrust and fuel consumption)
- Cost estimation (takes design parameters, outputs manufacturing costs)

Disciplines are the building blocks of MDO problems. They can be connected together to form complex multidisciplinary analyses where the output of one discipline becomes the input to another.

## Explicit vs Implicit Disciplines

Philote.jl supports two fundamental types of disciplines, each suited to different types of analyses:

### Explicit Disciplines

An **explicit discipline** directly computes outputs from inputs using a function:

```
outputs = f(inputs)
```

**Characteristics:**
- Direct computation: outputs are calculated in one step
- No iteration required
- Fast evaluation
- Examples: algebraic equations, lookup tables, surrogate models

**Example:** A drag coefficient calculator that takes Mach number and angle of attack and directly returns the drag coefficient.

### Implicit Disciplines

An **implicit discipline** solves a system of residual equations to find outputs:

```
residuals(inputs, outputs) = 0
```

The discipline must find values of `outputs` that make the residuals equal to zero (or near zero) for given `inputs`.

**Characteristics:**
- Requires iterative solving
- More computationally expensive
- Necessary for complex physics
- Examples: CFD solvers, FEA solvers, nonlinear equations

**Example:** A trim analysis that iteratively adjusts control surface deflections until all moments on an aircraft are balanced (residuals = 0).

### When to Use Each Type

| Use Explicit When | Use Implicit When |
|-------------------|-------------------|
| Direct formula available | Iterative solution required |
| No coupling/feedback | Solving equilibrium conditions |
| Fast lookup needed | Physics demands implicit solve |
| Creating surrogate models | Using existing solver codes |

## Gradients and Derivatives

Modern MDO relies heavily on gradient-based optimization algorithms. These algorithms use derivatives (gradients) to efficiently navigate the design space and find optimal solutions.

### Why Gradients Matter

Gradient-based optimizers (like SNOPT, IPOPT, SLSQP) are much more efficient than gradient-free methods (like genetic algorithms) for problems with many design variables. They can find optimal solutions with fewer function evaluations.

### Types of Derivatives in Philote

#### Partials (Explicit Disciplines)

For explicit disciplines, **partials** are the derivatives of outputs with respect to inputs:

```
∂output/∂input
```

For example, if `f = x² + 2xy`, then:
- `∂f/∂x = 2x + 2y`
- `∂f/∂y = 2x`

In Philote.jl, you compute these in the `compute_partials` function.

#### Jacobians (Implicit Disciplines)

For implicit disciplines, the **Jacobian** contains derivatives of residuals with respect to both inputs and outputs:

```
∂residuals/∂inputs  and  ∂residuals/∂outputs
```

In Philote.jl, you provide these in the `residual_partials` function.

### Analytic vs Finite Difference Gradients

**Analytic gradients** (hand-derived or automatic differentiation):
- Exact (no approximation error)
- Fast to compute
- Always preferred when available

**Finite differences** (numerical approximation):
- Introduces truncation error
- Requires multiple function evaluations
- Fallback when analytic derivatives unavailable

Philote.jl allows you to provide analytic gradients through the gradient functions. If you don't implement them, the framework can fall back to finite differences, but analytic derivatives are strongly recommended for performance.

## Variables in Philote

Disciplines work with three types of variables:

### Inputs

Values provided to the discipline from outside (other disciplines or design variables).

```julia
add_input!(discipline, "mach", 1, "unitless")
add_input!(discipline, "altitude", 1, "m")
```

### Outputs (Explicit)

Values computed by an explicit discipline.

```julia
add_output!(discipline, "drag", 1, "N")
add_output!(discipline, "lift", 1, "N")
```

### Residuals (Implicit)

Equations that must equal zero in an implicit discipline.

```julia
add_residual!(discipline, "moment_balance", 3, "N*m")
```

### Options

Configuration parameters that affect discipline behavior but aren't optimization variables.

```julia
add_option!(discipline, "tolerance", Float64)
add_option!(discipline, "max_iterations", Int)
```

## Variable Shapes and Arrays

All variables in Philote.jl have a **shape** (size). Shapes allow you to work with:

- **Scalars**: `shape = 1` (single value)
- **Vectors**: `shape = n` (array of values)
- **Matrices**: `shape = m * n` (flattened in row-major order)

For example, a 3D position vector:

```julia
add_input!(discipline, "position", 3, "m")  # [x, y, z]
```

Or a transformation matrix (3×3 = 9 elements):

```julia
add_output!(discipline, "rotation_matrix", 9, "unitless")
```

## Units

While Philote.jl stores unit strings for documentation, it does **not enforce unit checking or conversion**. You are responsible for ensuring dimensional consistency.

Best practices:
- Choose a consistent unit system (SI is recommended)
- Document units clearly in your `add_input!`/`add_output!` calls
- Be careful when integrating disciplines from different sources

## The Discipline Lifecycle

Every Philote discipline follows this lifecycle:

1. **Definition**: Create a struct that inherits from `ExplicitDiscipline` or `ImplicitDiscipline`
2. **Setup**: Implement `setup!()` to declare inputs, outputs, and options
3. **Configuration**: (Optional) Implement `set_options!()` to process option values
4. **Computation**: Implement `compute()` or `solve_residuals()`/`compute_residuals()`
5. **Gradients**: (Optional but recommended) Implement gradient functions
6. **Execution**: The framework calls your functions as needed during optimization

## Metadata Management

Philote.jl automatically manages metadata about your discipline:

```julia
metadata = get_metadata(discipline)
```

This metadata includes:
- Declared inputs, outputs, residuals
- Declared partials/Jacobians
- Options and their values
- Discipline name and version

You typically don't interact with metadata directly - the framework handles it for you.

## Integration with Optimization Frameworks

While Philote.jl can be used standalone in Julia, it's designed to integrate with MDO frameworks through the Philote-Python wrapper:

```
Julia Discipline (Philote.jl)
    ↓
Python Wrapper (Philote-Python)
    ↓
gRPC Server
    ↓
MDO Framework (OpenMDAO, etc.)
```

This architecture allows you to:
- Write high-performance analysis code in Julia
- Integrate seamlessly with Python-based MDO tools
- Distribute disciplines across multiple machines
- Mix disciplines from different languages

See the [Integration Guide](@ref integration) for details on serving your disciplines.

## Next Steps

Now that you understand the core concepts:

1. Follow the [Tutorial](@ref tutorial) to create your first discipline
2. Learn about [Explicit Disciplines](@ref explicit_disciplines) in detail
3. Explore [Implicit Disciplines](@ref implicit_disciplines)
4. Review the [API Reference](@ref) for complete function documentation
