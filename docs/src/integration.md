# [Integration with Philote-Python](@id integration)

This guide explains how to serve your Julia disciplines via gRPC using Philote-Python, enabling integration with MDO frameworks and other programming languages.

## Overview

The Philote ecosystem provides a bridge between Julia and Python-based MDO tools:

```
Julia Discipline (Philote.jl)
    ↓ loaded by juliacall
Python Wrapper (Philote-Python)
    ↓ serves via gRPC
MDO Framework (OpenMDAO, etc.)
```

This architecture allows you to:
- Write high-performance analysis code in Julia
- Integrate seamlessly with Python MDO frameworks
- Distribute computations across multiple machines
- Mix disciplines from different languages

## Installation

### 1. Install Philote.jl

If you haven't already:

```julia
using Pkg
Pkg.add("Philote")
```

### 2. Install Philote-Python with Julia Support

Install Philote-Python with the Julia optional dependency:

```bash
pip install philote-mdo[julia]
```

This installs:
- `philote-mdo`: The Python package for serving disciplines
- `juliacall`: Python-Julia bridge for zero-copy data transfer
- `grpcio`: gRPC server implementation

## Configuration

Philote-Python uses YAML configuration files to specify how to serve your Julia discipline.

### Basic Configuration Structure

```yaml
discipline:
  kind: explicit  # or 'implicit'
  julia_file: path/to/discipline.jl
  julia_type: YourDisciplineTypeName

server:
  address: "[::]:50051"
```

### Configuration Options

#### Discipline Section

- **kind** (required): `"explicit"` or `"implicit"`
  - Determines which discipline interface to use
- **julia_file** (required): Path to your Julia file
  - Can be relative or absolute
- **julia_type** (required): Name of your discipline struct
  - Must match exactly (case-sensitive)

#### Server Section

- **address** (required): Server bind address
  - `"[::]:50051"`: Listen on all interfaces (IPv6), port 50051
  - `"0.0.0.0:50051"`: Listen on all interfaces (IPv4)
  - `"localhost:50051"`: Local connections only

## Example: Serving the Paraboloid Discipline

### Step 1: Create a Configuration File

Create `config.yaml`:

```yaml
discipline:
  kind: explicit
  julia_file: examples/paraboloid.jl
  julia_type: ParaboloidDiscipline

server:
  address: "[::]:50051"
```

### Step 2: Start the Server

```bash
philote-julia-serve config.yaml
```

You should see output indicating the server has started:

```
Loading Julia discipline from examples/paraboloid.jl...
Discipline type: ParaboloidDiscipline
Server listening on [::]:50051
```

### Step 3: Connect from a Client

From Python (or any gRPC client):

```python
import grpc
from philote_mdo.client import DisciplineClient

# Connect to server
client = DisciplineClient("localhost:50051")

# Get discipline metadata
metadata = client.get_metadata()
print(f"Discipline: {metadata.name}")
print(f"Inputs: {list(metadata.inputs.keys())}")
print(f"Outputs: {list(metadata.outputs.keys())}")

# Compute
inputs = {"x": [2.0], "y": [3.0]}
outputs = client.compute(inputs)
print(f"Result: {outputs}")

# Compute gradients
partials = client.compute_partials(inputs)
print(f"Gradients: {partials}")
```

## Serving Implicit Disciplines

For implicit disciplines, the configuration is similar but with `kind: implicit`:

```yaml
discipline:
  kind: implicit
  julia_file: examples/quadratic.jl
  julia_type: QuadraticImplicitDiscipline

server:
  address: "[::]:50051"
```

Start the server:

```bash
philote-julia-serve config.yaml
```

From the client side, the interface is the same except implicit disciplines use `solve_residuals()` instead of `compute()`.

## Integration with OpenMDAO

Once your Julia discipline is served via gRPC, you can use it in OpenMDAO:

```python
import openmdao.api as om
from philote_mdo.openmdao import PhiloteExplicitComponent

# Create OpenMDAO problem
prob = om.Problem()

# Add Philote discipline as a component
prob.model.add_subsystem(
    'paraboloid',
    PhiloteExplicitComponent(server_address="localhost:50051"),
    promotes=['*']
)

# Set up and run
prob.setup()
prob.set_val('x', 2.0)
prob.set_val('y', 3.0)
prob.run_model()

# Get result
f = prob.get_val('f_xy')
print(f"f(2, 3) = {f}")
```

## Advanced Configuration

### Setting Discipline Options

You can pass options to your discipline through the configuration:

```yaml
discipline:
  kind: explicit
  julia_file: examples/paraboloid.jl
  julia_type: ParaboloidDiscipline
  options:
    scale_factor: 2.0
    offset: 10.0

server:
  address: "[::]:50051"
```

These options are passed to your discipline's `set_options!()` method on initialization.

### Multiple Servers

To serve multiple disciplines, create separate configuration files and run multiple server processes on different ports:

```yaml
# server1.yaml
discipline:
  kind: explicit
  julia_file: examples/paraboloid.jl
  julia_type: ParaboloidDiscipline
server:
  address: "[::]:50051"
```

```yaml
# server2.yaml
discipline:
  kind: implicit
  julia_file: examples/quadratic.jl
  julia_type: QuadraticImplicitDiscipline
server:
  address: "[::]:50052"  # Different port
```

Run both:

```bash
philote-julia-serve server1.yaml &
philote-julia-serve server2.yaml &
```

### Running in Docker

Create a `Dockerfile`:

```dockerfile
FROM julia:1.11

# Install Python and Philote-Python
RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip3 install philote-mdo[julia]

# Copy your Julia discipline
WORKDIR /app
COPY . .

# Install Julia dependencies
RUN julia --project -e 'using Pkg; Pkg.instantiate()'

# Expose gRPC port
EXPOSE 50051

# Start server
CMD ["philote-julia-serve", "config.yaml"]
```

Build and run:

```bash
docker build -t my-julia-discipline .
docker run -p 50051:50051 my-julia-discipline
```

## Data Transfer and Performance

### Zero-Copy Transfer

Philote-Python uses `juliacall`, which provides zero-copy data transfer between Python and Julia for arrays. This means:

- No data copying for large arrays
- Minimal overhead for function calls
- Efficient memory usage

### Performance Considerations

1. **First Call Overhead**: Julia JIT compiles on first use
   - Subsequent calls are much faster
   - Consider a warmup call after server starts

2. **Array Sizes**: gRPC has default message size limits
   - Default: 4 MB
   - Can be increased if needed

3. **Network Latency**: For distributed setups
   - Co-locate server and client when possible
   - Use faster networks for large data transfers

## Debugging

### Enable Logging

Set environment variables for more verbose output:

```bash
# Python/gRPC logging
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all

# Julia logging
export JULIA_DEBUG=all

philote-julia-serve config.yaml
```

### Common Issues

#### "ModuleNotFoundError: No module named 'philote_mdo'"

Solution: Install Philote-Python with Julia support:
```bash
pip install philote-mdo[julia]
```

#### "Could not load Julia file"

Solutions:
- Check that the path in `julia_file` is correct
- Ensure the file has the necessary `using` statements
- Verify the Julia struct name matches `julia_type`

#### "Type not found: YourDisciplineType"

Solutions:
- Check capitalization (Julia is case-sensitive)
- Ensure the struct is defined before the file ends
- Make sure the struct inherits from `ExplicitDiscipline` or `ImplicitDiscipline`

#### "Connection refused"

Solutions:
- Check that the server is running
- Verify the port matches between server config and client
- Check firewall settings if connecting remotely

## Production Deployment

### Process Management

Use a process manager like `supervisord`:

```ini
[program:julia-discipline]
command=philote-julia-serve /path/to/config.yaml
directory=/path/to/discipline
autostart=true
autorestart=true
stderr_logfile=/var/log/julia-discipline.err.log
stdout_logfile=/var/log/julia-discipline.out.log
```

### Load Balancing

For high availability, run multiple server instances and use a load balancer:

```
        ┌─→ Server 1 (port 50051)
        │
Client ─┼─→ Server 2 (port 50052)
        │
        └─→ Server 3 (port 50053)
```

Configure your load balancer (e.g., nginx, HAProxy) to distribute requests across servers.

### Security

For production deployments:

1. **Use TLS**: Configure gRPC with SSL/TLS certificates
2. **Authentication**: Implement token-based auth
3. **Network isolation**: Use VPNs or private networks
4. **Input validation**: Validate all inputs in your discipline
5. **Resource limits**: Set timeouts and memory limits

## Next Steps

- Review the [Explicit Disciplines](@ref explicit_disciplines) guide
- Explore [Implicit Disciplines](@ref implicit_disciplines)
- Check the [API Reference](@ref) for complete documentation
- Visit [Philote-Python documentation](https://github.com/mdo-standards/Philote-Python) for more details
