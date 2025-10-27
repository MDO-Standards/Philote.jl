"""
    Test Explicit Discipline Interface

Tests for the ExplicitDiscipline abstract type and its required methods.
"""

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
using Test

@testset "Explicit Discipline Interface" begin
    # Define a simple test discipline
    mutable struct SimpleDiscipline <: Philote.ExplicitDiscipline
        multiplier::Float64
        SimpleDiscipline() = new(2.0)
    end

    function Philote.setup!(d::SimpleDiscipline)
        Philote.add_input!(d, "x", [1], "m")
        Philote.add_output!(d, "y", [1], "m")
        Philote.declare_partials!(d, "y", "x")
    end

    function Philote.compute(d::SimpleDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
        x = inputs["x"][1]
        y = d.multiplier * x
        return Dict("y" => [y])
    end

    function Philote.compute_partials(d::SimpleDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
        return Dict("y" => Dict("x" => [d.multiplier]))
    end

    @testset "Type Hierarchy" begin
        d = SimpleDiscipline()
        @test d isa Philote.ExplicitDiscipline
        @test d isa Philote.AbstractDiscipline
    end

    @testset "Setup Required" begin
        # Discipline without setup! should error
        mutable struct NoSetupDiscipline <: Philote.ExplicitDiscipline end

        d = NoSetupDiscipline()
        @test_throws ErrorException Philote.setup!(d)
    end

    @testset "Compute Required" begin
        # Discipline without compute should error
        mutable struct NoComputeDiscipline <: Philote.ExplicitDiscipline end

        function Philote.setup!(d::NoComputeDiscipline)
            Philote.add_input!(d, "x", [1], "m")
            Philote.add_output!(d, "y", [1], "m")
        end

        d = NoComputeDiscipline()
        inputs = Dict("x" => [1.0])
        @test_throws ErrorException Philote.compute(d, inputs)
    end

    @testset "Basic Computation" begin
        d = SimpleDiscipline()
        Philote.setup!(d)

        inputs = Dict("x" => [5.0])
        outputs = Philote.compute(d, inputs)

        @test haskey(outputs, "y")
        @test outputs["y"][1] == 10.0  # 2.0 * 5.0
    end

    @testset "Gradient Computation" begin
        d = SimpleDiscipline()
        Philote.setup!(d)

        inputs = Dict("x" => [3.0])
        partials = Philote.compute_partials(d, inputs)

        @test haskey(partials, "y")
        @test haskey(partials["y"], "x")
        @test partials["y"]["x"][1] == 2.0
    end

    @testset "Multiple Inputs/Outputs" begin
        mutable struct MultiDiscipline <: Philote.ExplicitDiscipline end

        function Philote.setup!(d::MultiDiscipline)
            Philote.add_input!(d, "x", [1], "m")
            Philote.add_input!(d, "y", [1], "m")
            Philote.add_output!(d, "sum", [1], "m")
            Philote.add_output!(d, "product", [1], "m**2")
            Philote.declare_partials!(d, "sum", "x")
            Philote.declare_partials!(d, "sum", "y")
            Philote.declare_partials!(d, "product", "x")
            Philote.declare_partials!(d, "product", "y")
        end

        function Philote.compute(d::MultiDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
            x = inputs["x"][1]
            y = inputs["y"][1]
            return Dict(
                "sum" => [x + y],
                "product" => [x * y]
            )
        end

        function Philote.compute_partials(d::MultiDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
            x = inputs["x"][1]
            y = inputs["y"][1]
            return Dict(
                "sum" => Dict("x" => [1.0], "y" => [1.0]),
                "product" => Dict("x" => [y], "y" => [x])
            )
        end

        d = MultiDiscipline()
        Philote.setup!(d)

        inputs = Dict("x" => [3.0], "y" => [4.0])
        outputs = Philote.compute(d, inputs)

        @test outputs["sum"][1] == 7.0
        @test outputs["product"][1] == 12.0

        partials = Philote.compute_partials(d, inputs)
        @test partials["sum"]["x"][1] == 1.0
        @test partials["sum"]["y"][1] == 1.0
        @test partials["product"]["x"][1] == 4.0
        @test partials["product"]["y"][1] == 3.0
    end

    @testset "Array Inputs/Outputs" begin
        mutable struct ArrayDiscipline <: Philote.ExplicitDiscipline end

        function Philote.setup!(d::ArrayDiscipline)
            Philote.add_input!(d, "vec", [3], "m")
            Philote.add_output!(d, "norm", [1], "m")
            Philote.add_output!(d, "doubled", [3], "m")
        end

        function Philote.compute(d::ArrayDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
            vec = inputs["vec"]
            norm = sqrt(sum(vec .^ 2))
            doubled = 2.0 .* vec
            return Dict(
                "norm" => [norm],
                "doubled" => doubled
            )
        end

        d = ArrayDiscipline()
        Philote.setup!(d)

        inputs = Dict("vec" => [3.0, 4.0, 0.0])
        outputs = Philote.compute(d, inputs)

        @test outputs["norm"][1] ≈ 5.0
        @test outputs["doubled"] ≈ [6.0, 8.0, 0.0]
    end

    @testset "Default Partials (Empty)" begin
        # Discipline that doesn't implement compute_partials
        mutable struct NoPartialsDiscipline <: Philote.ExplicitDiscipline end

        function Philote.setup!(d::NoPartialsDiscipline)
            Philote.add_input!(d, "x", [1], "m")
            Philote.add_output!(d, "y", [1], "m")
        end

        function Philote.compute(d::NoPartialsDiscipline, inputs::Dict{String, <:AbstractArray{Float64}})
            return Dict("y" => [inputs["x"][1] * 2.0])
        end

        d = NoPartialsDiscipline()
        Philote.setup!(d)

        inputs = Dict("x" => [1.0])
        partials = Philote.compute_partials(d, inputs)

        # Should return empty dictionary
        @test isempty(partials)
    end
end
