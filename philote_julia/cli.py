"""
Command-line interface for Philote-Julia server.
"""
import sys
import argparse
from pathlib import Path

from .config import PhiloteConfig
from .servers import serve_explicit_discipline


def main():
    """Main entry point for philote-julia-serve command."""
    parser = argparse.ArgumentParser(
        description="Serve Julia Philote disciplines via gRPC",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Serve from YAML config
  philote-julia-serve examples/configs/paraboloid.yaml

  # Also works with absolute paths
  philote-julia-serve /path/to/config.yaml

For more information, see the documentation in examples/configs/README.md
"""
    )

    parser.add_argument(
        "config",
        type=str,
        help="Path to YAML configuration file"
    )

    parser.add_argument(
        "--version",
        action="version",
        version="philote-julia 0.1.0"
    )

    args = parser.parse_args()

    # Load configuration
    try:
        config = PhiloteConfig.from_yaml(args.config)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Configuration error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error loading config: {e}", file=sys.stderr)
        sys.exit(1)

    # Route to appropriate server based on discipline kind
    if config.discipline.kind == "explicit":
        serve_explicit_discipline(config)
    elif config.discipline.kind == "implicit":
        print("Error: Implicit disciplines not yet implemented", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"Error: Unknown discipline kind '{config.discipline.kind}'", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
