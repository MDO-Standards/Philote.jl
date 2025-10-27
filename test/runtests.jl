"""
    Philote.jl Test Suite

Main test runner for Philote-Julia package.
"""

using Test

@testset "Philote.jl Tests" begin
    include("test_metadata.jl")
    include("test_explicit_discipline.jl")
    include("test_paraboloid.jl")
    include("test_implicit_discipline.jl")
    include("test_quadratic_implicit.jl")
end
