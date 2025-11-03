"""
Philote-Julia: Python wrapper for Julia disciplines in the Philote MDO framework.

This package provides a seamless way to use Julia-based disciplines with the
Philote gRPC server infrastructure.
"""

__version__ = "0.1.0"

from .wrapper_discipline import JuliaWrapperDiscipline, JuliaImplicitWrapperDiscipline
from .config import DisciplineConfig, ServerConfig, PhiloteConfig

__all__ = [
    "JuliaWrapperDiscipline",
    "JuliaImplicitWrapperDiscipline",
    "DisciplineConfig",
    "ServerConfig",
    "PhiloteConfig",
]
