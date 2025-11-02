# Philote-Julia

Pure Julia implementation of Philote MDO framework with Python-based gRPC server support.

## Architecture

This implementation provides:

1. **Pure Julia Disciplines** - Write MDO disciplines in native Julia
2. **Python gRPC Server** - Serve Julia disciplines via Python + juliacall
3. **Julia gRPC Client** - Call remote Philote disciplines from Julia (planned)

### Why This Approach?

Julia currently lacks a mature gRPC server implementation. To enable serving Julia disciplines while keeping the core implementation pure Julia, we use:

- **juliacall** - Python package that embeds Julia in Python
- **grpcio** - Mature Python gRPC library
- Pure Julia for discipline logic (zero overhead)

## Writing Julia Disciplines

Julia disciplines use the same clean interface as before:

```julia
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    # Your fields here
end

function Philote.setup!(d::MyDiscipline)
    Philote.add_input!(d, "x", [1], "m")
    Philote.add_output!(d, "f", [1], "m**2")
    Philote.declare_partials!(d, "f", "x")
end

function Philote.compute(d::MyDiscipline, inputs)
    x = inputs["x"][1]
    return Dict("f" => [x^2])
end

function Philote.compute_partials(d::MyDiscipline, inputs)
    x = inputs["x"][1]
    return Dict("f" => Dict("x" => [2.0 * x]))
end
```

## Serving Julia Disciplines

### Option 1: Python Server (Recommended)

```bash
python server/julia_explicit_server.py examples/paraboloid.jl ParaboloidDiscipline
```

This:
1. Loads Julia via juliacall
2. Loads your Julia discipline
3. Serves it via gRPC

### Option 2: C++ Server (Legacy, will be removed)

Uses the old C++ wrapper approach.

## Calling Remote Disciplines from Julia

Coming soon - Julia client using gRPCClient.jl

## Dependencies

### Python
- `juliacall` - Embed Julia in Python
- `grpcio` - gRPC support
- `grpcio-tools` - Proto compilation
- `protobuf` - Protocol Buffers

### Julia
- Pure Julia, no external dependencies for disciplines
- `PythonCall.jl` - Installed automatically by juliacall
- `gRPCClient.jl` - For Julia client (planned)

## Installation

```bash
# Install Python dependencies
pip install juliacall grpcio grpcio-tools protobuf

# Julia dependencies are installed automatically
```

## Examples

See `examples/` directory:
- `paraboloid.jl` - Simple explicit discipline
- `quadratic_implicit.jl` - Implicit discipline example

## Development Status

- ✅ Pure Julia discipline interface
- ✅ Python gRPC server wrapper (juliacall)
- ✅ Proto files and generated code
- 🚧 Julia gRPC client (gRPCClient.jl)
- 📋 Documentation and examples
- 📋 Remove C++ wrapper

## Testing

```bash
# Run Julia tests
julia --project=. test/runtests.jl

# Test with existing Python client
cd /path/to/Philote-Python
python examples/parabaloid_client.py
```

## License

See LICENSE file.

## Contributing

Contributions welcome! See CONTRIBUTING.md for guidelines.
