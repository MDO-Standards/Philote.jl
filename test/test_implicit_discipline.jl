"""
    Test Implicit Discipline Interface

Tests for the ImplicitDiscipline abstract type and its required methods.
"""

module TestImplicitDiscipline

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
using Test

@testset "Implicit Discipline Interface" begin
    # Define a simple test implicit discipline
    mutable struct SimpleImplicitDiscipline <: Philote.ImplicitDiscipline
        SimpleImplicitDiscipline() = new()
    end

    function Philote.setup!(d::SimpleImplicitDiscipline)
        Philote.add_input!(d, "a", [1], "1")
        Philote.add_output!(d, "x", [1], "1")
        Philote.add_residual!(d, "R", [1], "1")
        Philote.declare_partials!(d, "R", "x")
        Philote.declare_partials!(d, "R", "a")
    end

    # R = x - 2a (residual is zero when x = 2a)
    function Philote.compute_residuals(d::SimpleImplicitDiscipline,
                                       inputs::Dict{String, <:AbstractArray{Float64}})
        a = inputs["a"][1]
        x = get(inputs, "x", [0.0])[1]
        R = x - 2.0 * a
        return Dict("R" => [R])
    end

    function Philote.solve_residuals(d::SimpleImplicitDiscipline,
                                     inputs::Dict{String, <:AbstractArray{Float64}})
        a = inputs["a"][1]
        x = 2.0 * a
        return Dict("x" => [x])
    end

    function Philote.compute_residual_partials(d::SimpleImplicitDiscipline,
                                               inputs::Dict{String, <:AbstractArray{Float64}})
        return Dict("R" => Dict("x" => [1.0], "a" => [-2.0]))
    end

    @testset "Type Hierarchy" begin
        d = SimpleImplicitDiscipline()
        @test d isa Philote.ImplicitDiscipline
        @test d isa Philote.AbstractDiscipline
    end

    @testset "Setup and Metadata" begin
        # Define a fresh discipline type for this test
        mutable struct FreshImplicitTest <: Philote.ImplicitDiscipline end

        function Philote.setup!(d::FreshImplicitTest)
            Philote.add_input!(d, "a", [1], "1")
            Philote.add_output!(d, "x", [1], "1")
            Philote.add_residual!(d, "R", [1], "1")
        end

        d = FreshImplicitTest()
        Philote.setup!(d)

        meta = Philote.get_metadata(d)
        # Check that the expected keys are present
        # (don't check exact counts as metadata may persist across tests)
        @test haskey(meta.inputs, "a")
        @test haskey(meta.outputs, "x")
        @test haskey(meta.residuals, "R")
        @test meta.inputs["a"] == ([1], "1")
        @test meta.outputs["x"] == ([1], "1")
        @test meta.residuals["R"] == ([1], "1")
    end

    @testset "Add Residual" begin
        d = SimpleImplicitDiscipline()
        Philote.add_residual!(d, "R1", [2], "m")
        Philote.add_residual!(d, "R2", [3, 3], "kg")

        meta = Philote.get_metadata(d)
        @test length(meta.residuals) == 2
        @test meta.residuals["R1"] == ([2], "m")
        @test meta.residuals["R2"] == ([3, 3], "kg")
    end

    @testset "Compute Residuals" begin
        d = SimpleImplicitDiscipline()
        Philote.setup!(d)

        inputs = Dict("a" => [5.0], "x" => [10.0])
        residuals = Philote.compute_residuals(d, inputs)

        @test haskey(residuals, "R")
        @test residuals["R"][1] == 0.0  # 10 - 2*5 = 0
    end

    @testset "Solve Residuals" begin
        d = SimpleImplicitDiscipline()
        Philote.setup!(d)

        inputs = Dict("a" => [7.0])
        outputs = Philote.solve_residuals(d, inputs)

        @test haskey(outputs, "x")
        @test outputs["x"][1] == 14.0  # x = 2*a = 2*7 = 14
    end

    @testset "Residual is Zero at Solution" begin
        d = SimpleImplicitDiscipline()
        Philote.setup!(d)

        # Solve for x
        inputs = Dict("a" => [3.0])
        outputs = Philote.solve_residuals(d, inputs)

        # Check residual is zero
        inputs_with_x = merge(inputs, Dict("x" => outputs["x"]))
        residuals = Philote.compute_residuals(d, inputs_with_x)
        @test abs(residuals["R"][1]) < 1e-10
    end

    @testset "Compute Residual Partials" begin
        d = SimpleImplicitDiscipline()
        Philote.setup!(d)

        inputs = Dict("a" => [2.0], "x" => [4.0])
        partials = Philote.compute_residual_partials(d, inputs)

        @test haskey(partials, "R")
        @test haskey(partials["R"], "x")
        @test haskey(partials["R"], "a")
        @test partials["R"]["x"][1] == 1.0
        @test partials["R"]["a"][1] == -2.0
    end

    @testset "Required Methods" begin
        # Discipline without compute_residuals should error
        mutable struct NoComputeResiduals <: Philote.ImplicitDiscipline end

        function Philote.setup!(d::NoComputeResiduals)
            Philote.add_input!(d, "x", [1], "m")
            Philote.add_residual!(d, "R", [1], "m")
        end

        d = NoComputeResiduals()
        inputs = Dict("x" => [1.0])
        @test_throws ErrorException Philote.compute_residuals(d, inputs)

        # Discipline without solve_residuals should error
        mutable struct NoSolveResiduals <: Philote.ImplicitDiscipline end

        function Philote.setup!(d::NoSolveResiduals)
            Philote.add_input!(d, "x", [1], "m")
        end

        d2 = NoSolveResiduals()
        @test_throws ErrorException Philote.solve_residuals(d2, inputs)
    end

    @testset "Default Residual Partials (Empty)" begin
        # Discipline that doesn't implement compute_residual_partials
        mutable struct NoPartialsDiscipline <: Philote.ImplicitDiscipline end

        function Philote.setup!(d::NoPartialsDiscipline)
            Philote.add_input!(d, "x", [1], "m")
            Philote.add_residual!(d, "R", [1], "m")
        end

        function Philote.compute_residuals(d::NoPartialsDiscipline,
                                           inputs::Dict{String, <:AbstractArray{Float64}})
            return Dict("R" => [inputs["x"][1]])
        end

        function Philote.solve_residuals(d::NoPartialsDiscipline,
                                         inputs::Dict{String, <:AbstractArray{Float64}})
            return Dict()
        end

        d = NoPartialsDiscipline()
        Philote.setup!(d)

        inputs = Dict("x" => [1.0])
        partials = Philote.compute_residual_partials(d, inputs)

        # Should return empty dictionary
        @test isempty(partials)
    end
end

end # module TestImplicitDiscipline
