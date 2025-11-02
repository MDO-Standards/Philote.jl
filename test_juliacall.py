#!/usr/bin/env python3
"""Test juliacall basic functionality"""

print("Importing juliacall...")
from juliacall import Main as jl
print("✓ juliacall imported")

print("\nTesting Julia evaluation...")
result = jl.seval("2 + 2")
print(f"✓ Julia eval works: 2 + 2 = {result}")

print("\nLoading Philote module...")
import os
philote_dir = os.path.dirname(os.path.abspath(__file__))
jl.seval(f'push!(LOAD_PATH, "{philote_dir}")')
jl.seval('using Philote')
print("✓ Philote module loaded")

print("\nLoading paraboloid example...")
jl.seval(f'include("{philote_dir}/examples/paraboloid.jl")')
print("✓ Paraboloid example loaded")

print("\nCreating discipline instance...")
disc = jl.seval('ParaboloidDiscipline()')
print(f"✓ Discipline created: {disc}")

print("\nCalling setup!...")
jl.seval('Philote.setup!')(disc)
print("✓ setup! called")

print("\nGetting metadata...")
meta = jl.seval('Philote.get_metadata')(disc)
print(f"✓ Metadata: inputs={list(meta.inputs.keys())}, outputs={list(meta.outputs.keys())}")

print("\n" + "="*60)
print("All tests passed! juliacall is working correctly.")
print("="*60)
