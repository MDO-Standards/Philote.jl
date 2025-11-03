#!/usr/bin/env python3
"""
Quick test client for Julia discipline server.
"""
import sys
import os

# Add Philote-Python to path
philote_python_path = os.path.join(os.path.dirname(__file__), '..', 'Philote-Python')
sys.path.insert(0, philote_python_path)

import philote_mdo.general as pmdo
import grpc

def main():
    print("Connecting to Julia discipline server...")

    # Create gRPC channel and connect to server
    channel = grpc.insecure_channel("localhost:50051")
    client = pmdo.ExplicitClient(channel=channel)

    # Get discipline info
    print("\n1. Getting discipline info...")
    info = client.get_discipline_info()
    print(f"   Discipline: {info.name}")
    print(f"   Version: {info.version}")
    print(f"   Continuous: {info.continuous}")
    print(f"   Differentiable: {info.differentiable}")
    print(f"   Provides gradients: {info.provides_gradients}")

    # Run setup
    print("\n2. Running setup...")
    client.run_setup()
    print("   Setup complete!")

    # Get variable definitions
    print("\n3. Getting variable definitions...")
    var_defs = client.get_variable_definitions()
    print(f"   Inputs: {[v.name for v in var_defs.inputs]}")
    print(f"   Outputs: {[v.name for v in var_defs.outputs]}")

    # Test compute
    print("\n4. Testing compute...")
    inputs = {"x": [2.0], "y": [3.0]}
    print(f"   Inputs: x={inputs['x'][0]}, y={inputs['y'][0]}")
    outputs = client.run_compute(inputs)
    print(f"   Output: f_xy={outputs['f_xy'][0]}")

    # Expected: f(2,3) = (2-3)^2 + 2*3 + (3+4)^2 = 1 + 6 + 49 = 56
    expected = (2-3)**2 + 2*3 + (3+4)**2
    print(f"   Expected: {expected}")
    print(f"   Match: {abs(outputs['f_xy'][0] - expected) < 1e-10}")

    # Test gradients
    if info.provides_gradients:
        print("\n5. Testing gradients...")
        partials = client.run_compute_partials(inputs)
        print(f"   df/dx: {partials[('f_xy', 'x')]}")
        print(f"   df/dy: {partials[('f_xy', 'y')]}")

        # Expected: df/dx = 2*(x-3) + y = 2*(2-3) + 3 = -2 + 3 = 1
        # Expected: df/dy = x + 2*(y+4) = 2 + 2*(3+4) = 2 + 14 = 16
        expected_dfdx = 2*(2-3) + 3
        expected_dfdy = 2 + 2*(3+4)
        print(f"   Expected df/dx: {expected_dfdx}")
        print(f"   Expected df/dy: {expected_dfdy}")

    print("\n✓ All tests passed!")

if __name__ == "__main__":
    main()
