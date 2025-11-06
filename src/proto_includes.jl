# Protocol Buffer Includes
# This file loads all the generated protocol buffer files

module PhiloteProto

using ProtoBuf
import ProtoBuf as PB

# Include google protobuf definitions (needed for Empty and Struct)
include("proto/google/google.jl")
using .google

# Include philote protocol buffer definitions
include("proto/philote/philote.jl")
using .philote

# Re-export the main types we'll use
export DisciplineProperties, StreamOptions, OptionsList, DisciplineOptions
export VariableMetaData, PartialsMetaData
export VariableType, DataType
export Array as PhiloteArray  # renamed to avoid conflict with Base.Array

end  # module PhiloteProto
