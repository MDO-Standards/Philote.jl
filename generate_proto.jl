using ProtoBuf

# Generate Julia protobuf files from the proto definitions
proto_dir = joinpath(@__DIR__, "..", "Philote-Python", "proto")
output_dir = joinpath(@__DIR__, "src", "proto")

# Use protojl to generate the files
# The API is: protojl(proto_files, import_paths, output_dir)
# proto_files must be relative to import_paths
ProtoBuf.protojl(
    ["data.proto"],  # relative to proto_dir
    [proto_dir],     # search directory
    output_dir;      # output directory
    add_kwarg_constructors=true
)

ProtoBuf.protojl(
    ["disciplines.proto"],  # relative to proto_dir
    [proto_dir],            # search directory
    output_dir;             # output directory
    add_kwarg_constructors=true
)

println("Protocol buffer files generated successfully!")
