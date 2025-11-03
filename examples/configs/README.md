# Philote-Julia Configuration Files

This directory contains YAML configuration files for serving Julia disciplines via the Philote-Julia server.

## Quick Start

```bash
# Install the package (from Philote-Julia directory)
pip install -e .

# Serve a discipline using a config file
philote-julia-serve examples/configs/paraboloid.yaml
```

## Configuration File Format

Configuration files use YAML format with two main sections: `discipline` and `server`.

### Complete Example

```yaml
discipline:
  kind: explicit              # Required: "explicit" or "implicit"
  julia_file: ../paraboloid.jl  # Required: Path to .jl file
  julia_type: ParaboloidDiscipline  # Required: Julia struct name

  # Optional: Discipline options
  options:
    scale_factor: 2.0
    debug: true

server:
  address: "[::]:50051"       # Optional: Server address (default: [::]:50051)
  max_workers: 10             # Optional: Thread pool size (default: 10)
```

### Discipline Section

#### `kind` (required)
The type of discipline:
- `explicit`: Disciplines with outputs = f(inputs)
- `implicit`: Disciplines with residuals = 0 (not yet implemented)

#### `julia_file` (required)
Path to the Julia file containing your discipline code.
- Can be relative to the config file location
- Can be an absolute path
- Must contain a Julia struct/type matching `julia_type`

#### `julia_type` (required)
Name of the Julia struct to instantiate. This type must:
- Extend `AbstractDiscipline` (or `ExplicitDiscipline` for explicit disciplines)
- Implement `Philote.setup!(discipline)`
- Implement `Philote.compute(discipline, inputs)`
- Optionally implement `Philote.compute_partials(discipline, inputs)` for gradients

#### `options` (optional)
Dictionary of options to pass to the Julia discipline via `set_options!()`.
Values will be converted to appropriate Julia types.

### Server Section

#### `address` (optional, default: `"[::]:50051"`)
The gRPC server address to bind to:
- `"[::]:PORT"` - Listen on all interfaces (IPv4 and IPv6)
- `"localhost:PORT"` - Listen only on localhost
- `"0.0.0.0:PORT"` - Listen on all IPv4 interfaces

#### `max_workers` (optional, default: `10`)
Maximum number of worker threads for the gRPC server.

## Creating Your Own Config

1. Write your Julia discipline (see `../paraboloid.jl` for an example)
2. Create a YAML config file:

```yaml
discipline:
  kind: explicit
  julia_file: path/to/your/discipline.jl
  julia_type: YourDisciplineName

server:
  address: "[::]:50051"
```

3. Serve it:
```bash
philote-julia-serve your_config.yaml
```

## Example Configs

### `paraboloid.yaml`
Basic explicit discipline computing a paraboloid function.
```bash
philote-julia-serve examples/configs/paraboloid.yaml
```

## Testing Your Server

Once the server is running, you can test it with a Philote client:

```python
# From Philote-Python
import philote_mdo.general as pmdo

# Connect to server
client = pmdo.ExplicitClient(address="localhost:50051")

# Get discipline info
info = client.get_discipline_info()
print(f"Discipline: {info.name}")

# Run setup
client.run_setup()

# Compute
inputs = {"x": [2.0], "y": [3.0]}
outputs = client.run_compute(inputs)
print(f"Outputs: {outputs}")
```

## Troubleshooting

### File Not Found Errors
- Ensure `julia_file` path is correct (relative to YAML file or absolute)
- Check that the Julia file exists and contains the specified type

### Import Errors
- Make sure Philote-Julia is installed: `pip install -e .`
- Ensure Philote-Python is accessible (in `~/tools/Philote/Philote-Python` or in PYTHONPATH)
- Install juliacall: `pip install juliacall`

### Julia Load Errors
- Verify the Julia type name matches exactly (case-sensitive)
- Ensure the Julia discipline implements required methods
- Check Julia syntax errors in the .jl file

## Advanced Usage

### Multiple Servers
You can run multiple servers on different ports by creating separate config files:

```yaml
# server1.yaml
server:
  address: "[::]:50051"

# server2.yaml
server:
  address: "[::]:50052"
```

### Custom Options
Pass configuration to your Julia discipline:

```yaml
discipline:
  options:
    num_iterations: 100
    tolerance: 1.0e-6
    verbose: true
```

These will be passed to your Julia `set_options!()` function if implemented.
