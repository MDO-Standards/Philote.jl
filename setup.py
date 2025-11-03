"""
Setup script for Philote-Julia.
"""
from setuptools import setup, find_packages
import os

# Read version from __init__.py
version = {}
with open("philote_julia/__init__.py") as f:
    for line in f:
        if line.startswith("__version__"):
            exec(line, version)

# Read README for long description
readme_path = os.path.join(os.path.dirname(__file__), "README.md")
if os.path.exists(readme_path):
    with open(readme_path, "r", encoding="utf-8") as f:
        long_description = f.read()
else:
    long_description = "Python wrapper for Julia disciplines in the Philote MDO framework"

setup(
    name="philote-julia",
    version=version.get("__version__", "0.1.0"),
    description="Python wrapper for Julia disciplines in the Philote MDO framework",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Philote Development Team",
    author_email="",
    url="https://github.com/clupp/Philote",
    packages=find_packages(),
    install_requires=[
        "pyyaml>=5.4",
        "juliacall>=0.9.0",
        "numpy>=1.20.0",
        "grpcio>=1.40.0",
    ],
    python_requires=">=3.7",
    entry_points={
        "console_scripts": [
            "philote-julia-serve=philote_julia.cli:main",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    keywords="mdo optimization julia grpc philote",
)
