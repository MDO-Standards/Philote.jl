"""
    Paraboloid Client Example

This example demonstrates how to connect to a Paraboloid discipline server
using the Julia gRPC client.

# Prerequisites
1. Start a Philote discipline server running the Paraboloid discipline
2. The server should be accessible at localhost:50051 (or modify host/port below)

# Starting a server (using Python Philote wrapper):
```bash
# In Philote-Python directory:
python -m philote.julia.cli serve examples/paraboloid.jl ParaboloidDiscipline --port 50051
```

Or use the philote-julia-serve command if installed:
```bash
philote-julia-serve /path/to/Philote.jl/examples/paraboloid.jl ParaboloidDiscipline --port 50051
```
"""

# Load the Philote module
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Philote
using Philote.Client

function main()
    println("=" ^ 70)
    println("Paraboloid Discipline Client Example")
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
        client = ExplicitClient(host, port)
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

        # Set options
        println("Setting options...")
        set_options!(client, Dict("scale_factor" => 2.0, "offset" => 10.0))
        println("✓ Options set: scale_factor=2.0, offset=10.0")
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
        println("✓ Partials (∂output/∂input):")
        for partial in partials
            println("  - ∂$(partial.name)/∂$(partial.subname): shape=$(partial.shape)")
        end
        println()

        # Compute function at several points
        println("Computing function values...")
        test_points = [
            (x=0.0, y=0.0),
            (x=3.0, y=-4.0),
            (x=1.0, y=2.0),
        ]

        for point in test_points
            inputs = Dict(
                "x" => [point.x],
                "y" => [point.y]
            )

            outputs = compute(client, inputs)
            f_xy = outputs["f_xy"][1]

            # Expected value with options: ((x-3)^2 + x*y + (y+4)^2 - 3) * 2.0 + 10.0
            expected = ((point.x - 3)^2 + point.x * point.y + (point.y + 4)^2 - 3) * 2.0 + 10.0

            println("  f($(point.x), $(point.y)) = $f_xy (expected: $expected)")
        end
        println()

        # Compute gradients at a point
        println("Computing gradients at x=1.0, y=2.0...")
        inputs = Dict("x" => [1.0], "y" => [2.0])
        gradients = compute_partials(client, inputs)

        println("✓ Gradients:")
        for (key, value) in gradients
            println("  - $key = $(value[1])")
        end
        println()

        # Expected gradients (with scale_factor=2.0):
        # df/dx = 2 * ((2*(x-3) + y)) = 2 * (2*(1-3) + 2) = 2 * (-2) = -4
        # df/dy = 2 * ((x + 2*(y+4))) = 2 * (1 + 2*(2+4)) = 2 * 13 = 26
        println("Expected gradients:")
        x, y = 1.0, 2.0
        df_dx = 2.0 * (2 * (x - 3) + y)
        df_dy = 2.0 * (x + 2 * (y + 4))
        println("  - f_xy:x = $df_dx")
        println("  - f_xy:y = $df_dy")
        println()

        println("=" ^ 70)
        println("✓ Example completed successfully!")
        println("=" ^ 70)

    catch e
        println("✗ Error: $e")
        println()
        println("Make sure a Philote Paraboloid discipline server is running at $host:$port")
        println("Start one using:")
        println("  philote-julia-serve examples/paraboloid.jl ParaboloidDiscipline --port $port")
        rethrow(e)
    end
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
