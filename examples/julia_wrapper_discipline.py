#!/usr/bin/env python3
"""
Python discipline wrapper that calls Julia code via juliacall.

This allows using pure Julia disciplines with the proven Python gRPC server.
"""
import sys
import os
import numpy as np

# Add Philote-Python to path
philote_python_path = os.path.join(os.path.dirname(__file__), '..', '..', 'Philote-Python')
sys.path.insert(0, philote_python_path)

from philote_mdo.general.explicit_discipline import ExplicitDiscipline

# Import juliacall
from juliacall import Main as jl


class JuliaWrapperDiscipline(ExplicitDiscipline):
    """
    Python discipline that wraps a Julia Philote discipline.

    This uses juliacall to load and execute Julia code, while presenting
    a pure Python interface that works with the Philote-Python server.
    """

    def __init__(self, julia_file, julia_type):
        """
        Initialize with a Julia discipline.

        Args:
            julia_file: Path to Julia file containing the discipline
            julia_type: Name of the Julia type (e.g., "ParaboloidDiscipline")
        """
        super().__init__()

        self.julia_file = julia_file
        self.julia_type = julia_type
        self.julia_discipline = None
        self.julia_metadata = None

        # Load Julia discipline
        self._load_julia_discipline()

    def _load_julia_discipline(self):
        """Load the Julia discipline using juliacall."""
        print(f"Loading Julia discipline from: {self.julia_file}")

        # Load the Philote.jl module
        philote_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        jl.seval(f'push!(LOAD_PATH, "{philote_dir}")')
        jl.seval('using Philote')

        # Load the discipline file
        jl.seval(f'include("{self.julia_file}")')

        # Create discipline instance
        self.julia_discipline = jl.seval(f'{self.julia_type}()')

        # Call setup!
        jl.seval('Philote.setup!')(self.julia_discipline)

        # Get metadata
        self.julia_metadata = jl.seval('Philote.get_metadata')(self.julia_discipline)

        print(f"✓ Julia discipline loaded: {self.julia_metadata.name}")

    def setup(self):
        """
        Setup the discipline - define inputs, outputs, and partials.

        This reads metadata from the Julia discipline and configures
        the Python discipline interface.
        """
        # Add inputs from Julia metadata
        for name, (shape, units) in self.julia_metadata.inputs.items():
            self.add_input(name, shape=tuple(shape), units=units)

        # Add outputs from Julia metadata
        for name, (shape, units) in self.julia_metadata.outputs.items():
            self.add_output(name, shape=tuple(shape), units=units)

        # Declare partials from Julia metadata
        for output_name, input_name in self.julia_metadata.partials:
            self.declare_partials(output_name, input_name)

    def compute(self, inputs, outputs):
        """
        Compute outputs from inputs by calling Julia discipline.

        Args:
            inputs: Dict of input arrays
            outputs: Dict to populate with output arrays
        """
        # Convert Python dict to Julia dict
        jl_inputs = jl.Dict(inputs)

        # Call Julia compute
        jl_outputs = jl.seval('Philote.compute')(self.julia_discipline, jl_inputs)

        # Convert Julia outputs back to Python and populate outputs dict
        for name in jl_outputs.keys():
            outputs[name] = np.array(jl_outputs[name])

    def compute_partials(self, inputs, partials):
        """
        Compute partial derivatives by calling Julia discipline.

        Args:
            inputs: Dict of input arrays
            partials: Dict to populate with partial derivative arrays
        """
        # Convert Python dict to Julia dict
        jl_inputs = jl.Dict(inputs)

        # Call Julia compute_partials
        jl_partials = jl.seval('Philote.compute_partials')(self.julia_discipline, jl_inputs)

        # Convert Julia partials back to Python
        # Julia returns: Dict{output_name => Dict{input_name => jacobian}}
        for output_name in jl_partials.keys():
            for input_name in jl_partials[output_name].keys():
                key = (output_name, input_name)
                partials[key] = np.array(jl_partials[output_name][input_name])
