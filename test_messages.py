#!/usr/bin/env python3
"""Test message creation"""
import numpy as np
import sys
import os

sys.path.insert(0, 'src/generated')
import data_pb2

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

# Create input data
inputs_list = [
    create_array_message("x", np.array([1.0])),
    create_array_message("y", np.array([2.0]))
]

print(f"Number of messages: {len(inputs_list)}")
for i, msg in enumerate(inputs_list):
    print(f"  Message {i}: name={msg.name}, start={msg.start}, end={msg.end}, data={list(msg.data)}")

print("\nTesting iteration:")
for msg in iter(inputs_list):
    print(f"  {msg.name}: {list(msg.data)}")
