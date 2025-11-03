# Philote-Julia

> **Note: This repository has been reorganized. Julia discipline server support has moved to [Philote-Python](https://github.com/mdo-standards/Philote-Python).**
>
> **For serving Julia disciplines via gRPC, please use `philote-mdo[julia]` from Philote-Python.**

Pure Julia interface for the Philote MDO (Multidisciplinary Design Optimization) framework.

## Overview

Philote-Julia provides the pure Julia interface (`src/Philote.jl`) for implementing Philote disciplines in Julia. This allows you to write high-performance analysis disciplines in pure Julia.

## Repository Organization

- **This repo (Philote-Julia)**: Contains the pure Julia interface (`src/Philote.jl`) for implementing disciplines
- **[Philote-Python](https://github.com/mdo-standards/Philote-Python)**: Contains the Python wrapper and gRPC server for serving Julia disciplines

## Quick Start - Serving Julia Disciplines

To serve Julia disciplines via gRPC, use Philote-Python with the Julia extras:

### Installation

```bash
pip install philote-mdo[julia]
```

This installs:
- The Philote-Python framework
- Julia integration via `juliacall`
- The `philote-julia-serve` command

### Usage

Create a Julia file implementing a Philote discipline:

```julia
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    function MyDiscipline()
        new()
    end
end

function Philote.setup!(discipline::MyDiscipline)
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_output!(discipline, "y", [1], "m^2")
    Philote.declare_partials!(discipline, "y", "x")
end

function Philote.compute(discipline::MyDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    return Dict("y" => [x^2])
end

function Philote.compute_partials(discipline::MyDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    return Dict("y" => Dict("x" => reshape([2*x], 1, 1)))
end
```

Create a YAML config file:

```yaml
discipline:
  kind: explicit
  julia_file: my_discipline.jl
  julia_type: MyDiscipline

server:
  address: "[::]:50051"
```

Serve it:

```bash
philote-julia-serve my_config.yaml
```

For complete documentation, examples, and usage instructions, see the [Philote-Python Julia wrapper documentation](https://github.com/mdo-standards/Philote-Python).

## Julia Interface (src/Philote.jl)

This repository contains the pure Julia interface for implementing Philote disciplines.

### Explicit Disciplines

Explicit disciplines compute outputs as a direct function of inputs: `outputs = f(inputs)`.

Required methods:
- `Philote.setup!(discipline)` - Declare inputs, outputs, and partials
- `Philote.compute(discipline, inputs)` - Compute outputs from inputs
- `Philote.compute_partials(discipline, inputs)` - Compute gradients (optional)

### Implicit Disciplines

Implicit disciplines solve residual equations: `residuals(inputs, outputs) = 0`.

Required methods:
- `Philote.setup!(discipline)` - Declare inputs, outputs, residuals, and partials
- `Philote.compute_residuals(discipline, inputs, outputs)` - Compute residual values
- `Philote.solve_residuals(discipline, inputs, outputs)` - Solve for outputs
- `Philote.residual_partials(discipline, inputs, outputs)` - Compute Jacobian (optional)

### Examples

See `examples/paraboloid.jl` and `examples/quadratic.jl` for complete examples of explicit and implicit disciplines.

## Repository Organization

The Julia discipline server support (Python wrapper, gRPC server, CLI, configuration) has been moved to [Philote-Python](https://github.com/mdo-standards/Philote-Python) to better organize language-specific bindings and wrappers.

**This repository now contains**:
- `src/Philote.jl` - Pure Julia interface
- `examples/` - Example Julia disciplines

**For server functionality, see [Philote-Python](https://github.com/mdo-standards/Philote-Python)**:
- Julia wrapper (via juliacall)
- gRPC server infrastructure
- YAML configuration
- CLI tool (`philote-julia-serve`)

## Status

**Working**:
- ✅ Pure Julia discipline interface (explicit and implicit)
- ✅ Example disciplines
- ✅ Server support via Philote-Python

**Future Work**:
- ⏳ Julia-native gRPC server (when ecosystem matures)
- ⏳ Pure Julia client library
