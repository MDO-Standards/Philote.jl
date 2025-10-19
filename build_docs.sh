#!/bin/bash
# Build Philote-Julia Documentation

set -e  # Exit on error

echo "======================================================"
echo "  Building Philote-Julia Documentation"
echo "======================================================"
echo ""

# Check if doxygen is installed
if ! command -v doxygen &> /dev/null; then
    echo "Error: Doxygen is not installed"
    echo ""
    echo "Install with:"
    echo "  macOS:   brew install doxygen graphviz"
    echo "  Ubuntu:  sudo apt-get install doxygen graphviz"
    exit 1
fi

# Check doxygen version
DOXYGEN_VERSION=$(doxygen --version)
echo "Using Doxygen version: $DOXYGEN_VERSION"
echo ""

# Check if graphviz is installed (optional but recommended)
if ! command -v dot &> /dev/null; then
    echo "Warning: Graphviz (dot) is not installed"
    echo "Diagrams will not be generated"
    echo ""
fi

# Clean previous build
if [ -d "docs/html" ]; then
    echo "Cleaning previous build..."
    rm -rf docs/html
fi

# Build documentation
echo "Building documentation..."
doxygen Doxyfile

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "======================================================"
    echo "  Documentation built successfully!"
    echo "======================================================"
    echo ""
    echo "Output location: docs/html/"
    echo ""
    echo "To view locally:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  open docs/html/index.html"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "  xdg-open docs/html/index.html"
    else
        echo "  Open docs/html/index.html in your browser"
    fi
    echo ""
    echo "To deploy to GitHub Pages:"
    echo "  git add docs/html"
    echo "  git commit -m 'Update documentation'"
    echo "  git push"
    echo ""
    echo "(GitHub Actions will automatically deploy)"
    echo ""
else
    echo ""
    echo "Error: Documentation build failed"
    exit 1
fi
