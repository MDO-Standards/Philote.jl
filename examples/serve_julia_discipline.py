#!/usr/bin/env python3
"""
Serve a Julia discipline using the Philote-Python server infrastructure.
"""
import sys
import os
from concurrent import futures
import grpc

# Add Philote-Python to path
philote_python_path = os.path.join(os.path.dirname(__file__), '..', '..', 'Philote-Python')
sys.path.insert(0, philote_python_path)

import philote_mdo.general as pmdo
from julia_wrapper_discipline import JuliaWrapperDiscipline


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Serve a Julia Philote discipline via gRPC using Python server"
    )
    parser.add_argument("julia_file", help="Path to Julia file containing discipline")
    parser.add_argument("julia_type", help="Name of Julia discipline type")
    parser.add_argument("--address", default="[::]:50051", help="Server address (default: [::]:50051)")

    args = parser.parse_args()

    # Create the wrapper discipline
    print("="*60)
    print("  Philote Julia Server (Python wrapper + juliacall)")
    print("="*60)
    print()

    discipline_wrapper = JuliaWrapperDiscipline(args.julia_file, args.julia_type)

    # Create gRPC server
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    # Create discipline server and attach to gRPC server
    discipline_server = pmdo.ExplicitServer(discipline=discipline_wrapper)
    discipline_server.attach_to_server(server)

    # Start server
    server.add_insecure_port(args.address)
    server.start()
    print(f"Server started. Listening on {args.address}")
    print("Press Ctrl+C to stop.")
    server.wait_for_termination()
