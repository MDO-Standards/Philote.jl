# Testing Documentation

This document describes the comprehensive test suite for Philote-Julia.

## Overview

The test suite is divided into two parts:
1. **Julia tests** - Test the Julia interface and example disciplines
2. **C++ tests** - Test the C++ wrapper components

**Total Test Count:** 96 Julia tests + ~50 C++ tests = ~146 tests

## Julia Test Suite

Location: `test/`

### Structure

```
test/
├── runtests.jl              # Main test runner
├── test_metadata.jl         # Metadata management tests
├── test_explicit_discipline.jl  # Discipline interface tests
└── test_paraboloid.jl       # Paraboloid example tests
```

### Running Julia Tests

```bash
julia --project=. test/runtests.jl
```

Expected output:
```
Test Summary:    | Pass  Total  Time
Philote.jl Tests |   96     96  1.1s
```

### Test Coverage

#### test_metadata.jl (36 tests)
- Metadata creation and initialization
- Metadata persistence across get_metadata() calls
- Multiple discipline instances with separate metadata
- Adding inputs with shapes and units
- Adding outputs with shapes and units
- Adding options with types
- Declaring partials
- Complete setup workflow

#### test_explicit_discipline.jl (28 tests)
- Type hierarchy validation
- Required method enforcement (setup!, compute)
- Basic scalar computation
- Gradient computation
- Multiple inputs/outputs
- Array inputs/outputs (vectors, matrices)
- Default behavior for missing compute_partials

#### test_paraboloid.jl (32 tests)
- Type verification and setup
- Metadata completeness
- Forward computation at multiple test points:
  - Origin (0, 0)
  - Standard point (1, 2)
  - Special point (3, -4)
  - Arbitrary point (-2.5, 1.5)
  - Multiple sequential evaluations
- Gradient computation at multiple points
- Finite difference validation of analytical gradients
- Options handling:
  - Scale factor effects on outputs and gradients
  - Offset effects on outputs (not gradients)
  - Combined scale and offset

## C++ Test Suite

Location: `cpp/test/`

### Structure

```
cpp/test/
├── CMakeLists.txt              # Test build configuration
├── test_main.cpp               # Test entry point
├── test_julia_runtime.cpp      # JuliaRuntime tests
├── test_julia_marshal.cpp      # JuliaMarshal tests
└── test_julia_explicit.cpp     # JuliaExplicitDiscipline tests
```

### Building and Running C++ Tests

```bash
cd cpp
mkdir build && cd build
cmake .. -DPHILOTE_CPP_DIR=../../Philote-Cpp -DBUILD_TESTS=ON
cmake --build .
ctest --output-on-failure
```

Or run directly:
```bash
./philote_julia_tests
```

### Test Coverage

#### test_julia_runtime.cpp (~18 tests)
- Singleton pattern verification
- Initialization state checking
- Expression evaluation (arithmetic, strings, arrays)
- Invalid expression error handling
- Function retrieval from Base and Main modules
- Module loading (Philote module)
- Exception handling and propagation
- GC root management (single and multiple roots)
- Exception state after errors

#### test_julia_marshal.cpp (~20 tests)
**Variable ↔ Julia Array:**
- Scalar conversion (both directions)
- Vector conversion
- Matrix conversion
- 3D tensor conversion
- Round-trip tests (C++ → Julia → C++)

**Variables ↔ Julia Dict:**
- Dictionary creation from C++ map
- Dictionary parsing to C++ map
- Round-trip with multiple variables of different shapes

**Partials ↔ Nested Julia Dict:**
- Nested dictionary conversion
- Round-trip tests for Jacobian structures

**Helper functions:**
- Array shape extraction
- Type checking (IsDict, IsArray)
- Dictionary key retrieval
- Dictionary get/set operations

#### test_julia_explicit.cpp (~12 tests)
- Construction and initialization
- Error handling (invalid files, invalid types)
- Setup and SetupPartials
- Computation at multiple points:
  - Basic computation
  - At origin
  - With negative values
  - Multiple sequential evaluations
- Gradient computation:
  - Basic gradients
  - At origin
  - Multiple evaluations
- Finite difference validation
- Multiple discipline instances
- Sequential computation stability

## Test Quality Metrics

### Coverage
- ✅ All public API methods tested
- ✅ Error paths tested (exceptions, invalid inputs)
- ✅ Round-trip data conversion tested
- ✅ Gradient accuracy validated with finite differences
- ✅ Multiple instances and sequential calls tested

### Accuracy
- Analytical gradients verified against finite differences (tolerance: 1e-5)
- All paraboloid function values computed correctly
- Data marshaling preserves values to machine precision

### Robustness
- Exception handling tested
- Invalid input rejection verified
- GC safety tested (forced garbage collection)
- Multiple discipline instances coexist

## Test Dependencies

### Julia Tests
- Julia 1.6+
- Test standard library (built-in)
- Philote module (local)

### C++ Tests
- Google Test
- Julia runtime (libjulia)
- Philote-Cpp library
- CMake 3.23+

## CI/CD Recommendations

For continuous integration:

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test-julia:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: julia-actions/setup-julia@v1
        with:
          version: '1.9'
      - run: julia --project=. test/runtests.jl

  test-cpp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y cmake g++ libgtest-dev
          # Install Julia, gRPC, Philote-Cpp...
      - name: Build and test
        run: |
          cd cpp && mkdir build && cd build
          cmake .. -DBUILD_TESTS=ON
          cmake --build .
          ctest --output-on-failure
```

## Adding New Tests

### Julia Tests

Add to appropriate test file or create new:

```julia
@testset "My New Feature" begin
    @test my_function(1, 2) == 3
    @test_throws ErrorException bad_function()
end
```

Include in `test/runtests.jl`:
```julia
include("test_my_feature.jl")
```

### C++ Tests

Add to appropriate test file:

```cpp
TEST_F(MyComponentTest, NewFeature) {
    // Arrange
    auto obj = CreateTestObject();

    // Act
    auto result = obj.DoSomething();

    // Assert
    EXPECT_EQ(result, expected_value);
}
```

## Troubleshooting

### Julia Tests Fail

1. Check Julia project is activated: `julia --project=.`
2. Verify Philote module loads: `using Philote`
3. Check LOAD_PATH includes parent directory

### C++ Tests Fail to Build

1. Verify Google Test is installed
2. Check PHILOTE_CPP_DIR points to built Philote-Cpp
3. Ensure Julia runtime is found by CMake

### C++ Tests Fail at Runtime

1. Check Julia runtime initializes: look for "Julia runtime initialized" in logs
2. Verify paraboloid.jl is accessible from test directory
3. Check LD_LIBRARY_PATH includes Julia library path

### Segmentation Faults

1. Usually indicates GC root issue - check AddGCRoot calls
2. Verify Julia types before casting
3. Use jl_typeof() for debugging

## Test Maintenance

- Run tests before every commit
- Update tests when adding features
- Keep finite difference tolerances reasonable (1e-5 to 1e-7)
- Document expected values in test comments
- Use descriptive test names

## Future Test Additions

Recommended additions:
- [ ] Implicit discipline tests
- [ ] Options marshaling tests
- [ ] Performance benchmarks
- [ ] Multi-threaded safety tests
- [ ] Memory leak detection
- [ ] Stress tests (large arrays, many evaluations)
- [ ] Integration tests with actual Philote-Cpp client
