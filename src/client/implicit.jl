# Implicit discipline client implementation

using gRPCClient2
using .PhiloteProto

"""
    ImplicitClient <: AbstractImplicitClient

Client for interacting with implicit Philote disciplines via gRPC.

Implicit disciplines solve residual equations: `R(inputs, outputs) = 0`

# Fields
- `base::BaseDisciplineClient`: Base client for common operations
- `residuals_client`: gRPC client for ComputeResiduals
- `solve_client`: gRPC client for SolveResiduals
- `gradients_client`: gRPC client for ComputeResidualGradients

# Example
```julia
using Philote
using Philote.Client

# Initialize gRPC
grpc_init()

# Create client
client = ImplicitClient("localhost", 50051)

# Get discipline info
info = get_discipline_info!(client)
println("Connected to: ", info.name, " v", info.version)

# Setup the discipline
setup!(client)

# Solve for outputs given inputs
inputs = Dict("a" => [1.0], "b" => [2.0], "c" => [-3.0])
outputs = solve_residuals(client, inputs)
println("Outputs: ", outputs)

# Compute residuals for verification
residuals = compute_residuals(client, inputs, outputs)
println("Residuals (should be near zero): ", residuals)
```
"""
mutable struct ImplicitClient <: AbstractImplicitClient
    base::BaseDisciplineClient
    residuals_client
    solve_client
    gradients_client

    function ImplicitClient(host::String, port::Int; secure=false, deadline=10, keepalive=60)
        base = BaseDisciplineClient(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        residuals_client = ImplicitService_ComputeResiduals_Client(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        solve_client = ImplicitService_SolveResiduals_Client(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        gradients_client = ImplicitService_ComputeResidualGradients_Client(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        return new(base, residuals_client, solve_client, gradients_client)
    end
end

# Forward base methods to the base client
get_discipline_info!(client::ImplicitClient) = get_discipline_info!(client.base)
set_stream_options!(client::ImplicitClient; kwargs...) = set_stream_options!(client.base; kwargs...)
get_available_options(client::ImplicitClient) = get_available_options(client.base)
set_options!(client::ImplicitClient, options::Dict) = set_options!(client.base, options)
setup!(client::ImplicitClient) = setup!(client.base)
get_variable_definitions!(client::ImplicitClient) = get_variable_definitions!(client.base)
get_partial_definitions!(client::ImplicitClient) = get_partial_definitions!(client.base)

"""
    compute_residuals(client::ImplicitClient,
                      inputs::Dict{String, <:AbstractVector{Float64}},
                      outputs::Dict{String, <:AbstractVector{Float64}})

Compute residuals R(inputs, outputs) for the implicit discipline.

For implicit disciplines, residuals should equal zero when outputs satisfy the equations.

# Arguments
- `client`: Implicit discipline client
- `inputs`: Dictionary mapping input variable names to Float64 vectors
- `outputs`: Dictionary mapping output variable names to Float64 vectors

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping residual variable names to data vectors

# Example
```julia
inputs = Dict("a" => [1.0], "b" => [2.0], "c" => [-3.0])
outputs = Dict("x" => [1.0], "y" => [2.0])
residuals = compute_residuals(client, inputs, outputs)
```
"""
function compute_residuals(
    client::ImplicitClient,
    inputs::Dict{String, <:AbstractVector{Float64}},
    outputs::Dict{String, <:AbstractVector{Float64}}
)
    # Create channels
    request_channel = Channel{PhiloteProto.philote.var"#Array"}(16)
    response_channel = Channel{PhiloteProto.philote.var"#Array"}(16)

    # Start the bidirectional streaming request
    req = grpc_async_request(client.residuals_client, request_channel, response_channel)

    # Send inputs and outputs
    @async begin
        try
            for (name, data) in inputs
                arr = create_array_message(name, data; type=PhiloteProto.philote.VariableType.kInput)
                put!(request_channel, arr)
            end
            for (name, data) in outputs
                arr = create_array_message(name, data; type=PhiloteProto.philote.VariableType.kOutput)
                put!(request_channel, arr)
            end
        finally
            close(request_channel)
        end
    end

    # Collect residuals
    residuals = collect_stream_to_dict(response_channel)

    # Wait for request to complete
    grpc_async_await(req)

    return residuals
end

"""
    solve_residuals(client::ImplicitClient, inputs::Dict{String, <:AbstractVector{Float64}})

Solve for outputs such that R(inputs, outputs) = 0.

This calls the discipline's nonlinear solver to find outputs that satisfy the residual equations.

# Arguments
- `client`: Implicit discipline client
- `inputs`: Dictionary mapping input variable names to Float64 vectors

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping output variable names to solution vectors

# Example
```julia
# For a quadratic equation: ax² + bx + c = 0
inputs = Dict("a" => [1.0], "b" => [2.0], "c" => [-3.0])
outputs = solve_residuals(client, inputs)
# outputs["x"] will contain the solution
```
"""
function solve_residuals(
    client::ImplicitClient,
    inputs::Dict{String, <:AbstractVector{Float64}}
)
    # Create channels
    request_channel = Channel{PhiloteProto.philote.var"#Array"}(16)
    response_channel = Channel{PhiloteProto.philote.var"#Array"}(16)

    # Start the bidirectional streaming request
    req = grpc_async_request(client.solve_client, request_channel, response_channel)

    # Send inputs
    @async begin
        try
            for (name, data) in inputs
                arr = create_array_message(name, data; type=PhiloteProto.philote.VariableType.kInput)
                put!(request_channel, arr)
            end
        finally
            close(request_channel)
        end
    end

    # Collect outputs
    outputs = collect_stream_to_dict(response_channel)

    # Wait for request to complete
    grpc_async_await(req)

    return outputs
end

"""
    compute_residual_gradients(client::ImplicitClient,
                               inputs::Dict{String, <:AbstractVector{Float64}},
                               outputs::Dict{String, <:AbstractVector{Float64}})

Compute the Jacobian of residuals with respect to inputs and outputs.

For implicit disciplines, this computes ∂R/∂inputs and ∂R/∂outputs.

# Arguments
- `client`: Implicit discipline client
- `inputs`: Dictionary mapping input variable names to Float64 vectors
- `outputs`: Dictionary mapping output variable names to Float64 vectors

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping partial derivative names to data vectors
  The keys follow the convention "residual_name:variable_name"

# Example
```julia
inputs = Dict("a" => [1.0], "b" => [2.0], "c" => [-3.0])
outputs = Dict("x" => [1.0])
gradients = compute_residual_gradients(client, inputs, outputs)
# gradients might contain:
# "R:a" => [1.0]  # ∂R/∂a
# "R:x" => [2.0]  # ∂R/∂x
```
"""
function compute_residual_gradients(
    client::ImplicitClient,
    inputs::Dict{String, <:AbstractVector{Float64}},
    outputs::Dict{String, <:AbstractVector{Float64}}
)
    # Create channels
    request_channel = Channel{PhiloteProto.philote.var"#Array"}(16)
    response_channel = Channel{PhiloteProto.philote.var"#Array"}(16)

    # Start the bidirectional streaming request
    req = grpc_async_request(client.gradients_client, request_channel, response_channel)

    # Send inputs and outputs
    @async begin
        try
            for (name, data) in inputs
                arr = create_array_message(name, data; type=PhiloteProto.philote.VariableType.kInput)
                put!(request_channel, arr)
            end
            for (name, data) in outputs
                arr = create_array_message(name, data; type=PhiloteProto.philote.VariableType.kOutput)
                put!(request_channel, arr)
            end
        finally
            close(request_channel)
        end
    end

    # Collect gradients - they come back with name and subname set
    gradients = Dict{String, Vector{Float64}}()
    for arr in response_channel
        # Construct key as "name:subname" for partials
        if !isempty(arr.subname)
            key = "$(arr.name):$(arr.subname)"
        else
            key = arr.name
        end
        gradients[key] = arr.data
    end

    # Wait for request to complete
    grpc_async_await(req)

    return gradients
end
