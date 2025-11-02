#!/usr/bin/env python3
"""Simple test of compute functionality"""
import grpc
import numpy as np
import sys
import os

# Add generated proto files to path
sys.path.insert(0, 'src/generated')

import data_pb2
import disciplines_pb2_grpc

channel = grpc.insecure_channel("localhost:50051")
stub = disciplines_pb2_grpc.ExplicitServiceStub(channel)

print("Testing compute...")

# Create input data
def create_array_message(name, data):
    """Helper to create Array message"""
    flat_data = data.ravel()
    return data_pb2.Array(
        name=name,
        type=data_pb2.kInput,
        start=0,
        end=len(flat_data) - 1,
        data=flat_data
    )

# Send inputs
inputs_list = [
    create_array_message("x", np.array([1.0])),
    create_array_message("y", np.array([2.0]))
]

print(f"Sending inputs: {[(msg.name, msg.data) for msg in inputs_list]}")

# Generator function to send messages
def send_inputs():
    for msg in inputs_list:
        print(f"  Yielding: {msg.name}")
        yield msg

# Call compute
try:
    print("Calling ComputeFunction...")
    response_iterator = stub.ComputeFunction(send_inputs())
    print("Got response iterator, consuming...")
    for output in response_iterator:
        print(f"  {output.name}: {output.data}")
    print("✓ Compute successful!")
except Exception as e:
    print(f"✗ Error: {e}")
    import traceback
    traceback.print_exc()
