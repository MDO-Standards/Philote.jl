"""
Python discipline wrapper that calls Julia code via juliacall.

This allows using pure Julia disciplines with the proven Python gRPC server.
"""
import os
import sys
import numpy as np

# Find and add Philote-Python to path
def _find_philote_python():
    """Try to find Philote-Python in standard locations."""
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # Try ../Philote-Python relative to this file
    candidate = os.path.join(os.path.dirname(os.path.dirname(current_dir)), 'Philote-Python')
    if os.path.exists(candidate):
        return candidate

    # Try ~/tools/Philote/Philote-Python
    home_path = os.path.expanduser('~/tools/Philote/Philote-Python')
    if os.path.exists(home_path):
        return home_path

    return None

philote_python_path = _find_philote_python()
if philote_python_path and philote_python_path not in sys.path:
    sys.path.insert(0, philote_python_path)

try:
    from philote_mdo.general.explicit_discipline import ExplicitDiscipline
except ImportError as e:
    raise ImportError(
        f"Cannot import Philote-Python. Searched in: {philote_python_path}\n"
        f"Please ensure Philote-Python is installed or set PYTHONPATH.\n"
        f"Original error: {e}"
    )

# Import juliacall
try:
    from juliacall import Main as jl
except ImportError as e:
    raise ImportError(
        f"Cannot import juliacall. Please install it with: pip install juliacall\n"
        f"Original error: {e}"
    )


class JuliaWrapperDiscipline(ExplicitDiscipline):
    """
    Python discipline that wraps a Julia Philote discipline.

    This uses juliacall to load and execute Julia code, while presenting
    a pure Python interface that works with the Philote-Python server.
    """

    def __init__(self, julia_file, julia_type, options=None):
        """
        Initialize with a Julia discipline.

        Args:
            julia_file: Path to Julia file containing the discipline
            julia_type: Name of the Julia type (e.g., "ParaboloidDiscipline")
            options: Optional dict of discipline options to set after initialization
        """
        super().__init__()

        self.julia_file = os.path.abspath(julia_file)
        self.julia_type = julia_type
        self.julia_discipline = None
        self.julia_metadata = None
        self._options = options or {}

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
        if not os.path.exists(self.julia_file):
            raise FileNotFoundError(f"Julia file not found: {self.julia_file}")

        jl.seval(f'include("{self.julia_file}")')

        # Create discipline instance
        try:
            self.julia_discipline = jl.seval(f'{self.julia_type}()')
        except Exception as e:
            raise ValueError(
                f"Failed to instantiate Julia type '{self.julia_type}'. "
                f"Make sure it exists in {self.julia_file}\n"
                f"Original error: {e}"
            )

        # Set options if provided
        if self._options:
            jl.seval('Philote.set_options!')(self.julia_discipline, jl.Dict(self._options))

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
        try:
            # Convert Python dict to Julia dict
            jl_inputs = jl.Dict(inputs)

            # Call Julia compute
            jl_outputs = jl.seval('Philote.compute')(self.julia_discipline, jl_inputs)

            # Convert Julia outputs back to Python and populate outputs dict
            for name in jl_outputs.keys():
                outputs[name] = np.array(jl_outputs[name])
        except Exception as e:
            raise RuntimeError(f"Error in Julia compute: {e}")

    def compute_partials(self, inputs, partials):
        """
        Compute partial derivatives by calling Julia discipline.

        Args:
            inputs: Dict of input arrays
            partials: Dict to populate with partial derivative arrays
        """
        try:
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
        except Exception as e:
            raise RuntimeError(f"Error in Julia compute_partials: {e}")
