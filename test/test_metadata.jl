"""
    Test Discipline Metadata Management

Tests for metadata storage, retrieval, and manipulation.
"""

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
using Test

@testset "Metadata Management" begin
    # Create a simple test discipline
    mutable struct TestDiscipline <: Philote.ExplicitDiscipline end

    @testset "Metadata Creation" begin
        discipline = TestDiscipline()
        meta = Philote.get_metadata(discipline)

        @test meta isa Philote.DisciplineMetadata
        @test meta.name == "UnnamedDiscipline"
        @test meta.version == "0.1.0"
        @test isempty(meta.inputs)
        @test isempty(meta.outputs)
        @test isempty(meta.residuals)
        @test isempty(meta.options)
        @test isempty(meta.partials)
    end

    @testset "Metadata Persistence" begin
        discipline = TestDiscipline()
        meta1 = Philote.get_metadata(discipline)
        meta1.name = "TestChanged"

        # Should get the same metadata object
        meta2 = Philote.get_metadata(discipline)
        @test meta2.name == "TestChanged"
        @test meta1 === meta2  # Same object
    end

    @testset "Multiple Disciplines" begin
        discipline1 = TestDiscipline()
        discipline2 = TestDiscipline()

        meta1 = Philote.get_metadata(discipline1)
        meta2 = Philote.get_metadata(discipline2)

        meta1.name = "Discipline1"
        meta2.name = "Discipline2"

        # Should have separate metadata
        @test meta1.name == "Discipline1"
        @test meta2.name == "Discipline2"
        @test meta1 !== meta2
    end

    @testset "Add Input" begin
        discipline = TestDiscipline()
        Philote.add_input!(discipline, "x", [1], "m")
        Philote.add_input!(discipline, "y", [2, 3], "kg")

        meta = Philote.get_metadata(discipline)
        @test length(meta.inputs) == 2
        @test haskey(meta.inputs, "x")
        @test haskey(meta.inputs, "y")
        @test meta.inputs["x"] == ([1], "m")
        @test meta.inputs["y"] == ([2, 3], "kg")
    end

    @testset "Add Output" begin
        discipline = TestDiscipline()
        Philote.add_output!(discipline, "f", [1], "m**2")
        Philote.add_output!(discipline, "g", [5], "N")

        meta = Philote.get_metadata(discipline)
        @test length(meta.outputs) == 2
        @test haskey(meta.outputs, "f")
        @test haskey(meta.outputs, "g")
        @test meta.outputs["f"] == ([1], "m**2")
        @test meta.outputs["g"] == ([5], "N")
    end

    @testset "Add Option" begin
        discipline = TestDiscipline()
        Philote.add_option!(discipline, "tol", "float")
        Philote.add_option!(discipline, "max_iter", "int")

        meta = Philote.get_metadata(discipline)
        @test length(meta.options) == 2
        @test meta.options["tol"] == "float"
        @test meta.options["max_iter"] == "int"
    end

    @testset "Declare Partials" begin
        discipline = TestDiscipline()
        Philote.declare_partials!(discipline, "f", "x")
        Philote.declare_partials!(discipline, "f", "y")
        Philote.declare_partials!(discipline, "g", "x")

        meta = Philote.get_metadata(discipline)
        @test length(meta.partials) == 3
        @test ("f", "x") in meta.partials
        @test ("f", "y") in meta.partials
        @test ("g", "x") in meta.partials
    end

    @testset "Complete Setup" begin
        discipline = TestDiscipline()

        # Simulate a complete setup
        Philote.add_input!(discipline, "x", [1], "m")
        Philote.add_input!(discipline, "y", [1], "m")
        Philote.add_output!(discipline, "f", [1], "m**2")
        Philote.add_option!(discipline, "scale", "float")
        Philote.declare_partials!(discipline, "f", "x")
        Philote.declare_partials!(discipline, "f", "y")

        meta = Philote.get_metadata(discipline)
        meta.name = "CompleteTest"
        meta.version = "1.0.0"

        @test length(meta.inputs) == 2
        @test length(meta.outputs) == 1
        @test length(meta.options) == 1
        @test length(meta.partials) == 2
        @test meta.name == "CompleteTest"
        @test meta.version == "1.0.0"
    end

    @testset "Set Options" begin
        # Test the default set_options! (does nothing)
        discipline = TestDiscipline()
        options = Dict("foo" => 1.0, "bar" => "test")

        # Should not throw even though discipline doesn't override set_options!
        @test_nowarn Philote.set_options!(discipline, options)
    end
end
