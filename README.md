# Philote.jl

Pure Julia interface for implementing Philote MDO (Multidisciplinary Design Optimization) disciplines.

[![CI](https://github.com/MDO-Standards/Philote-Julia/actions/workflows/ci.yml/badge.svg)](https://github.com/MDO-Standards/Philote-Julia/actions/workflows/ci.yml)

## Overview

Philote.jl provides a Julia interface for creating analysis disciplines that can be used in MDO frameworks. It defines abstract types and a standardized API for both explicit and implicit disciplines.

**For serving Julia disciplines via gRPC**, see [Philote-Python](https://github.com/MDO-Standards/Philote-Python) which provides Python wrappers and server infrastructure using juliacall.

## Installation

### From Git

```julia
using Pkg
Pkg.add(url="https://github.com/MDO-Standards/Philote-Julia.git")
```

### From Local Directory (Development)

```julia
using Pkg
Pkg.develop(path="/path/to/Philote-Julia")
```

## Quick Start

```julia
using Philote

# Define a simple explicit discipline
mutable struct ParaboloidDiscipline <: Philote.ExplicitDiscipline
    ParaboloidDiscipline() = new()
end

function Philote.setup!(discipline::ParaboloidDiscipline)
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_input!(discipline, "y", [1], "m")
    Philote.add_output!(discipline, "f_xy", [1], "m^2")
    Philote.declare_partials!(discipline, "f_xy", "x")
    Philote.declare_partials!(discipline, "f_xy", "y")
end

function Philote.compute(discipline::ParaboloidDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    y = inputs["y"][1]
    f = (x - 3)^2 + x*y + (y + 4)^2
    return Dict("f_xy" => [f])
end

function Philote.compute_partials(discipline::ParaboloidDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    y = inputs["y"][1]
    df_dx = 2*(x - 3) + y
    df_dy = x + 2*(y + 4)
    return Dict(
        "f_xy" => Dict(
            "x" => reshape([df_dx], 1, 1),
            "y" => reshape([df_dy], 1, 1)
        )
    )
end

# Use the discipline
disc = ParaboloidDiscipline()
Philote.setup!(disc)
inputs = Dict("x" => [1.0], "y" => [2.0])
outputs = Philote.compute(disc, inputs)
println("f(1, 2) = ", outputs["f_xy"][1])  # 11.0
```

## Discipline Types

### Explicit Disciplines

Explicit disciplines compute outputs as a direct function of inputs: **outputs = f(inputs)**

Required methods:
- `Philote.setup!(discipline)` - Declare inputs, outputs, and partials
- `Philote.compute(discipline, inputs)` - Compute outputs from inputs

Optional methods:
- `Philote.compute_partials(discipline, inputs)` - Compute gradients

Example: `examples/paraboloid.jl`

### Implicit Disciplines

Implicit disciplines solve residual equations: **residuals(inputs, outputs) = 0**

Required methods:
- `Philote.setup!(discipline)` - Declare inputs, outputs, residuals, and partials
- `Philote.compute_residuals(discipline, inputs, outputs)` - Compute residual values
- `Philote.solve_residuals(discipline, inputs, outputs)` - Solve for outputs that drive residuals to zero

Optional methods:
- `Philote.residual_partials(discipline, inputs, outputs)` - Compute Jacobian

Example: `examples/quadratic.jl`

## API Reference

### Abstract Types

```julia
abstract type AbstractDiscipline end
abstract type ExplicitDiscipline <: AbstractDiscipline end
abstract type ImplicitDiscipline <: AbstractDiscipline end
```

### Setup Functions

```julia
setup!(discipline::AbstractDiscipline)
```
Initialize the discipline by declaring inputs, outputs, options, and partials.

```julia
add_input!(discipline::AbstractDiscipline, name::String, shape::Vector{Int}, units::String)
```
Declare an input variable.

```julia
add_output!(discipline::AbstractDiscipline, name::String, shape::Vector{Int}, units::String)
```
Declare an output variable.

```julia
add_residual!(discipline::ImplicitDiscipline, name::String, shape::Vector{Int}, units::String)
```
Declare a residual variable (implicit disciplines only).

```julia
declare_partials!(discipline::AbstractDiscipline, of::String, wrt::String)
```
Declare that partial derivatives of `of` with respect to `wrt` will be provided.

```julia
set_options!(discipline::AbstractDiscipline, options::Dict)
```
Set discipline options from a dictionary (optional method to implement).

### Explicit Discipline Functions

```julia
compute(discipline::ExplicitDiscipline, inputs::Dict{String,Array}) -> Dict{String,Array}
```
Compute outputs from inputs.

```julia
compute_partials(discipline::ExplicitDiscipline, inputs::Dict{String,Array}) -> Dict{String,Dict{String,Array}}
```
Compute partial derivatives. Returns nested dict: `output_name => input_name => jacobian`.

### Implicit Discipline Functions

```julia
compute_residuals(discipline::ImplicitDiscipline, inputs::Dict{String,Array}, outputs::Dict{String,Array}) -> Dict{String,Array}
```
Compute residual values given inputs and outputs.

```julia
solve_residuals(discipline::ImplicitDiscipline, inputs::Dict{String,Array}, outputs::Dict{String,Array})
```
Solve for outputs that drive residuals to zero. Modifies `outputs` in place.

```julia
residual_partials(discipline::ImplicitDiscipline, inputs::Dict{String,Array}, outputs::Dict{String,Array}) -> Dict{String,Dict{String,Array}}
```
Compute Jacobian of residuals. Returns nested dict: `residual_name => variable_name => jacobian`.

### Metadata Functions

```julia
get_metadata(discipline::AbstractDiscipline) -> DisciplineMetadata
```
Get discipline metadata including name, inputs, outputs, partials, and residuals.

## Data Format

All variables are represented as Julia `Array` types:
- **Scalars**: `[1]` shape - stored as single-element vectors
- **Vectors**: `[n]` shape - n-element vectors
- **Matrices**: `[m, n]` shape - m×n matrices

**Jacobians** are 2D arrays where:
- Rows correspond to output/residual elements
- Columns correspond to input/output elements
- For scalar-to-scalar: `reshape([derivative], 1, 1)`

## Examples

See `examples/` directory for complete working examples:
- `examples/paraboloid.jl` - Explicit discipline (paraboloid function)
- `examples/quadratic.jl` - Implicit discipline (quadratic equation solver)
- `examples/README.md` - Detailed documentation and templates

## Testing

Run the test suite:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Or from Julia REPL:

```julia
using Pkg
Pkg.activate(".")
Pkg.test()
```

## gRPC Client

Philote.jl now includes native Julia gRPC clients for connecting to Philote discipline servers! This allows pure Julia workflows without Python dependencies.

### Quick Start with Clients

```julia
using Philote
using Philote.Client

# Initialize gRPC
grpc_init()

# Connect to an explicit discipline server
client = ExplicitClient("localhost", 50051)

# Get discipline info
info = get_discipline_info!(client)
println("Connected to: $(info.name) v$(info.version)")

# Setup discipline
setup!(client)

# Compute function
inputs = Dict("x" => [1.0], "y" => [2.0])
outputs = compute(client, inputs)
println("f(1, 2) = ", outputs["f_xy"][1])

# Compute gradients
gradients = compute_partials(client, inputs)
```

### Client Features

**ExplicitClient** - For explicit disciplines (outputs = f(inputs)):
- `get_discipline_info!(client)` - Get discipline properties
- `setup!(client)` - Initialize discipline
- `compute(client, inputs)` - Evaluate function
- `compute_partials(client, inputs)` - Compute Jacobian
- `get_variable_definitions!(client)` - Get input/output metadata
- `get_partial_definitions!(client)` - Get derivative metadata

**ImplicitClient** - For implicit disciplines (R(inputs, outputs) = 0):
- All ExplicitClient methods plus:
- `solve_residuals(client, inputs)` - Solve for outputs
- `compute_residuals(client, inputs, outputs)` - Evaluate residuals
- `compute_residual_gradients(client, inputs, outputs)` - Compute Jacobian

### Client Examples

See complete examples:
- `examples/paraboloid_client.jl` - Explicit discipline client
- `examples/quadratic_client.jl` - Implicit discipline client

### gRPC Implementation

The Julia clients are built on [gRPCClient2.jl](https://github.com/csvance/gRPCClient2.jl), a high-performance gRPC client library for Julia.

**About gRPCClient2.jl:**
- Pure Julia gRPC client implementation using libcurl's HTTP/2 support
- Significantly faster than existing Julia gRPC alternatives
- Supports bidirectional streaming for efficient data transfer
- Minimal dependencies and straightforward API
- Not yet registered in Julia's General registry (installed from GitHub)

**Performance characteristics:**
- ~8,000+ requests/sec for small messages
- ~500+ requests/sec for large arrays (~1.6 MB)
- Concurrent request support
- Streaming for large data transfers

**Note:** gRPCClient2.jl is an unregistered package. During installation, it will be automatically fetched from GitHub. This is handled transparently by the package manager.

### Client vs Server

**Use the Julia Client when:**
- Building pure Julia MDO workflows
- Integrating with Julia optimization packages (JuMP, Optim.jl)
- You need high performance from Julia code
- You want to eliminate Python dependencies

**Use Philote-Python Server when:**
- Serving Julia disciplines to Python/C++ clients
- You have existing Python MDO tools
- You need the mature Python gRPC ecosystem

## Serving via gRPC

To serve Julia disciplines via gRPC for integration with MDO frameworks and other languages:

1. Install [Philote-Python](https://github.com/mdo-standards/Philote-Python) with Julia support:
   ```bash
   pip install philote-mdo[julia]
   ```

2. Create a YAML configuration file:
   ```yaml
   discipline:
     kind: explicit
     julia_file: examples/paraboloid.jl
     julia_type: ParaboloidDiscipline

   server:
     address: "[::]:50051"
   ```

3. Start the server:
   ```bash
   philote-julia-serve config.yaml
   ```

The Philote-Python wrapper uses `juliacall` to load your Julia code and serves it via gRPC with zero-copy data transfer.

## Project Structure

```
Philote-Julia/
├── Project.toml              # Julia package manifest
├── Manifest.toml             # Dependency lock file
├── README.md                 # This file
├── LICENSE                   # Apache 2.0 license
├── generate_proto.jl         # Protocol buffer code generation script
├── src/
│   ├── Philote.jl            # Main module implementation
│   ├── proto_includes.jl     # Protocol buffer module
│   ├── proto/                # Generated protocol buffer files
│   │   ├── philote/          # Philote protobuf messages
│   │   └── google/           # Google protobuf dependencies
│   └── client/               # gRPC client implementations
│       ├── abstract.jl       # Abstract client types
│       ├── base.jl           # BaseDisciplineClient
│       ├── explicit.jl       # ExplicitClient
│       ├── implicit.jl       # ImplicitClient
│       ├── service_clients.jl # gRPC service client generators
│       └── utils.jl          # Client utility functions
├── examples/
│   ├── paraboloid.jl         # Explicit discipline example
│   ├── paraboloid_client.jl  # Explicit discipline client example
│   ├── quadratic.jl          # Implicit discipline example
│   ├── quadratic_client.jl   # Implicit discipline client example
│   └── README.md             # Examples documentation
└── test/
    └── runtests.jl           # Test suite
```

## Development Status

**Current Version**: 0.1.0 (Alpha)

**Working**:
- ✅ Pure Julia discipline interface
- ✅ Explicit and implicit discipline support
- ✅ Metadata system
- ✅ Example disciplines (Paraboloid, Quadratic)
- ✅ Basic test suite
- ✅ gRPC serving via Philote-Python
- ✅ **NEW: Native Julia gRPC clients (ExplicitClient, ImplicitClient)**
- ✅ **NEW: Protocol buffer support via ProtoBuf.jl**
- ✅ **NEW: High-performance streaming via gRPCClient2.jl**
- ✅ **NEW: Client examples and documentation**

**Future Work**:
- ⏳ Julia-native gRPC server (client-only currently via gRPCClient2.jl)
- ⏳ Integration examples with JuMP, Optim.jl
- ⏳ Distributed optimization patterns
- ⏳ Connection pooling for concurrent evaluations
- ⏳ Additional examples and documentation
- ⏳ Performance benchmarks and optimization

## Troubleshooting

### Common Issues

**Issue**: `LoadError: ArgumentError: Package Philote not found`
- **Solution**: Make sure you've added the package using `Pkg.add(url="...")` or `Pkg.develop(path="...")`

**Issue**: `Shape dimensions must be positive integers`
- **Solution**: When declaring inputs/outputs with `add_input!` or `add_output!`, ensure all shape dimensions are positive. Use `[1]` for scalars, `[3]` for vectors, `[2, 3]` for matrices.

**Issue**: `compute_residuals must be implemented`
- **Solution**: For implicit disciplines, you must implement all required methods: `setup!`, `compute_residuals`, `solve_residuals`, and optionally `residual_partials`.

**Issue**: Tests failing with Julia version errors
- **Solution**: This package supports Julia 1.6-1.11. Ensure you're using a compatible version with `julia --version`.

### Getting Help

- Check the [examples](examples/) directory for working code
- Review the [API documentation](src/Philote.jl)
- Open an issue on GitHub for bugs or questions

## Related Projects

- **[Philote-Python](https://github.com/MDO-Standards/Philote-Python)** - Python implementation with Julia wrapper support
- **Philote-Cpp** - C++ implementation with protocol definitions

## Contributing

Contributions are welcome! Areas of interest:
- Additional example disciplines
- Documentation improvements
- Test coverage expansion
- Performance optimization
- Julia-native gRPC support

## License

Apache License 2.0 - See LICENSE file for details

## Citation

If you use Philote.jl in your research, please cite:

```
@inproceedings{PhilotePaper,
author = {Christopher A. Lupp and Alexander Xu},
title = {Creating a Universal Communication Standard to Enable Heterogeneous Multidisciplinary Design Optimization},
booktitle = {AIAA SCITECH 2024 Forum},
pages = {1--22},
doi = {10.2514/6.2024-1799},
}
```
