# Philote Julia Server Examples

This directory contains example programs for running Julia disciplines as Philote gRPC servers.

## Generic Launcher (Recommended)

The **`philote_julia_server`** is a generic launcher that loads Julia disciplines based on YAML configuration files. This is the recommended approach as it requires no recompilation for new disciplines.

### Usage

```bash
# Build the server
cd cpp
mkdir build && cd build
cmake .. -DPHILOTE_CPP_DIR=../../Philote-Cpp -DBUILD_EXAMPLES=ON
cmake --build .

# Run with a config file
./bin/philote_julia_server ../examples/configs/paraboloid.yaml
```

### Configuration File Format

Create a YAML file with the following structure:

```yaml
discipline:
  # Type of discipline: 'explicit' or 'implicit'
  kind: explicit

  # Path to Julia file (relative to where you run the server)
  julia_file: ../../examples/paraboloid.jl

  # Name of the Julia type
  julia_type: ParaboloidDiscipline

server:
  # gRPC server address
  address: localhost:50051
```

### Example Configurations

Two example configurations are provided:

1. **`configs/paraboloid.yaml`** - Explicit discipline (paraboloid function)
2. **`configs/quadratic_implicit.yaml`** - Implicit discipline (quadratic solver)

### Running the Examples

**Paraboloid (Explicit):**
```bash
./bin/philote_julia_server ../examples/configs/paraboloid.yaml
```

**Quadratic Implicit:**
```bash
./bin/philote_julia_server ../examples/configs/quadratic_implicit.yaml
```

### Creating Your Own Configuration

1. Write your Julia discipline (see `../../examples/` for examples)
2. Create a YAML config file pointing to your `.jl` file
3. Run: `./bin/philote_julia_server your_config.yaml`

No C++ code needed!

## Legacy: Hardcoded Server

The **`paraboloid_server`** is a hardcoded example that demonstrates the C++ API directly. It's useful for understanding how the wrapper works internally, but the generic launcher is more practical for deployment.

```bash
./bin/paraboloid_server
```

## Dependencies

- Julia (1.9+)
- Philote-Cpp
- gRPC
- Protocol Buffers
- yaml-cpp

See the main `README.md` for installation instructions.

## Troubleshooting

**Error: "Julia discipline file not found"**
- Check that the `julia_file` path in your config is correct relative to where you run the server
- Use absolute paths if needed: `julia_file: /full/path/to/discipline.jl`

**Error: "Could not find Philote.setup! function"**
- Ensure your Julia discipline implements all required methods
- Check that the `julia_type` name matches exactly

**Error: "Configuration error: Missing 'discipline' section"**
- Verify your YAML file is properly formatted
- Check for typos in section names

## Next Steps

1. Test with a Philote client (see Philote-Cpp examples)
2. Deploy multiple disciplines on different ports
3. Create your own Julia disciplines
