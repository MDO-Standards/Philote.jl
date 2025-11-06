# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-06

### Added
- Native Julia gRPC clients for connecting to Philote discipline servers
- `ExplicitClient` for explicit disciplines (outputs = f(inputs))
- `ImplicitClient` for implicit disciplines (R(inputs, outputs) = 0)
- Protocol buffer support via ProtoBuf.jl
- High-performance streaming via gRPCClient2.jl
- Client examples: `paraboloid_client.jl` and `quadratic_client.jl`
- Full gRPC service support:
  - DisciplineService (metadata, setup, options)
  - ExplicitService (function and gradient computation)
  - ImplicitService (residuals, solving, gradients)
- Comprehensive documentation for client usage

### Changed
- Updated CI workflow to test on multiple platforms (Ubuntu, macOS, Windows)
- Expanded test coverage to 68 tests
- Updated README with client documentation and usage examples

### Fixed
- Module scoping issues in client implementation
- Protocol buffer type exports
- Test compatibility with package environment

### Initial Features (Pre-release)
- Initial Julia interface for Philote disciplines
- Abstract types: `AbstractDiscipline`, `ExplicitDiscipline`, `ImplicitDiscipline`
- Core API for discipline implementation
- Metadata management system
- Input/output/residual/option declarations
- Partial derivative declarations
- Example disciplines: Paraboloid (explicit) and Quadratic (implicit)
- Basic test suite
- CI/CD workflows for linting, testing, and coverage
- Integration with Philote-Python via juliacall

[Unreleased]: https://github.com/MDO-Standards/Philote-Julia/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/MDO-Standards/Philote-Julia/compare/v0.0.0...v0.1.0
