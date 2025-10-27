"""
    Test Paraboloid Discipline

Tests for the example ParaboloidDiscipline implementation.
Tests both forward computation and analytical gradients.
"""

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
using Test

# Load paraboloid discipline
include(joinpath(@__DIR__, "..", "examples", "paraboloid.jl"))

@testset "Paraboloid Discipline" begin
    @testset "Type and Setup" begin
        d = ParaboloidDiscipline()

        @test d isa Philote.ExplicitDiscipline
        @test d.scale_factor == 1.0
        @test d.offset == 0.0

        Philote.setup!(d)
        meta = Philote.get_metadata(d)

        @test meta.name == "ParaboloidDiscipline"
        @test meta.version == "0.1.0"
    end

    @testset "Metadata" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)
        meta = Philote.get_metadata(d)

        # Check inputs
        @test length(meta.inputs) == 2
        @test haskey(meta.inputs, "x")
        @test haskey(meta.inputs, "y")
        @test meta.inputs["x"] == ([1], "m")
        @test meta.inputs["y"] == ([1], "m")

        # Check outputs
        @test length(meta.outputs) == 1
        @test haskey(meta.outputs, "f_xy")
        @test meta.outputs["f_xy"] == ([1], "m**2")

        # Check options
        @test length(meta.options) == 2
        @test haskey(meta.options, "scale_factor")
        @test haskey(meta.options, "offset")
        @test meta.options["scale_factor"] == "float"
        @test meta.options["offset"] == "float"

        # Check partials
        @test length(meta.partials) == 2
        @test ("f_xy", "x") in meta.partials
        @test ("f_xy", "y") in meta.partials
    end

    @testset "Forward Computation" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)

        @testset "Test Point 1: (0, 0)" begin
            inputs = Dict("x" => [0.0], "y" => [0.0])
            outputs = Philote.compute(d, inputs)

            # f(0, 0) = (0-3)^2 + 0*0 + (0+4)^2 - 3
            #         = 9 + 0 + 16 - 3 = 22
            @test outputs["f_xy"][1] ≈ 22.0
        end

        @testset "Test Point 2: (1, 2)" begin
            inputs = Dict("x" => [1.0], "y" => [2.0])
            outputs = Philote.compute(d, inputs)

            # f(1, 2) = (1-3)^2 + 1*2 + (2+4)^2 - 3
            #         = 4 + 2 + 36 - 3 = 39
            @test outputs["f_xy"][1] ≈ 39.0
        end

        @testset "Test Point 3: (3, -4)" begin
            inputs = Dict("x" => [3.0], "y" => [-4.0])
            outputs = Philote.compute(d, inputs)

            # f(3, -4) = (3-3)^2 + 3*(-4) + (-4+4)^2 - 3
            #          = 0 - 12 + 0 - 3 = -15
            @test outputs["f_xy"][1] ≈ -15.0
        end

        @testset "Test Point 4: (-2.5, 1.5)" begin
            inputs = Dict("x" => [-2.5], "y" => [1.5])
            outputs = Philote.compute(d, inputs)

            # f(-2.5, 1.5) = (-2.5-3)^2 + (-2.5)*1.5 + (1.5+4)^2 - 3
            #              = 30.25 - 3.75 + 30.25 - 3 = 53.75
            @test outputs["f_xy"][1] ≈ 53.75
        end
    end

    @testset "Gradient Computation" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)

        @testset "Gradients at (0, 0)" begin
            inputs = Dict("x" => [0.0], "y" => [0.0])
            partials = Philote.compute_partials(d, inputs)

            # ∂f/∂x = 2(x-3) + y = 2(0-3) + 0 = -6
            # ∂f/∂y = 2(y+4) + x = 2(0+4) + 0 = 8
            @test partials["f_xy"]["x"][1] ≈ -6.0
            @test partials["f_xy"]["y"][1] ≈ 8.0
        end

        @testset "Gradients at (1, 2)" begin
            inputs = Dict("x" => [1.0], "y" => [2.0])
            partials = Philote.compute_partials(d, inputs)

            # ∂f/∂x = 2(1-3) + 2 = -4 + 2 = -2
            # ∂f/∂y = 2(2+4) + 1 = 12 + 1 = 13
            @test partials["f_xy"]["x"][1] ≈ -2.0
            @test partials["f_xy"]["y"][1] ≈ 13.0
        end

        @testset "Gradients at (3, -4)" begin
            inputs = Dict("x" => [3.0], "y" => [-4.0])
            partials = Philote.compute_partials(d, inputs)

            # ∂f/∂x = 2(3-3) + (-4) = 0 - 4 = -4
            # ∂f/∂y = 2(-4+4) + 3 = 0 + 3 = 3
            @test partials["f_xy"]["x"][1] ≈ -4.0
            @test partials["f_xy"]["y"][1] ≈ 3.0
        end
    end

    @testset "Finite Difference Check" begin
        # Verify analytical gradients against finite differences
        d = ParaboloidDiscipline()
        Philote.setup!(d)

        x0, y0 = 2.0, -1.0
        h = 1e-7

        inputs_center = Dict("x" => [x0], "y" => [y0])
        f_center = Philote.compute(d, inputs_center)["f_xy"][1]

        # Finite difference for ∂f/∂x
        inputs_x_plus = Dict("x" => [x0 + h], "y" => [y0])
        f_x_plus = Philote.compute(d, inputs_x_plus)["f_xy"][1]
        fd_dx = (f_x_plus - f_center) / h

        # Finite difference for ∂f/∂y
        inputs_y_plus = Dict("x" => [x0], "y" => [y0 + h])
        f_y_plus = Philote.compute(d, inputs_y_plus)["f_xy"][1]
        fd_dy = (f_y_plus - f_center) / h

        # Analytical gradients
        partials = Philote.compute_partials(d, inputs_center)
        analytical_dx = partials["f_xy"]["x"][1]
        analytical_dy = partials["f_xy"]["y"][1]

        # Should match to high precision
        @test analytical_dx ≈ fd_dx atol=1e-5
        @test analytical_dy ≈ fd_dy atol=1e-5
    end

    @testset "Options - Scale Factor" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)

        # Default scale factor
        inputs = Dict("x" => [1.0], "y" => [2.0])
        outputs_default = Philote.compute(d, inputs)
        f_default = outputs_default["f_xy"][1]

        # With scale factor = 2.0
        set_options!(d, Dict("scale_factor" => 2.0))
        @test d.scale_factor == 2.0

        outputs_scaled = Philote.compute(d, inputs)
        f_scaled = outputs_scaled["f_xy"][1]

        @test f_scaled ≈ 2.0 * f_default

        # Gradients should also scale
        partials_default = Philote.compute_partials(ParaboloidDiscipline(), inputs)
        d2 = ParaboloidDiscipline()
        set_options!(d2, Dict("scale_factor" => 2.0))
        partials_scaled = Philote.compute_partials(d2, inputs)

        @test partials_scaled["f_xy"]["x"][1] ≈ 2.0 * partials_default["f_xy"]["x"][1]
        @test partials_scaled["f_xy"]["y"][1] ≈ 2.0 * partials_default["f_xy"]["y"][1]
    end

    @testset "Options - Offset" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)
        set_options!(d, Dict("offset" => 10.0))

        @test d.offset == 10.0

        inputs = Dict("x" => [1.0], "y" => [2.0])

        # Compute with offset
        outputs = Philote.compute(d, inputs)
        f_with_offset = outputs["f_xy"][1]

        # Without offset
        d_no_offset = ParaboloidDiscipline()
        outputs_no_offset = Philote.compute(d_no_offset, inputs)
        f_no_offset = outputs_no_offset["f_xy"][1]

        @test f_with_offset ≈ f_no_offset + 10.0

        # Gradients should NOT be affected by offset
        partials_with_offset = Philote.compute_partials(d, inputs)
        partials_no_offset = Philote.compute_partials(d_no_offset, inputs)

        @test partials_with_offset["f_xy"]["x"][1] ≈ partials_no_offset["f_xy"]["x"][1]
        @test partials_with_offset["f_xy"]["y"][1] ≈ partials_no_offset["f_xy"]["y"][1]
    end

    @testset "Options - Combined" begin
        d = ParaboloidDiscipline()
        Philote.setup!(d)
        set_options!(d, Dict("scale_factor" => 3.0, "offset" => 5.0))

        inputs = Dict("x" => [0.0], "y" => [0.0])
        outputs = Philote.compute(d, inputs)

        # f(0,0) = 22 (base value)
        # scaled and offset: 3.0 * 22 + 5.0 = 71.0
        @test outputs["f_xy"][1] ≈ 71.0
    end
end
