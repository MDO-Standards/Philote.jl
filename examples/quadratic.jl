"""
    Quadratic Implicit Discipline Example

This example implements a simple implicit discipline that solves a quadratic equation:
    R(x) = ax² + bx + c = 0

The discipline takes coefficients (a, b, c) as inputs and solves for x.
This demonstrates:
- Residual equation definition
- Iterative solving
- Jacobian computation for residuals
"""

# Load the Philote module from the parent directory
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote

"""
    QuadraticImplicitDiscipline <: ImplicitDiscipline

Solves a quadratic equation ax² + bx + c = 0 using the quadratic formula.

Inputs:
- a (float): Coefficient of x²
- b (float): Coefficient of x
- c (float): Constant term

Outputs:
- x (float): Solution to the equation (positive root)

Residuals:
- R (float): Residual value (should be zero at solution)

The residual is defined as:
    R(x) = ax² + bx + c

The Jacobian is:
    dR/dx = 2ax + b
    dR/da = x²
    dR/db = x
    dR/dc = 1
"""
mutable struct QuadraticImplicitDiscipline <: Philote.ImplicitDiscipline
    tolerance::Float64
    max_iterations::Int

    function QuadraticImplicitDiscipline()
        new(1e-10, 100)
    end
end

"""
    setup!(discipline::QuadraticImplicitDiscipline)

Declare inputs, outputs, residuals, and partials for the quadratic solver.
"""
function Philote.setup!(discipline::QuadraticImplicitDiscipline)
    # Declare options
    Philote.add_option!(discipline, "tolerance", "float")
    Philote.add_option!(discipline, "max_iterations", "int")

    # Declare inputs (coefficients)
    Philote.add_input!(discipline, "a", [1], "1")
    Philote.add_input!(discipline, "b", [1], "1")
    Philote.add_input!(discipline, "c", [1], "1")

    # Declare outputs (solution)
    Philote.add_output!(discipline, "x", [1], "1")

    # Declare residuals
    Philote.add_residual!(discipline, "R", [1], "1")

    # Declare partials
    # Residual partials with respect to outputs (state variables)
    Philote.declare_partials!(discipline, "R", "x")

    # Residual partials with respect to inputs
    Philote.declare_partials!(discipline, "R", "a")
    Philote.declare_partials!(discipline, "R", "b")
    Philote.declare_partials!(discipline, "R", "c")

    # Set metadata
    meta = Philote.get_metadata(discipline)
    meta.name = "QuadraticImplicitDiscipline"
    meta.version = "0.1.0"
end

"""
    set_options!(discipline::QuadraticImplicitDiscipline, options::Dict{String, <:Any})

Set configuration options for the quadratic solver.
"""
function Philote.set_options!(discipline::QuadraticImplicitDiscipline, options::Dict{String, <:Any})
    if haskey(options, "tolerance")
        discipline.tolerance = Float64(options["tolerance"])
    end
    if haskey(options, "max_iterations")
        discipline.max_iterations = Int(options["max_iterations"])
    end
end

"""
    compute_residuals(discipline::QuadraticImplicitDiscipline, inputs::Dict, outputs::Dict)

Compute the residual R(x) = ax² + bx + c given current values of inputs and outputs.

For implicit disciplines, both inputs and the current guess for outputs
are needed to compute residuals.
"""
function Philote.compute_residuals(discipline::QuadraticImplicitDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}},
                                   outputs::Dict{String, <:AbstractArray{Float64}})
    # Extract coefficients from inputs
    a = inputs["a"][1]
    b = inputs["b"][1]
    c = inputs["c"][1]

    # Extract current value of x (output/state variable)
    x = outputs["x"][1]

    # Compute residual: R = ax² + bx + c
    R = a * x^2 + b * x + c

    return Dict("R" => [R])
end

"""
    solve_residuals(discipline::QuadraticImplicitDiscipline, inputs::Dict, outputs::Dict)

Solve for x that makes the residual zero using the quadratic formula.
Modifies the outputs dictionary in place.

For ax² + bx + c = 0:
    x = (-b ± sqrt(b² - 4ac)) / (2a)

We use the positive root (using +).
"""
function Philote.solve_residuals(discipline::QuadraticImplicitDiscipline,
                                 inputs::Dict{String, <:AbstractArray{Float64}},
                                 outputs::Dict{String, <:AbstractArray{Float64}})
    # Extract coefficients
    a = inputs["a"][1]
    b = inputs["b"][1]
    c = inputs["c"][1]

    # Check for degenerate cases
    if abs(a) < 1e-14
        # Linear equation: bx + c = 0
        if abs(b) < 1e-14
            error("Degenerate equation: both a and b are zero")
        end
        x = -c / b
    else
        # Quadratic formula
        discriminant = b^2 - 4*a*c

        if discriminant < 0
            error("No real solutions: discriminant = $discriminant < 0")
        end

        # Return the positive root (or more positive if both are negative)
        sqrt_disc = sqrt(discriminant)
        x1 = (-b + sqrt_disc) / (2*a)
        x2 = (-b - sqrt_disc) / (2*a)

        # Choose root with larger absolute value (arbitrary choice for example)
        x = abs(x1) > abs(x2) ? x1 : x2
    end

    # Modify outputs in place
    outputs["x"][1] = x
    return nothing
end

"""
    residual_partials(discipline::QuadraticImplicitDiscipline, inputs::Dict, outputs::Dict)

Compute the Jacobian of the residual with respect to inputs and outputs.

For R(x) = ax² + bx + c:
    dR/dx = 2ax + b
    dR/da = x²
    dR/db = x
    dR/dc = 1
"""
function Philote.residual_partials(discipline::QuadraticImplicitDiscipline,
                                   inputs::Dict{String, <:AbstractArray{Float64}},
                                   outputs::Dict{String, <:AbstractArray{Float64}})
    # Extract values
    a = inputs["a"][1]
    b = inputs["b"][1]
    c = inputs["c"][1]
    x = outputs["x"][1]

    # Compute partials
    dR_dx = 2.0 * a * x + b
    dR_da = x^2
    dR_db = x
    dR_dc = 1.0

    # Return as nested dictionary
    return Dict(
        "R" => Dict(
            "x" => [dR_dx],
            "a" => [dR_da],
            "b" => [dR_db],
            "c" => [dR_dc]
        )
    )
end

# Example usage when run as a standalone script
if abspath(PROGRAM_FILE) == @__FILE__
    println("Quadratic Implicit Discipline Example")
    println("=" ^ 50)

    # Create discipline instance
    discipline = QuadraticImplicitDiscipline()

    # Setup discipline
    Philote.setup!(discipline)

    # Print metadata
    meta = Philote.get_metadata(discipline)
    println("Discipline: $(meta.name) v$(meta.version)")
    println("\nInputs:")
    for (name, (shape, units)) in meta.inputs
        println("  $name: shape=$(shape), units=$units")
    end
    println("\nOutputs:")
    for (name, (shape, units)) in meta.outputs
        println("  $name: shape=$(shape), units=$units")
    end
    println("\nResiduals:")
    for (name, (shape, units)) in meta.residuals
        println("  $name: shape=$(shape), units=$units")
    end
    println("\nPartials:")
    for (output, input) in meta.partials
        println("  ∂$output/∂$input")
    end

    # Test Case 1: Standard quadratic x² - 5x + 6 = 0
    # Solutions: x = 2 or x = 3
    println("\n" * "=" ^ 50)
    println("Test Case 1: x² - 5x + 6 = 0")
    println("=" ^ 50)

    inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0])
    println("Coefficients: a=$(inputs["a"][1]), b=$(inputs["b"][1]), c=$(inputs["c"][1])")

    # Solve for x
    outputs = Dict("x" => [0.0])  # Initial guess
    Philote.solve_residuals(discipline, inputs, outputs)
    x_solution = outputs["x"][1]
    println("Solution: x = $x_solution")

    # Verify residual is zero
    residuals = Philote.compute_residuals(discipline, inputs, outputs)
    println("Residual at solution: R = $(residuals["R"][1])")

    # Compute partials
    partials = Philote.residual_partials(discipline, inputs, outputs)
    println("Partials:")
    println("  dR/dx = $(partials["R"]["x"][1])")
    println("  dR/da = $(partials["R"]["a"][1])")
    println("  dR/db = $(partials["R"]["b"][1])")
    println("  dR/dc = $(partials["R"]["c"][1])")

    # Test Case 2: x² - 2x - 3 = 0
    # Solutions: x = 3 or x = -1
    println("\n" * "=" ^ 50)
    println("Test Case 2: x² - 2x - 3 = 0")
    println("=" ^ 50)

    inputs2 = Dict("a" => [1.0], "b" => [-2.0], "c" => [-3.0])
    println("Coefficients: a=$(inputs2["a"][1]), b=$(inputs2["b"][1]), c=$(inputs2["c"][1])")

    outputs2 = Dict("x" => [0.0])
    Philote.solve_residuals(discipline, inputs2, outputs2)
    x_solution2 = outputs2["x"][1]
    println("Solution: x = $x_solution2")

    residuals2 = Philote.compute_residuals(discipline, inputs2, outputs2)
    println("Residual at solution: R = $(residuals2["R"][1])")

    # Test Case 3: 2x² + 3x - 2 = 0
    println("\n" * "=" ^ 50)
    println("Test Case 3: 2x² + 3x - 2 = 0")
    println("=" ^ 50)

    inputs3 = Dict("a" => [2.0], "b" => [3.0], "c" => [-2.0])
    println("Coefficients: a=$(inputs3["a"][1]), b=$(inputs3["b"][1]), c=$(inputs3["c"][1])")

    outputs3 = Dict("x" => [0.0])
    Philote.solve_residuals(discipline, inputs3, outputs3)
    x_solution3 = outputs3["x"][1]
    println("Solution: x = $x_solution3")

    residuals3 = Philote.compute_residuals(discipline, inputs3, outputs3)
    println("Residual at solution: R = $(residuals3["R"][1]) (should be ≈ 0)")
end
