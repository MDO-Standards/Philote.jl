"""
    Philote

Julia interface for creating Philote MDO disciplines that can be wrapped
by C++ servers using the Julia embedding API.

This module defines the interface that Julia disciplines must implement
to be compatible with the Philote-Cpp wrapper.
"""
module Philote

export AbstractDiscipline, ExplicitDiscipline, ImplicitDiscipline
export setup!, compute, compute_partials
export add_input!, add_output!, add_option!, declare_partials!
export get_metadata

"""
    AbstractDiscipline

Base type for all Philote disciplines implemented in Julia.

Users should subtype `ExplicitDiscipline` or `ImplicitDiscipline` rather
than this abstract type directly.
"""
abstract type AbstractDiscipline end

"""
    ExplicitDiscipline <: AbstractDiscipline

Base type for explicit disciplines of the form: outputs = f(inputs)

Explicit disciplines must implement:
- `setup!(discipline)` - declare inputs, outputs, options
- `compute(discipline, inputs)` - compute outputs from inputs
- `compute_partials(discipline, inputs)` - compute gradients (optional)
"""
abstract type ExplicitDiscipline <: AbstractDiscipline end

"""
    ImplicitDiscipline <: AbstractDiscipline

Base type for implicit disciplines with residual equations.

Implicit disciplines must implement:
- `setup!(discipline)` - declare inputs, outputs, residuals, options
- `compute_residuals(discipline, inputs)` - compute residual values
- `solve_residuals(discipline, inputs)` - solve for outputs
- `compute_residual_partials(discipline, inputs)` - compute Jacobian (optional)
"""
abstract type ImplicitDiscipline <: AbstractDiscipline end

# Metadata storage for discipline configuration
mutable struct DisciplineMetadata
    inputs::Dict{String, Tuple{Vector{Int64}, String}}  # name => (shape, units)
    outputs::Dict{String, Tuple{Vector{Int64}, String}}
    residuals::Dict{String, Tuple{Vector{Int64}, String}}
    options::Dict{String, String}  # name => type
    partials::Vector{Tuple{String, String}}  # (output, input) pairs
    name::String
    version::String
end

function DisciplineMetadata()
    DisciplineMetadata(
        Dict{String, Tuple{Vector{Int64}, String}}(),
        Dict{String, Tuple{Vector{Int64}, String}}(),
        Dict{String, Tuple{Vector{Int64}, String}}(),
        Dict{String, String}(),
        Vector{Tuple{String, String}}(),
        "UnnamedDiscipline",
        "0.1.0"
    )
end

# Global metadata storage keyed by discipline instance
const DISCIPLINE_METADATA = Dict{UInt, DisciplineMetadata}()

"""
    get_metadata(discipline::AbstractDiscipline)

Get the metadata object for a discipline instance.
"""
function get_metadata(discipline::AbstractDiscipline)
    id = objectid(discipline)
    if !haskey(DISCIPLINE_METADATA, id)
        DISCIPLINE_METADATA[id] = DisciplineMetadata()
    end
    return DISCIPLINE_METADATA[id]
end

"""
    add_input!(discipline, name::String, shape::Vector{Int64}, units::String)

Declare an input variable for the discipline.

# Arguments
- `discipline`: The discipline instance
- `name`: Variable name
- `shape`: Array shape (e.g., [1] for scalar, [3, 3] for 3x3 matrix)
- `units`: Physical units (e.g., "m", "kg", "m**2")
"""
function add_input!(discipline::AbstractDiscipline, name::String,
                    shape::Vector{Int64}, units::String)
    meta = get_metadata(discipline)
    meta.inputs[name] = (shape, units)
end

"""
    add_output!(discipline, name::String, shape::Vector{Int64}, units::String)

Declare an output variable for the discipline.
"""
function add_output!(discipline::AbstractDiscipline, name::String,
                     shape::Vector{Int64}, units::String)
    meta = get_metadata(discipline)
    meta.outputs[name] = (shape, units)
end

"""
    add_residual!(discipline, name::String, shape::Vector{Int64}, units::String)

Declare a residual variable for implicit disciplines.
"""
function add_residual!(discipline::ImplicitDiscipline, name::String,
                      shape::Vector{Int64}, units::String)
    meta = get_metadata(discipline)
    meta.residuals[name] = (shape, units)
end

"""
    add_option!(discipline, name::String, type::String)

Declare a configuration option for the discipline.

# Arguments
- `discipline`: The discipline instance
- `name`: Option name
- `type`: Option type ("float", "int", "bool", "string")
"""
function add_option!(discipline::AbstractDiscipline, name::String, type::String)
    meta = get_metadata(discipline)
    meta.options[name] = type
end

"""
    declare_partials!(discipline, output::String, input::String)

Declare that the discipline can compute the partial derivative ∂output/∂input.
"""
function declare_partials!(discipline::AbstractDiscipline, output::String, input::String)
    meta = get_metadata(discipline)
    push!(meta.partials, (output, input))
end

"""
    setup!(discipline::AbstractDiscipline)

Initialize the discipline by declaring all inputs, outputs, and options.

This method must be implemented by all discipline subtypes.

# Example
```julia
function setup!(d::MyDiscipline)
    add_input!(d, "x", [1], "m")
    add_input!(d, "y", [1], "m")
    add_output!(d, "f", [1], "m**2")
    add_option!(d, "scale", "float")
    declare_partials!(d, "f", "x")
    declare_partials!(d, "f", "y")
end
```
"""
function setup!(discipline::AbstractDiscipline)
    error("setup! must be implemented for $(typeof(discipline))")
end

"""
    compute(discipline::ExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})

Compute outputs from inputs for an explicit discipline.

# Arguments
- `discipline`: The discipline instance
- `inputs`: Dictionary mapping input names to arrays

# Returns
- Dictionary mapping output names to arrays

# Example
```julia
function compute(d::MyDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = inputs["y"][1]
    f = x^2 + y^2
    return Dict("f" => [f])
end
```
"""
function compute(discipline::ExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    error("compute must be implemented for $(typeof(discipline))")
end

"""
    compute_partials(discipline::ExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})

Compute partial derivatives for an explicit discipline.

# Returns
- Nested dictionary: Dict{String, Dict{String, AbstractArray{Float64}}}
  - First level keys are output names
  - Second level keys are input names
  - Values are Jacobian matrices

# Example
```julia
function compute_partials(d::MyDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    x = inputs["x"][1]
    y = inputs["y"][1]
    return Dict(
        "f" => Dict(
            "x" => [2.0 * x],
            "y" => [2.0 * y]
        )
    )
end
```
"""
function compute_partials(discipline::ExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    # Default: no gradients provided
    return Dict{String, Dict{String, Vector{Float64}}}()
end

"""
    compute_residuals(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})

Compute residual values for an implicit discipline.

# Returns
- Dictionary mapping residual names to arrays
"""
function compute_residuals(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    error("compute_residuals must be implemented for $(typeof(discipline))")
end

"""
    solve_residuals(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})

Solve for outputs that drive residuals to zero.

# Returns
- Dictionary mapping output names to arrays
"""
function solve_residuals(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    error("solve_residuals must be implemented for $(typeof(discipline))")
end

"""
    compute_residual_partials(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})

Compute partial derivatives of residuals for an implicit discipline.

# Returns
- Nested dictionary: Dict{String, Dict{String, AbstractArray{Float64}}}
"""
function compute_residual_partials(discipline::ImplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
    # Default: no gradients provided
    return Dict{String, Dict{String, Vector{Float64}}}()
end

end # module
