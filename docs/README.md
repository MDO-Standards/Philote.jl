# Philote-Julia Documentation

This directory contains the source files for Philote-Julia documentation, which is generated using [Doxygen](https://www.doxygen.nl/).

## Building Locally

### Prerequisites

- Doxygen (>= 1.9.0)
- Graphviz (for diagrams)

#### Install on macOS

```bash
brew install doxygen graphviz
```

#### Install on Ubuntu/Debian

```bash
sudo apt-get install doxygen graphviz
```

#### Install on Windows

Download from [doxygen.nl](https://www.doxygen.nl/download.html)

### Build Documentation

From the repository root:

```bash
doxygen Doxyfile
```

The HTML documentation will be generated in `docs/html/`.

### View Documentation

Open in your browser:

```bash
open docs/html/index.html  # macOS
xdg-open docs/html/index.html  # Linux
start docs/html/index.html  # Windows
```

## Documentation Structure

### Source Files

- `mainpage.md` - Main landing page
- `user_guide.md` - User guide for creating disciplines
- `developer_guide.md` - Developer guide for internals
- `tutorials.md` - Step-by-step tutorials
- `custom.css` - Custom styling

### Generated Content

Doxygen also processes:
- C++ headers (`cpp/include/*.h`) - API documentation
- C++ source (`cpp/src/*.cpp`) - Implementation details
- Julia source (`src/Philote.jl`) - Julia API
- Examples (`examples/*.jl`, `cpp/examples/*.cpp`)
- README files throughout the project

## Online Documentation

The documentation is automatically built and deployed to GitHub Pages on every push to `main`.

**URL**: https://yourusername.github.io/Philote-Julia/

### GitHub Pages Setup

1. Enable GitHub Pages in repository settings
2. Set source to `gh-pages` branch
3. GitHub Actions will automatically build and deploy

## Customization

### Modifying Content

Edit the markdown files in `docs/`:
- `mainpage.md` - Edit landing page content
- `user_guide.md` - Edit user documentation
- `developer_guide.md` - Edit developer documentation
- `tutorials.md` - Add or modify tutorials

### Modifying Appearance

Edit `docs/custom.css` to change:
- Colors and theme
- Font sizes and families
- Layout and spacing
- Code block styling

### Configuration

Edit `Doxyfile` (in repository root) to change:
- Input files
- Output format
- Diagram generation
- Search functionality

Common settings:

```doxyfile
# Change project name
PROJECT_NAME = "Your Project Name"

# Change version
PROJECT_NUMBER = 1.0.0

# Add/remove input files
INPUT = src/ include/ docs/

# Enable/disable features
GENERATE_HTML = YES
GENERATE_LATEX = NO
HAVE_DOT = YES  # Requires Graphviz
```

## Documentation Guidelines

### Writing Code Documentation

**C++ (Doxygen style):**

```cpp
/**
 * @brief Brief description
 *
 * Detailed description goes here.
 *
 * @param param1 Description of param1
 * @param param2 Description of param2
 * @return Description of return value
 *
 * @throws ExceptionType When this exception is thrown
 *
 * @code
 * Example usage();
 * @endcode
 */
ReturnType functionName(Type1 param1, Type2 param2);
```

**Julia (Docstrings):**

```julia
"""
    function_name(arg1, arg2)

Brief description.

# Arguments
- `arg1`: Description of arg1
- `arg2`: Description of arg2

# Returns
- Description of return value

# Examples
```julia
result = function_name(1, 2)
```
"""
function function_name(arg1, arg2)
    # ...
end
```

### Writing Tutorial Content

1. **Clear Objectives**: State what the reader will learn
2. **Step-by-Step**: Break down into numbered steps
3. **Code Examples**: Include complete, runnable code
4. **Expected Output**: Show what success looks like
5. **Troubleshooting**: Address common issues

### Writing API Reference

- Brief description first
- Parameters clearly documented
- Return values explained
- Exceptions/errors noted
- Usage examples provided
- See-also references

## Troubleshooting

### Doxygen Not Found

```bash
# Check if installed
doxygen --version

# If not, install (see Prerequisites above)
```

### Graphviz Diagrams Not Rendering

```bash
# Check if Graphviz is installed
dot -V

# Ensure HAVE_DOT = YES in Doxyfile
```

### CSS Not Applied

- Check `HTML_EXTRA_STYLESHEET = docs/custom.css` in Doxyfile
- Ensure `custom.css` exists
- Clear browser cache

### Missing Pages

- Verify files are listed in `INPUT` directive
- Check file extensions in `FILE_PATTERNS`
- Ensure `USE_MDFILE_AS_MAINPAGE` points to correct file

## Contributing

When contributing documentation:

1. **Test Locally**: Build and review before committing
2. **Follow Style**: Match existing documentation style
3. **Add Examples**: Include code examples where helpful
4. **Update TOC**: Keep table of contents current
5. **Check Links**: Ensure all links work

## Resources

- [Doxygen Manual](https://www.doxygen.nl/manual/)
- [Markdown Syntax](https://www.markdownguide.org/)
- [GitHub Pages Docs](https://docs.github.com/en/pages)

## License

Documentation is part of Philote-Julia and follows the same MIT license.
