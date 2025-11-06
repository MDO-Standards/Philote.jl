# Utility functions for Philote gRPC clients

using .PhiloteProto

"""
    create_array_message(name::String, data::AbstractVector{Float64};
                         subname::String="", type::VariableType.T=VariableType.kInput)

Create a Philote Array message from Julia data.

# Arguments
- `name`: Variable name
- `data`: Vector of Float64 data
- `subname`: Optional sub-name (for partials)
- `type`: Variable type (kInput, kOutput, kResidual, kPartial)

# Returns
- `PhiloteProto.philote.var"#Array"`: Protocol buffer array message
"""
function create_array_message(
    name::String,
    data::AbstractVector{Float64};
    subname::String="",
    type=PhiloteProto.philote.VariableType.kInput
)
    return PhiloteProto.philote.var"#Array"(
        name=name,
        subname=subname,
        start=0,
        _end=length(data),
        type=type,
        data=collect(data)
    )
end

"""
    create_input_arrays(inputs::Dict{String, <:AbstractVector{Float64}})

Create a vector of Array messages from a dictionary of inputs.

# Arguments
- `inputs`: Dictionary mapping variable names to Float64 vectors

# Returns
- `Vector{PhiloteProto.philote.var"#Array"}`: Vector of protocol buffer array messages
"""
function create_input_arrays(inputs::Dict{String, <:AbstractVector{Float64}})
    return [
        create_array_message(name, data; type=PhiloteProto.philote.VariableType.kInput)
        for (name, data) in inputs
    ]
end

"""
    parse_array_messages(arrays::Vector{PhiloteProto.philote.var"#Array"})

Parse a vector of Array messages into a dictionary.

# Arguments
- `arrays`: Vector of protocol buffer array messages

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping variable names to data vectors
"""
function parse_array_messages(arrays::Vector)
    result = Dict{String, Vector{Float64}}()
    for arr in arrays
        result[arr.name] = arr.data
    end
    return result
end

"""
    collect_stream_to_dict(channel::Channel)

Collect all Array messages from a streaming channel into a dictionary.

# Arguments
- `channel`: Channel containing Array messages

# Returns
- `Dict{String, Vector{Float64}}`: Dictionary mapping variable names to data vectors
"""
function collect_stream_to_dict(channel::Channel)
    arrays = []
    for arr in channel
        push!(arrays, arr)
    end
    return parse_array_messages(arrays)
end

"""
    collect_metadata_stream(channel::Channel{T}) where T

Collect all metadata messages from a streaming channel.

# Arguments
- `channel`: Channel containing metadata messages (VariableMetaData or PartialsMetaData)

# Returns
- `Vector{T}`: Vector of metadata messages
"""
function collect_metadata_stream(channel::Channel{T}) where T
    result = T[]
    for item in channel
        push!(result, item)
    end
    return result
end
