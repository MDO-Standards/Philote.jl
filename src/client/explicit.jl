# Explicit discipline client implementation

using gRPCClient2
using .PhiloteProto

"""
    ExplicitClient <: AbstractExplicitClient

Client for interacting with explicit Philote disciplines via gRPC.

Explicit disciplines compute outputs directly from inputs: `outputs = f(inputs)`

# Fields
- `base::BaseDisciplineClient`: Base client for common operations
- `compute_client`: gRPC client for ComputeFunction
- `gradient_client`: gRPC client for ComputeGradient

# Example
```julia
using Philote
using Philote.Client

# Initialize gRPC
grpc_init()

# Create client
client = ExplicitClient("localhost", 50051)

# Get discipline info
info = get_discipline_info!(client)
println("Connected to: ", info.name, " v", info.version)

# Setup the discipline
setup!(client)

# Get variable definitions
variables = get_variable_definitions!(client)

# Compute function
inputs = Dict("x" => [1.0], "y" => [2.0])
outputs = compute(client, inputs)
println("Outputs: ", outputs)

# Compute gradients
gradients = compute_partials(client, inputs)
println("Gradients: ", gradients)
```
"""
mutable struct ExplicitClient <: AbstractExplicitClient
    base::BaseDisciplineClient
    compute_client
    gradient_client

    function ExplicitClient(host::String, port::Int; secure=false, deadline=10, keepalive=60)
        base = BaseDisciplineClient(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        compute_client = ExplicitService_ComputeFunction_Client(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        gradient_client = ExplicitService_ComputeGradient_Client(host, port; secure=secure, deadline=deadline, keepalive=keepalive)
        return new(base, compute_client, gradient_client)
    end
end

# Forward base methods to the base client
get_discipline_info!(client::ExplicitClient) = get_discipline_info!(client.base)
set_stream_options!(client::ExplicitClient; kwargs...) = set_stream_options!(client.base; kwargs...)
get_available_options(client::ExplicitClient) = get_available_options(client.base)
set_options!(client::ExplicitClient, options::Dict) = set_options!(client.base, options)
setup!(client::ExplicitClient) = setup!(client.base)
get_variable_definitions!(client::ExplicitClient) = get_variable_definitions!(client.base)
get_partial_definitions!(client::ExplicitClient) = get_partial_definitions!(client.base)

"""
    compute(client::ExplicitClient, inputs::Dict{String, <:AbstractVector{Float64}})

Compute outputs from inputs using the remote explicit discipline.

This performs a bidirectional streaming RPC where inputs are sent and outputs are received.

# Arguments
- `client`: Explicit discipline client
- `inputs`: Dictionary mapping input variable names to Float64 vectors

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping output variable names to data vectors

# Example
```julia
inputs = Dict("x" => [1.0, 2.0], "y" => [3.0, 4.0])
outputs = compute(client, inputs)
```
"""
function compute(client::ExplicitClient, inputs::Dict{String, <:AbstractVector{Float64}})
    # Create input channel
    request_channel = Channel{PhiloteProto.philote.var"#Array"}(16)
    response_channel = Channel{PhiloteProto.philote.var"#Array"}(16)

    # Start the bidirectional streaming request
    req = grpc_async_request(client.compute_client, request_channel, response_channel)

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
    compute_partials(client::ExplicitClient, inputs::Dict{String, <:AbstractVector{Float64}})

Compute partial derivatives (Jacobian) at the given inputs.

This performs a bidirectional streaming RPC where inputs are sent and partials are received.

# Arguments
- `client`: Explicit discipline client
- `inputs`: Dictionary mapping input variable names to Float64 vectors

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping partial derivative names to data vectors
  The keys follow the convention "output_name:input_name" for partials ∂output/∂input

# Example
```julia
inputs = Dict("x" => [1.0], "y" => [2.0])
partials = compute_partials(client, inputs)
# partials might contain:
# "f:x" => [2.0]  # ∂f/∂x
# "f:y" => [3.0]  # ∂f/∂y
```
"""
function compute_partials(client::ExplicitClient, inputs::Dict{String, <:AbstractVector{Float64}})
    # Create channels
    request_channel = Channel{PhiloteProto.philote.var"#Array"}(16)
    response_channel = Channel{PhiloteProto.philote.var"#Array"}(16)

    # Start the bidirectional streaming request
    req = grpc_async_request(client.gradient_client, request_channel, response_channel)

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

    # Collect partials - they come back with name and subname set
    partials = Dict{String, Vector{Float64}}()
    for arr in response_channel
        # Construct key as "name:subname" for partials
        if !isempty(arr.subname)
            key = "$(arr.name):$(arr.subname)"
        else
            key = arr.name
        end
        partials[key] = arr.data
    end

    # Wait for request to complete
    grpc_async_await(req)

    return partials
end
