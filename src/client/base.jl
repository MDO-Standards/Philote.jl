# Base discipline client implementation

using gRPCClient2
using .PhiloteProto
using .PhiloteProto.google.protobuf: Empty

"""
    BaseDisciplineClient

Base client for interacting with Philote discipline servers.

This struct contains all the common gRPC clients needed to interact with
any Philote discipline (both explicit and implicit).

# Fields

  - `host::String`: Server hostname
  - `port::Int`: Server port
  - `info_client`: gRPC client for GetInfo
  - `stream_options_client`: gRPC client for SetStreamOptions
  - `available_options_client`: gRPC client for GetAvailableOptions
  - `set_options_client`: gRPC client for SetOptions
  - `setup_client`: gRPC client for Setup
  - `variable_defs_client`: gRPC client for GetVariableDefinitions
  - `partial_defs_client`: gRPC client for GetPartialDefinitions
  - `properties::Union{Nothing, DisciplineProperties}`: Cached discipline properties
  - `variables::Union{Nothing, Vector{VariableMetaData}}`: Cached variable definitions
  - `partials::Union{Nothing, Vector{PartialsMetaData}}`: Cached partial definitions
"""
mutable struct BaseDisciplineClient
    host::String
    port::Int

    # gRPC clients for DisciplineService
    info_client
    stream_options_client
    available_options_client
    set_options_client
    setup_client
    variable_defs_client
    partial_defs_client

    # Cached data
    properties::Union{Nothing, DisciplineProperties}
    variables::Union{Nothing, Vector{VariableMetaData}}
    partials::Union{Nothing, Vector{PartialsMetaData}}

    function BaseDisciplineClient(
        host::String, port::Int; secure=false, deadline=10, keepalive=60
    )
        # Initialize gRPC system if not already done
        try
            grpc_init()
        catch
            # Already initialized
        end

        # Create all the DisciplineService clients
        info_client = DisciplineService_GetInfo_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        stream_options_client = DisciplineService_SetStreamOptions_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        available_options_client = DisciplineService_GetAvailableOptions_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        set_options_client = DisciplineService_SetOptions_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        setup_client = DisciplineService_Setup_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        variable_defs_client = DisciplineService_GetVariableDefinitions_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )
        partial_defs_client = DisciplineService_GetPartialDefinitions_Client(
            host, port; secure=secure, deadline=deadline, keepalive=keepalive
        )

        return new(
            host,
            port,
            info_client,
            stream_options_client,
            available_options_client,
            set_options_client,
            setup_client,
            variable_defs_client,
            partial_defs_client,
            nothing,
            nothing,
            nothing,
        )
    end
end

"""
    get_discipline_info!(client::BaseDisciplineClient)

Retrieve discipline properties from the server and cache them.

# Arguments

  - `client`: Base discipline client

# Returns

  - `DisciplineProperties`: Discipline properties including name, version, and capabilities
"""
function get_discipline_info!(client::BaseDisciplineClient)
    if isnothing(client.properties)
        empty_msg = Empty()
        client.properties = grpc_sync_request(client.info_client, empty_msg)
    end
    return client.properties
end

"""
    set_stream_options!(client::BaseDisciplineClient; num_double::Int=10000)

Configure streaming options for array data transfer.

# Arguments

  - `client`: Base discipline client
  - `num_double`: Maximum number of doubles per array slice (default: 10000)
"""
function set_stream_options!(client::BaseDisciplineClient; num_double::Int=10000)
    options = StreamOptions(; num_double=num_double)
    grpc_sync_request(client.stream_options_client, options)
    return nothing
end

"""
    get_available_options(client::BaseDisciplineClient)

Query the discipline for available options.

# Arguments

  - `client`: Base discipline client

# Returns

  - `OptionsList`: List of available option names and their types
"""
function get_available_options(client::BaseDisciplineClient)
    empty_msg = Empty()
    return grpc_sync_request(client.available_options_client, empty_msg)
end

"""
    set_options!(client::BaseDisciplineClient, options::Dict)

Set discipline options.

# Arguments

  - `client`: Base discipline client
  - `options`: Dictionary of option names to values
"""
function set_options!(client::BaseDisciplineClient, options::Dict)
    # Convert options dict to protobuf Struct
    # For now, pass the dict directly - protobuf should handle conversion
    opts = DisciplineOptions(; options=options)
    grpc_sync_request(client.set_options_client, opts)
    return nothing
end

"""
    setup!(client::BaseDisciplineClient)

Trigger the discipline setup process on the server.

# Arguments

  - `client`: Base discipline client
"""
function setup!(client::BaseDisciplineClient)
    empty_msg = Empty()
    grpc_sync_request(client.setup_client, empty_msg)
    return nothing
end

"""
    get_variable_definitions!(client::BaseDisciplineClient)

Retrieve variable definitions from the server (streaming RPC) and cache them.

# Arguments

  - `client`: Base discipline client

# Returns

  - `Vector{VariableMetaData}`: Vector of variable metadata
"""
function get_variable_definitions!(client::BaseDisciplineClient)
    if isnothing(client.variables)
        empty_msg = Empty()
        response_channel = Channel{VariableMetaData}(16)

        # Start the streaming request
        req = grpc_async_request(client.variable_defs_client, empty_msg, response_channel)

        # Collect all variable definitions
        client.variables = collect_metadata_stream(response_channel)

        # Wait for request to complete
        grpc_async_await(req)
    end
    return client.variables
end

"""
    get_partial_definitions!(client::BaseDisciplineClient)

Retrieve partial derivative definitions from the server (streaming RPC) and cache them.

# Arguments

  - `client`: Base discipline client

# Returns

  - `Vector{PartialsMetaData}`: Vector of partial derivative metadata
"""
function get_partial_definitions!(client::BaseDisciplineClient)
    if isnothing(client.partials)
        empty_msg = Empty()
        response_channel = Channel{PartialsMetaData}(16)

        # Start the streaming request
        req = grpc_async_request(client.partial_defs_client, empty_msg, response_channel)

        # Collect all partial definitions
        client.partials = collect_metadata_stream(response_channel)

        # Wait for request to complete
        grpc_async_await(req)
    end
    return client.partials
end
