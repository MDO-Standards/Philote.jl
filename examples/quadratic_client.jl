"""
    Quadratic Client Example

This example demonstrates how to connect to a Quadratic (implicit) discipline server
using the Julia gRPC client.

The Quadratic discipline solves: ax² + bx + c = 0

# Prerequisites
1. Start a Philote discipline server running the Quadratic discipline
2. The server should be accessible at localhost:50051 (or modify host/port below)

# Starting a server (using Python Philote wrapper):
```bash
# In Philote-Python directory:
python -m philote.julia.cli serve examples/quadratic.jl QuadraticDiscipline --port 50051
```

Or use the philote-julia-serve command if installed:
```bash
philote-julia-serve /path/to/Philote.jl/examples/quadratic.jl QuadraticDiscipline --port 50051
```
"""

# Load the Philote module
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Philote
using Philote.Client

function main()
    println("=" ^ 70)
    println("Quadratic Discipline Client Example")
    println("=" ^ 70)
    println()

    # Initialize gRPC system
    println("Initializing gRPC...")
    grpc_init()
    println("✓ gRPC initialized")
    println()

    # Connect to discipline server
    host = "localhost"
    port = 50051
    println("Connecting to discipline server at $host:$port...")

    try
        client = ImplicitClient(host, port)
        println("✓ Connected to server")
        println()

        # Get discipline information
        println("Getting discipline info...")
        info = get_discipline_info!(client)
        println("✓ Discipline: $(info.name) v$(info.version)")
        println("  - Continuous: $(info.continuous)")
        println("  - Differentiable: $(info.differentiable)")
        println("  - Provides gradients: $(info.provides_gradients)")
        println()

        # Get available options
        println("Getting available options...")
        options = get_available_options(client)
        println("✓ Available options:")
        for (i, (name, type)) in enumerate(zip(options.options, options.type))
            println("  $i. $name (type: $type)")
        end
        println()

        # Setup discipline
        println("Running setup...")
        setup!(client)
        println("✓ Setup complete")
        println()

        # Get variable definitions
        println("Getting variable definitions...")
        variables = get_variable_definitions!(client)
        println("✓ Variables:")
        for var in variables
            println("  - $(var.name): shape=$(var.shape), units=$(var.units), type=$(var.type)")
        end
        println()

        # Get partial definitions
        println("Getting partial definitions...")
        partials = get_partial_definitions!(client)
        println("✓ Partials (∂residual/∂variable):")
        for partial in partials
            println("  - ∂$(partial.name)/∂$(partial.subname): shape=$(partial.shape)")
        end
        println()

        # Solve quadratic equations
        println("Solving quadratic equations...")
        test_cases = [
            (a=1.0, b=0.0, c=-4.0, desc="x² - 4 = 0"),  # solution: x = 2
            (a=1.0, b=-3.0, c=2.0, desc="x² - 3x + 2 = 0"),  # solution: x = 2 or x = 1
            (a=2.0, b=4.0, c=-6.0, desc="2x² + 4x - 6 = 0"),  # solution: x = 1 or x = -3
        ]

        for (i, case) in enumerate(test_cases)
            println("\nTest case $i: $(case.desc)")
            inputs = Dict(
                "a" => [case.a],
                "b" => [case.b],
                "c" => [case.c]
            )

            # Solve for x
            outputs = solve_residuals(client, inputs)
            x_solution = outputs["x"][1]
            println("  Solution: x = $x_solution")

            # Verify by computing residuals (should be near zero)
            residuals = compute_residuals(client, inputs, outputs)
            R_value = residuals["R"][1]
            println("  Residual R = $R_value (should be ≈ 0)")

            # Compute expected residual manually
            expected_R = case.a * x_solution^2 + case.b * x_solution + case.c
            println("  Expected R = $expected_R")

            # Check analytical solution
            discriminant = case.b^2 - 4 * case.a * case.c
            if discriminant >= 0
                x1 = (-case.b + sqrt(discriminant)) / (2 * case.a)
                x2 = (-case.b - sqrt(discriminant)) / (2 * case.a)
                println("  Analytical solutions: x₁ = $x1, x₂ = $x2")
            end
        end
        println()

        # Compute gradients at a solution
        println("Computing gradients at a solution point...")
        inputs = Dict("a" => [1.0], "b" => [-3.0], "c" => [2.0])
        outputs = solve_residuals(client, inputs)
        x_solution = outputs["x"][1]

        gradients = compute_residual_gradients(client, inputs, outputs)
        println("✓ Gradients at x = $x_solution:")
        for (key, value) in gradients
            println("  - $key = $(value[1])")
        end
        println()

        # Expected gradients for R = ax² + bx + c:
        # ∂R/∂a = x²
        # ∂R/∂b = x
        # ∂R/∂c = 1
        # ∂R/∂x = 2ax + b
        println("Expected gradients:")
        a, b, c = 1.0, -3.0, 2.0
        println("  - R:a = $(x_solution^2)")
        println("  - R:b = $x_solution")
        println("  - R:c = 1.0")
        println("  - R:x = $(2 * a * x_solution + b)")
        println()

        println("=" ^ 70)
        println("✓ Example completed successfully!")
        println("=" ^ 70)

    catch e
        println("✗ Error: $e")
        println()
        println("Make sure a Philote Quadratic discipline server is running at $host:$port")
        println("Start one using:")
        println("  philote-julia-serve examples/quadratic.jl QuadraticDiscipline --port $port")
        rethrow(e)
    end
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
