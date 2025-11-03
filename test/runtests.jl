using Test
using Philote

@testset "Philote.jl" begin
    @testset "Module exports" begin
        @test isdefined(Philote, :AbstractDiscipline)
        @test isdefined(Philote, :ExplicitDiscipline)
        @test isdefined(Philote, :ImplicitDiscipline)
        @test isdefined(Philote, :setup!)
        @test isdefined(Philote, :compute)
        @test isdefined(Philote, :compute_partials)
        @test isdefined(Philote, :add_input!)
        @test isdefined(Philote, :add_output!)
        @test isdefined(Philote, :declare_partials!)
        @test isdefined(Philote, :add_residual!)
        @test isdefined(Philote, :compute_residuals)
        @test isdefined(Philote, :solve_residuals)
        @test isdefined(Philote, :residual_partials)
        @test isdefined(Philote, :get_metadata)
    end

    @testset "Simple Explicit Discipline" begin
        # Define a simple test discipline
        mutable struct TestExplicitDiscipline <: Philote.ExplicitDiscipline
            TestExplicitDiscipline() = new()
        end

        function Philote.setup!(discipline::TestExplicitDiscipline)
            Philote.add_input!(discipline, "x", [1], "m")
            Philote.add_output!(discipline, "y", [1], "m^2")
            Philote.declare_partials!(discipline, "y", "x")
        end

        function Philote.compute(discipline::TestExplicitDiscipline, inputs::Dict{String,Array})
            x = inputs["x"][1]
            return Dict("y" => [x^2])
        end

        function Philote.compute_partials(discipline::TestExplicitDiscipline, inputs::Dict{String,Array})
            x = inputs["x"][1]
            return Dict("y" => Dict("x" => reshape([2*x], 1, 1)))
        end

        # Test discipline instantiation
        disc = TestExplicitDiscipline()
        @test disc isa Philote.ExplicitDiscipline
        @test disc isa Philote.AbstractDiscipline

        # Test setup
        Philote.setup!(disc)
        metadata = Philote.get_metadata(disc)
        @test metadata.name == "TestExplicitDiscipline"
        @test haskey(metadata.inputs, "x")
        @test haskey(metadata.outputs, "y")
        @test ("y", "x") in metadata.partials

        # Test compute
        inputs = Dict("x" => [3.0])
        outputs = Philote.compute(disc, inputs)
        @test outputs["y"][1] ≈ 9.0

        # Test compute_partials
        partials = Philote.compute_partials(disc, inputs)
        @test partials["y"]["x"][1,1] ≈ 6.0
    end

    @testset "Simple Implicit Discipline" begin
        # Define a simple implicit test discipline (linear equation: a*x = b)
        mutable struct TestImplicitDiscipline <: Philote.ImplicitDiscipline
            TestImplicitDiscipline() = new()
        end

        function Philote.setup!(discipline::TestImplicitDiscipline)
            Philote.add_input!(discipline, "a", [1], "unitless")
            Philote.add_input!(discipline, "b", [1], "unitless")
            Philote.add_output!(discipline, "x", [1], "unitless")
            Philote.add_residual!(discipline, "r", [1], "unitless")
            Philote.declare_partials!(discipline, "r", "a")
            Philote.declare_partials!(discipline, "r", "b")
            Philote.declare_partials!(discipline, "r", "x")
        end

        function Philote.compute_residuals(discipline::TestImplicitDiscipline,
                                          inputs::Dict{String,Array},
                                          outputs::Dict{String,Array})
            a = inputs["a"][1]
            b = inputs["b"][1]
            x = outputs["x"][1]
            r = a * x - b
            return Dict("r" => [r])
        end

        function Philote.solve_residuals(discipline::TestImplicitDiscipline,
                                        inputs::Dict{String,Array},
                                        outputs::Dict{String,Array})
            a = inputs["a"][1]
            b = inputs["b"][1]
            x = b / a
            outputs["x"][1] = x
        end

        function Philote.residual_partials(discipline::TestImplicitDiscipline,
                                          inputs::Dict{String,Array},
                                          outputs::Dict{String,Array})
            a = inputs["a"][1]
            x = outputs["x"][1]
            return Dict(
                "r" => Dict(
                    "a" => reshape([x], 1, 1),
                    "b" => reshape([-1.0], 1, 1),
                    "x" => reshape([a], 1, 1)
                )
            )
        end

        # Test discipline instantiation
        disc = TestImplicitDiscipline()
        @test disc isa Philote.ImplicitDiscipline
        @test disc isa Philote.AbstractDiscipline

        # Test setup
        Philote.setup!(disc)
        metadata = Philote.get_metadata(disc)
        @test metadata.name == "TestImplicitDiscipline"
        @test haskey(metadata.inputs, "a")
        @test haskey(metadata.inputs, "b")
        @test haskey(metadata.outputs, "x")
        @test haskey(metadata.residuals, "r")

        # Test compute_residuals
        inputs = Dict("a" => [2.0], "b" => [6.0])
        outputs = Dict("x" => [3.0])  # correct solution
        residuals = Philote.compute_residuals(disc, inputs, outputs)
        @test abs(residuals["r"][1]) < 1e-10

        # Test solve_residuals
        outputs = Dict("x" => [0.0])  # wrong initial guess
        Philote.solve_residuals(disc, inputs, outputs)
        @test outputs["x"][1] ≈ 3.0

        # Test residual_partials
        outputs = Dict("x" => [3.0])
        partials = Philote.residual_partials(disc, inputs, outputs)
        @test partials["r"]["a"][1,1] ≈ 3.0
        @test partials["r"]["b"][1,1] ≈ -1.0
        @test partials["r"]["x"][1,1] ≈ 2.0
    end
end
