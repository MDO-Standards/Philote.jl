# Philote-Julia Documentation {#mainpage}

Welcome to the Philote-Julia documentation! This library enables you to write MDO (Multidisciplinary Design Optimization) disciplines in Julia and deploy them as gRPC services.

## Quick Links

- @ref user_guide "User Guide" - Get started creating Julia disciplines
- @ref developer_guide "Developer Guide" - Understand the internals
- @ref tutorials "Tutorials" - Step-by-step examples
- [API Reference](modules.html) - Complete API documentation

## Overview

Philote-Julia provides a hybrid architecture combining:
- **Julia Interface**: Write disciplines in Julia's high-level syntax
- **C++ Wrapper**: Embed Julia runtime and serve via gRPC
- **Full Compatibility**: Works with any Philote client

### Key Features

- ✅ **Easy to Use**: Write disciplines with just 3 Julia functions
- ✅ **Network Accessible**: Serve via gRPC to any client
- ✅ **High Performance**: Julia JIT compilation + C++ infrastructure
- ✅ **Type Safe**: Automatic validation and conversion
- ✅ **Well Documented**: Comprehensive guides and examples

## Architecture

```
┌─────────────────────────────────────┐
│   gRPC Client (Any Language)        │
└────────────┬────────────────────────┘
             │ Philote Protocol
┌────────────┴────────────────────────┐
│   C++ Server (Philote-Cpp)          │
│   ┌─────────────────────────────┐   │
│   │ JuliaExplicitDiscipline     │   │
│   └──────────┬──────────────────┘   │
│   ┌──────────┴──────────────────┐   │
│   │ Data Marshaling Layer       │   │
│   └──────────┬──────────────────┘   │
└──────────────┼──────────────────────┘
               │ Julia C API
┌──────────────┴──────────────────────┐
│   Julia Runtime                     │
│   ┌─────────────────────────────┐   │
│   │ Your Discipline (Julia)     │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Getting Started

### Installation

1. **Install Julia** (≥ 1.6)
   ```bash
   # macOS
   brew install julia

   # Linux
   wget https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-1.9.3-linux-x86_64.tar.gz
   tar -xvzf julia-1.9.3-linux-x86_64.tar.gz
   sudo mv julia-1.9.3 /opt/julia
   sudo ln -s /opt/julia/bin/julia /usr/local/bin/julia
   ```

2. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Philote-Julia.git
   cd Philote-Julia
   ```

3. **Set up Julia environment**
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

### Hello World Example

Create a simple discipline in Julia:

```julia
using Philote

mutable struct SimpleDiscipline <: Philote.ExplicitDiscipline
    SimpleDiscipline() = new()
end

function Philote.setup!(d::SimpleDiscipline)
    Philote.add_input!(d, "x", [1], "m")
    Philote.add_output!(d, "y", [1], "m**2")
end

function Philote.compute(d::SimpleDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = x^2
    return Dict("y" => [y])
end
```

Test it:
```bash
julia -e 'include("my_discipline.jl"); d = SimpleDiscipline(); Philote.setup!(d); println(Philote.compute(d, Dict("x" => [3.0])))'
```

Wrap it in a C++ server:
```cpp
#include "julia_explicit.h"
#include <grpc++/grpc++.h>

int main() {
    philote::JuliaExplicitDiscipline discipline("my_discipline.jl", "SimpleDiscipline");

    grpc::ServerBuilder builder;
    builder.AddListeningPort("localhost:50051", grpc::InsecureServerCredentials());
    discipline.RegisterServices(builder);

    auto server = builder.BuildAndStart();
    server->Wait();
}
```

## Components

### Julia Components

- **Philote Module** (`src/Philote.jl`)
  - Abstract types: `ExplicitDiscipline`, `ImplicitDiscipline`
  - Declaration API: `add_input!()`, `add_output!()`, `declare_partials!()`
  - Computation interface: `compute()`, `compute_partials()`
  - Metadata management

### C++ Components

- **JuliaRuntime** (`cpp/include/julia_runtime.h`)
  - Singleton managing Julia lifecycle
  - Module loading and function lookup
  - GC root management
  - Exception handling

- **JuliaMarshal** (`cpp/include/julia_marshal.h`)
  - Bidirectional C++/Julia data conversion
  - Type-safe marshaling
  - Shape preservation

- **JuliaExplicitDiscipline** (`cpp/include/julia_explicit.h`)
  - Main wrapper class
  - Inherits from `philote::ExplicitDiscipline`
  - Automatic metadata extraction
  - Full gRPC server integration

## Examples

See the `examples/` directory for complete examples:

- **paraboloid.jl** - Complete explicit discipline with gradients
- **paraboloid_server.cpp** - C++ server wrapping Julia discipline

## Building Documentation

Generate this documentation:

```bash
doxygen Doxyfile
```

View locally:
```bash
open docs/html/index.html
```

Deploy to GitHub Pages:
```bash
# Commit docs/html to gh-pages branch
git subtree push --prefix docs/html origin gh-pages
```

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/Philote-Julia/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/Philote-Julia/discussions)
- **Email**: support@yourproject.org

## License

MIT License - see LICENSE file for details.

## Citation

If you use Philote-Julia in your research, please cite:

```bibtex
@software{philote_julia,
  title = {Philote-Julia: Julia MDO Disciplines with gRPC},
  author = {Your Name},
  year = {2025},
  url = {https://github.com/yourusername/Philote-Julia}
}
```

## Acknowledgments

- Built on the [Philote MDO standard](https://github.com/philote/philote)
- Uses [Philote-Cpp](https://github.com/yourusername/Philote-Cpp) for gRPC infrastructure
- Powered by the [Julia programming language](https://julialang.org)
