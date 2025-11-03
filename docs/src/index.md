# Philote.jl

Philote.jl is a pure Julia interface for implementing Multidisciplinary Design Optimization (MDO) disciplines. It provides a standardized API for defining analysis components that can be integrated into MDO frameworks and served to optimization tools through the Philote ecosystem.

## What is Philote?

Philote is an ecosystem of tools for building and connecting MDO disciplines across different programming languages:

- **Philote.jl**: This package - implements disciplines in Julia
- **Philote-Python**: Python library that wraps and serves Julia disciplines via gRPC
- **Philote-Cpp**: Protocol buffer definitions for language-agnostic communication

Together, these components enable you to write high-performance analysis code in Julia and integrate it seamlessly with MDO frameworks like OpenMDAO.

## Features

- **Two Discipline Types**: Support for both explicit and implicit formulations
- **Gradient Support**: First-class support for analytic gradients through `compute_partials` and `residual_partials`
- **Type-Safe**: Leverage Julia's type system for robust discipline definitions
- **Zero External Dependencies**: Pure Julia implementation with no external package requirements
- **Metadata Management**: Automatic tracking of inputs, outputs, residuals, and options
- **Integration Ready**: Designed to work seamlessly with Philote-Python for gRPC serving

## Quick Example

Here's a simple explicit discipline that computes a paraboloid function:

```julia
using Philote

struct ParaboloidDiscipline <: ExplicitDiscipline end

function Philote.setup!(discipline::ParaboloidDiscipline)
    add_input!(discipline, "x", 1, "m")
    add_input!(discipline, "y", 1, "m")
    add_output!(discipline, "f", 1, "m^2")
    declare_partials!(discipline, "f", "x")
    declare_partials!(discipline, "f", "y")
end

function Philote.compute(discipline::ParaboloidDiscipline, inputs)
    x = inputs["x"][1]
    y = inputs["y"][1]
    f = (x - 3.0)^2 + x * y + (y + 4.0)^2 - 3.0
    return Dict("f" => [f])
end

function Philote.compute_partials(discipline::ParaboloidDiscipline, inputs)
    x = inputs["x"][1]
    y = inputs["y"][1]
    df_dx = 2.0 * (x - 3.0) + y
    df_dy = x + 2.0 * (y + 4.0)
    return Dict("f" => Dict("x" => [df_dx], "y" => [df_dy]))
end
```

## Installation

Philote.jl can be installed using Julia's package manager:

```julia
using Pkg
Pkg.add("Philote")
```

Or from the Julia REPL package mode (press `]`):

```
pkg> add Philote
```

## Getting Started

New to Philote or MDO? Start here:

1. [**MDO Concepts**](@ref concepts): Learn about disciplines, explicit vs implicit formulations, and gradients
2. [**Tutorial**](@ref tutorial): Step-by-step guide to creating your first discipline
3. [**Explicit Disciplines**](@ref explicit_disciplines): Detailed guide with examples
4. [**Implicit Disciplines**](@ref implicit_disciplines): Working with residual equations
5. [**Integration**](@ref integration): Serving disciplines with Philote-Python

## Documentation Structure

- **Getting Started**: Concepts and tutorials for newcomers
- **User Guide**: Detailed guides for explicit and implicit disciplines, plus integration patterns
- **API Reference**: Complete API documentation with all functions and types

## Contributing

Philote.jl is open source and welcomes contributions! Visit the [GitHub repository](https://github.com/chrislupp/Philote-Julia) to:

- Report issues
- Submit pull requests
- Request features
- Ask questions

## License

Philote.jl is licensed under the Apache License 2.0. See the LICENSE file for details.

## Citation

If you use Philote.jl in your research, please cite:

```bibtex
@inproceedings{Lupp2024,
  author = {Lupp, Christopher A.},
  title = {Philote: A Modular Framework for Gradient-Enhanced Multidisciplinary Design Optimization},
  booktitle = {AIAA AVIATION FORUM AND ASCEND 2024},
  year = {2024},
  doi = {10.2514/6.2024-4443}
}
```
