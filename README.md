# Philote-Julia

Python wrapper for hosting Julia disciplines in the Philote MDO (Multidisciplinary Design Optimization) framework.

## Overview

Philote-Julia enables you to write high-performance analysis disciplines in pure Julia and serve them via gRPC using the Philote protocol. This allows Julia code to seamlessly integrate with MDO frameworks and other Philote clients written in Python, C++, or any other language.

## Architecture

The Philote-Julia library uses a Python wrapper approach:

- **Pure Julia Interface** (src/Philote.jl): Defines the discipline interface for implementing disciplines in Julia
- **Python Wrapper** (philote_julia/): Uses `juliacall` to load Julia code and wrap it as a Python Philote discipline
- **Python gRPC Server** (from Philote-Python): Hosts the wrapped discipline using proven server infrastructure
- **YAML Configuration**: No-code interface for deploying Julia disciplines

This approach leverages:
- ✓ Pure Julia for modeling (no C++ bindings required)
- ✓ Proven Philote-Python gRPC server infrastructure
- ✓ Zero-copy data transfer via juliacall
- ✓ Full Philote protocol compatibility
- ✓ Simple YAML-based deployment

## Installation

### Prerequisites
- Python 3.7+
- Julia 1.6+
- Access to Philote-Python (in `~/tools/Philote/Philote-Python` or in PYTHONPATH)

### Install Philote-Julia

```bash
cd Philote-Julia
pip install -e .
```

This installs the `philote-julia-serve` command and all dependencies.

## Quick Start

### 1. Write a Julia Discipline

Create a Julia file (e.g., `my_discipline.jl`):

```julia
using Philote

mutable struct MyDiscipline <: Philote.ExplicitDiscipline
    function MyDiscipline()
        new()
    end
end

function Philote.setup!(discipline::MyDiscipline)
    # Define inputs and outputs
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_output!(discipline, "y", [1], "m^2")

    # Declare partial derivatives
    Philote.declare_partials!(discipline, "y", "x")
end

function Philote.compute(discipline::MyDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    y = x^2
    return Dict("y" => [y])
end

function Philote.compute_partials(discipline::MyDiscipline, inputs::Dict{String,Array})
    x = inputs["x"][1]
    dy_dx = 2*x
    return Dict("y" => Dict("x" => reshape([dy_dx], 1, 1)))
end
```

### 2. Create a Configuration File

Create `my_config.yaml`:

```yaml
discipline:
  kind: explicit
  julia_file: my_discipline.jl
  julia_type: MyDiscipline

server:
  address: "[::]:50051"
```

### 3. Start the Server

```bash
philote-julia-serve my_config.yaml
```

That's it! Your Julia discipline is now accessible via gRPC on port 50051.

### 4. Connect from a Client

```python
import grpc
import philote_mdo.general as pmdo

# Connect to server
channel = grpc.insecure_channel("localhost:50051")
client = pmdo.ExplicitClient(channel=channel)

# Use the discipline
client.run_setup()
outputs = client.run_compute({"x": [3.0]})
print(outputs)  # {'y': [9.0]}
```

## Creating Disciplines

### Explicit Disciplines

Explicit disciplines compute outputs as a direct function of inputs: `outputs = f(inputs)`.

```julia
mutable struct ParaboloidDiscipline <: Philote.ExplicitDiscipline
    function ParaboloidDiscipline()
        new()
    end
end

function Philote.setup!(discipline::ParaboloidDiscipline)
    # Inputs
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_input!(discipline, "y", [1], "m")

    # Outputs
    Philote.add_output!(discipline, "f_xy", [1], "m^2")

    # Partials
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
```

### Required Methods

Every discipline must implement:

1. `Philote.setup!(discipline)` - Declare inputs, outputs, and partials
2. `Philote.compute(discipline, inputs)` - Compute outputs from inputs

Optional methods:

3. `Philote.compute_partials(discipline, inputs)` - Compute gradients (if `provides_gradients = true`)
4. `Philote.set_options!(discipline, options)` - Set discipline options from config

See `examples/paraboloid.jl` for a complete example.

## Configuration Files

Configuration files use YAML format. See `examples/configs/` for examples.

### Complete Configuration

```yaml
discipline:
  kind: explicit              # Required: "explicit" or "implicit"
  julia_file: path/to/file.jl # Required: Path to Julia file
  julia_type: DisciplineType  # Required: Julia struct name

  # Optional: Discipline options
  options:
    param1: value1
    param2: value2

server:
  address: "[::]:50051"       # Optional: Server address (default: [::]:50051)
  max_workers: 10             # Optional: Thread pool size (default: 10)
```

For more details, see `examples/configs/README.md`.

## Command-Line Usage

### Basic Usage

```bash
# Serve a discipline from a config file
philote-julia-serve config.yaml

# Using Python module directly
python -m philote_julia.cli config.yaml
```

### Without Config File (Programmatic)

You can also use the library programmatically:

```python
from philote_julia import JuliaWrapperDiscipline, PhiloteConfig, DisciplineConfig, ServerConfig
from philote_julia.servers import serve_explicit_discipline

# Create configuration
config = PhiloteConfig(
    discipline=DisciplineConfig(
        kind="explicit",
        julia_file="examples/paraboloid.jl",
        julia_type="ParaboloidDiscipline"
    ),
    server=ServerConfig(address="[::]:50051")
)

# Start server
serve_explicit_discipline(config)
```

## Examples

The `examples/` directory contains:

- `paraboloid.jl` - Simple explicit discipline (paraboloid function)
- `configs/paraboloid.yaml` - Configuration for serving paraboloid
- `serve_julia_discipline.py` - Programmatic server startup (backward compatibility)
- `julia_wrapper_discipline.py` - Direct wrapper usage (backward compatibility)

## Directory Structure

```
Philote-Julia/
├── philote_julia/           # Python package
│   ├── __init__.py
│   ├── config.py            # YAML configuration loading
│   ├── wrapper_discipline.py # Julia wrapper discipline
│   ├── cli.py               # Command-line interface
│   └── servers/
│       ├── __init__.py
│       └── explicit.py      # Explicit discipline server
├── src/
│   └── Philote.jl           # Pure Julia interface
├── examples/
│   ├── paraboloid.jl        # Example discipline
│   └── configs/
│       ├── paraboloid.yaml  # Example config
│       └── README.md        # Config documentation
├── bin/
│   └── philote-julia-serve  # Executable entry point
├── setup.py                 # Package installer
└── README.md                # This file
```

## Troubleshooting

### Import Errors

- Ensure Philote-Python is in `~/tools/Philote/Philote-Python` or in your PYTHONPATH
- Install juliacall: `pip install juliacall`
- Reinstall package: `pip install -e .`

### Julia Load Errors

- Verify the Julia type name matches exactly (case-sensitive)
- Check that your Julia file is syntactically correct
- Ensure the Julia type extends `AbstractDiscipline` or `ExplicitDiscipline`

### Server Won't Start

- Check that the port isn't already in use
- Try a different port in the config file
- Check server logs for detailed error messages

### Connection Errors

- Ensure server address matches client address
- Check firewall settings
- Verify server is running before connecting client

## How It Works

The implementation uses a multi-layer architecture:

1. **Julia Layer**: Pure Julia disciplines implementing the Philote.jl interface
2. **Python Wrapper**: `JuliaWrapperDiscipline` loads Julia code via juliacall and presents a Python discipline interface
3. **gRPC Server**: Philote-Python's `ExplicitServer` hosts the wrapped discipline
4. **Protocol**: Standard Philote gRPC protocol for MDO

Data flow:
```
Client → gRPC → Python Server → JuliaWrapperDiscipline → juliacall → Pure Julia Code
```

Benefits:
- Julia code remains pure (no FFI code needed)
- Proven server infrastructure from Philote-Python
- Efficient zero-copy data transfer via juliacall
- Full protocol compatibility

## Development

### Running Tests

```bash
# Start server
philote-julia-serve examples/configs/paraboloid.yaml

# In another terminal, run client
python test_client.py
```

### Contributing

Contributions are welcome! Please ensure:
- Julia code follows standard Julia style
- Python code follows PEP 8
- All examples work correctly
- Documentation is updated

## License

[Add license information here]

## Related Projects

- **Philote-Python**: Python implementation of Philote MDO framework
- **Philote-Cpp**: C++ implementation with protocol definitions
- **juliacall**: Python-Julia integration library

## Status

**Current Status**: Alpha - Working implementation with YAML configuration support

**Working**:
- ✅ Pure Julia discipline interface
- ✅ Python wrapper via juliacall
- ✅ YAML-based configuration
- ✅ Command-line server tool
- ✅ Explicit disciplines
- ✅ Gradient computation

**Future Work**:
- ⏳ Implicit discipline support
- ⏳ Comprehensive test suite
- ⏳ Performance benchmarks
- ⏳ Additional examples
- ⏳ Julia-native gRPC server (when ecosystem matures)
