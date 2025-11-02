#!/usr/bin/env python3
"""
Python gRPC server that wraps Julia Philote disciplines.

This server uses juliacall to embed Julia and serve Julia disciplines
via gRPC. It adapts Julia's Philote interface to Python's grpcio server.
"""

import sys
import os
import numpy as np
from concurrent import futures
import grpc

# Add the generated proto files to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'generated'))

import data_pb2
import data_pb2_grpc
import disciplines_pb2
import disciplines_pb2_grpc

# Import Empty message from google.protobuf
from google.protobuf import empty_pb2

# Import juliacall to call Julia from Python
from juliacall import Main as jl


def get_chunk_indices(size, chunk_size):
    """
    Get start and end indices for chunking an array.

    Args:
        size: Total size of the array
        chunk_size: Maximum chunk size

    Yields:
        Tuples of (start, end) indices
    """
    for i in range(0, size, chunk_size):
        yield (i, min(i + chunk_size, size))


class JuliaExplicitServer(disciplines_pb2_grpc.DisciplineServiceServicer,
                          disciplines_pb2_grpc.ExplicitServiceServicer):
    """
    gRPC server that wraps a Julia ExplicitDiscipline.

    This server:
    1. Loads a Julia discipline using juliacall
    2. Implements the gRPC Discipline and Explicit service interfaces
    3. Translates gRPC calls to Julia function calls
    4. Handles data marshaling between Python numpy and Julia arrays
    """

    def __init__(self, julia_file, julia_type):
        """
        Initialize the server with a Julia discipline.

        Args:
            julia_file: Path to Julia file containing the discipline
            julia_type: Name of the Julia type (e.g., "ParaboloidDiscipline")
        """
        self.julia_file = julia_file
        self.julia_type = julia_type
        self.discipline = None
        self.metadata = None
        self.stream_opts = data_pb2.StreamOptions(num_double=1000000)

        # Load Julia and initialize discipline
        self._load_julia_discipline()

    def _load_julia_discipline(self):
        """Load the Julia discipline using juliacall."""
        print(f"[DEBUG] Loading Julia discipline from: {self.julia_file}")
        print(f"[DEBUG] Julia type: {self.julia_type}")

        # Load the Philote module
        philote_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        print(f"[DEBUG] Philote directory: {philote_dir}")

        print("[DEBUG] Adding to LOAD_PATH...")
        jl.seval(f'push!(LOAD_PATH, "{philote_dir}")')

        print("[DEBUG] Loading Philote module...")
        jl.seval('using Philote')

        # Load the discipline file
        print(f"[DEBUG] Including discipline file: {self.julia_file}")
        jl.seval(f'include("{self.julia_file}")')

        # Create discipline instance
        print(f"[DEBUG] Creating {self.julia_type} instance...")
        self.discipline = jl.seval(f'{self.julia_type}()')
        print(f"[DEBUG] Discipline created: {self.discipline}")

        # Call setup!
        print("[DEBUG] Calling setup!...")
        setup_fn = jl.seval('Philote.setup!')
        print(f"[DEBUG] Got setup function: {setup_fn}")
        setup_fn(self.discipline)
        print("[DEBUG] setup! completed")

        # Get metadata
        print("[DEBUG] Getting metadata...")
        get_meta_fn = jl.seval('Philote.get_metadata')
        self.metadata = get_meta_fn(self.discipline)
        print(f"[DEBUG] Got metadata: {self.metadata}")

        print("✓ Julia discipline loaded successfully")
        print(f"  Inputs: {list(self.metadata.inputs.keys())}")
        print(f"  Outputs: {list(self.metadata.outputs.keys())}")

    def GetInfo(self, request, context):
        """Return discipline properties."""
        print("[DEBUG] GetInfo called")
        result = data_pb2.DisciplineProperties(
            continuous=True,
            differentiable=len(self.metadata.partials) > 0,
            provides_gradients=len(self.metadata.partials) > 0,
            name=self.metadata.name,
            version=self.metadata.version
        )
        print(f"[DEBUG] GetInfo returning: {result}")
        return result

    def SetStreamOptions(self, request, context):
        """Set streaming chunk size."""
        print("[DEBUG] SetStreamOptions called")
        self.stream_opts = request
        print(f"[DEBUG] SetStreamOptions set to: {self.stream_opts}")
        return empty_pb2.Empty()

    def GetAvailableOptions(self, request, context):
        """Return available options."""
        options_list = data_pb2.OptionsList()
        for name, type_str in self.metadata.options.items():
            option = options_list.options.add()
            option.name = name
            option.type = type_str
        return options_list

    def SetOptions(self, request, context):
        """Set discipline options."""
        # Convert protobuf options to Julia dict
        options_dict = {}
        for opt in request.options:
            if opt.type == "float":
                options_dict[opt.name] = float(opt.value)
            elif opt.type == "int":
                options_dict[opt.name] = int(opt.value)
            elif opt.type == "bool":
                options_dict[opt.name] = opt.value.lower() == "true"
            else:
                options_dict[opt.name] = opt.value

        # Call Julia set_options!
        jl_dict = jl.Dict(options_dict)
        jl.seval('Philote.set_options!')(self.discipline, jl_dict)

        return empty_pb2.Empty()

    def Setup(self, request, context):
        """Setup is already done in __init__, just return empty."""
        print("[DEBUG] Setup called")
        return empty_pb2.Empty()

    def GetVariableDefinitions(self, request, context):
        """Stream variable metadata to client."""
        print("[DEBUG] GetVariableDefinitions called")
        # Send inputs
        for name, (shape, units) in self.metadata.inputs.items():
            print(f"[DEBUG] Sending input: {name}, shape={shape}, units={units}")
            yield data_pb2.VariableMetaData(
                type=data_pb2.kInput,
                name=name,
                shape=shape,
                units=units
            )

        # Send outputs
        for name, (shape, units) in self.metadata.outputs.items():
            print(f"[DEBUG] Sending output: {name}, shape={shape}, units={units}")
            yield data_pb2.VariableMetaData(
                type=data_pb2.kOutput,
                name=name,
                shape=shape,
                units=units
            )
        print("[DEBUG] GetVariableDefinitions complete")

    def GetPartialDefinitions(self, request, context):
        """Stream partial derivative metadata to client."""
        print("[DEBUG] GetPartialDefinitions called")
        for output, input_var in self.metadata.partials:
            # Get shapes
            out_shape = self.metadata.outputs[output][0]
            in_shape = self.metadata.inputs[input_var][0]

            # Jacobian shape
            jac_shape = list(out_shape) + list(in_shape)

            print(f"[DEBUG] Sending partial: {output} wrt {input_var}, shape={jac_shape}")
            yield data_pb2.PartialsMetaData(
                name=output,
                subname=input_var,
                shape=jac_shape
            )
        print("[DEBUG] GetPartialDefinitions complete")

    def ComputeFunction(self, request_iterator, context):
        """Compute outputs from inputs."""
        print("[DEBUG] ComputeFunction called")
        # Collect inputs from stream
        inputs = {}
        for msg in request_iterator:
            print(f"[DEBUG] Received input chunk: {msg.name}, start={msg.start}, end={msg.end}, data={msg.data}")
            if msg.name not in inputs:
                # Get shape from metadata
                shape = self.metadata.inputs[msg.name][0]
                size = int(np.prod(shape))
                inputs[msg.name] = np.zeros(size)
                print(f"[DEBUG] Created input array for {msg.name}, shape={shape}, size={size}")

            # Fill in chunk
            inputs[msg.name][msg.start:msg.end+1] = msg.data
            print(f"[DEBUG] Filled chunk for {msg.name}")

        # Reshape inputs to proper shape
        print(f"[DEBUG] Reshaping inputs...")
        for name in inputs:
            shape = self.metadata.inputs[name][0]
            inputs[name] = inputs[name].reshape(shape)
            print(f"[DEBUG] Reshaped {name} to {shape}: {inputs[name]}")

        # Convert to Julia dict (juliacall handles numpy → Julia conversion)
        print(f"[DEBUG] Converting to Julia dict...")
        jl_inputs = jl.Dict(inputs)
        print(f"[DEBUG] Julia inputs: {jl_inputs}")

        # Call Julia compute
        print(f"[DEBUG] Calling Julia compute...")
        jl_outputs = jl.seval('Philote.compute')(self.discipline, jl_inputs)
        print(f"[DEBUG] Julia compute returned: {jl_outputs}")

        # Stream outputs back to client
        print(f"[DEBUG] Streaming outputs...")
        for name, value in jl_outputs.items():
            # Convert Julia array to numpy
            np_value = np.array(value)
            print(f"[DEBUG] Output {name}: {np_value}")

            # Send in chunks
            for start, end in get_chunk_indices(np_value.size, self.stream_opts.num_double):
                print(f"[DEBUG] Sending chunk {start}:{end} of {name}")
                yield data_pb2.Array(
                    name=name,
                    type=data_pb2.kOutput,
                    start=start,
                    end=end - 1,
                    data=np_value.ravel()[start:end]
                )
        print("[DEBUG] ComputeFunction complete")

    def ComputeGradient(self, request_iterator, context):
        """Compute partial derivatives."""
        # Collect inputs from stream
        inputs = {}
        for msg in request_iterator:
            if msg.name not in inputs:
                shape = self.metadata.inputs[msg.name][0]
                size = int(np.prod(shape))
                inputs[msg.name] = np.zeros(size)
            inputs[msg.name][msg.start:msg.end+1] = msg.data

        # Reshape inputs
        for name in inputs:
            shape = self.metadata.inputs[name][0]
            inputs[name] = inputs[name].reshape(shape)

        # Convert to Julia dict
        jl_inputs = jl.Dict(inputs)

        # Call Julia compute_partials
        jl_partials = jl.seval('Philote.compute_partials')(self.discipline, jl_inputs)

        # Stream partials back to client
        for output_name, input_dict in jl_partials.items():
            for input_name, value in input_dict.items():
                # Convert to numpy
                np_value = np.array(value)

                # Send in chunks
                for start, end in get_chunk_indices(np_value.size, self.stream_opts.num_double):
                    yield data_pb2.Array(
                        name=output_name,
                        subname=input_name,
                        type=data_pb2.kPartial,
                        start=start,
                        end=end - 1,
                        data=np_value.ravel()[start:end]
                    )


def serve(julia_file, julia_type, address="localhost:50051"):
    """
    Start the gRPC server serving a Julia discipline.

    Args:
        julia_file: Path to Julia file
        julia_type: Julia discipline type name
        address: Server address (default: localhost:50051)
    """
    print("="*60)
    print("  Philote Julia Server (Python + juliacall)")
    print("="*60)
    print()

    # Create server
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    # Create and attach discipline server
    discipline_server = JuliaExplicitServer(julia_file, julia_type)
    disciplines_pb2_grpc.add_DisciplineServiceServicer_to_server(discipline_server, server)
    disciplines_pb2_grpc.add_ExplicitServiceServicer_to_server(discipline_server, server)

    # Start server
    server.add_insecure_port(address)
    server.start()

    print()
    print(f"✓ Server listening on: {address}")
    print()
    print("The server is now ready to accept connections.")
    print("Press Ctrl+C to stop the server.")
    print()
    print("="*60)

    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.stop(0)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Serve a Julia Philote discipline via gRPC")
    parser.add_argument("julia_file", help="Path to Julia file containing discipline")
    parser.add_argument("julia_type", help="Name of Julia discipline type")
    parser.add_argument("--address", default="localhost:50051", help="Server address")

    args = parser.parse_args()

    serve(args.julia_file, args.julia_type, args.address)
