"""
    Test Quadratic Implicit Discipline

Tests for the QuadraticImplicitDiscipline example implementation.
"""

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Philote
using Test

# Load quadratic implicit discipline
include(joinpath(@__DIR__, "..", "examples", "quadratic_implicit.jl"))

@testset "Quadratic Implicit Discipline" begin
    @testset "Type and Setup" begin
        d = QuadraticImplicitDiscipline()

        @test d isa Philote.ImplicitDiscipline
        @test d.tolerance == 1e-10
        @test d.max_iterations == 100

        Philote.setup!(d)
        meta = Philote.get_metadata(d)

        @test meta.name == "QuadraticImplicitDiscipline"
        @test meta.version == "0.1.0"
    end

    @testset "Metadata" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)
        meta = Philote.get_metadata(d)

        # Check inputs
        @test length(meta.inputs) == 3
        @test haskey(meta.inputs, "a")
        @test haskey(meta.inputs, "b")
        @test haskey(meta.inputs, "c")

        # Check outputs
        @test length(meta.outputs) == 1
        @test haskey(meta.outputs, "x")

        # Check residuals
        @test length(meta.residuals) == 1
        @test haskey(meta.residuals, "R")

        # Check partials
        @test length(meta.partials) == 4
        @test ("R", "x") in meta.partials
        @test ("R", "a") in meta.partials
        @test ("R", "b") in meta.partials
        @test ("R", "c") in meta.partials
    end

    @testset "Solve Quadratic Equations" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        @testset "x² - 5x + 6 = 0 (solutions: 2, 3)" begin
            inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            @test x == 3.0  # Should return the larger root
        end

        @testset "x² - 2x - 3 = 0 (solutions: -1, 3)" begin
            inputs = Dict("a" => [1.0], "b" => [-2.0], "c" => [-3.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            @test x == 3.0
        end

        @testset "2x² + 3x - 2 = 0 (solutions: 0.5, -2)" begin
            inputs = Dict("a" => [2.0], "b" => [3.0], "c" => [-2.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            # Should return the root with larger absolute value
            @test x ≈ -2.0 || x ≈ 0.5
        end

        @testset "x² - 4 = 0 (perfect square: solutions ±2)" begin
            inputs = Dict("a" => [1.0], "b" => [0.0], "c" => [-4.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            @test abs(x) ≈ 2.0
        end

        @testset "x² - 1 = 0 (solutions: ±1)" begin
            inputs = Dict("a" => [1.0], "b" => [0.0], "c" => [-1.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            @test abs(x) ≈ 1.0
        end
    end

    @testset "Compute Residuals" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        @testset "Residual at solution" begin
            # For x² - 5x + 6 = 0, x=3 is a solution
            inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0], "x" => [3.0])
            residuals = Philote.compute_residuals(d, inputs)

            @test residuals["R"][1] ≈ 0.0 atol=1e-10
        end

        @testset "Residual away from solution" begin
            # For x² - 5x + 6, at x=0: R = 6
            inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0], "x" => [0.0])
            residuals = Philote.compute_residuals(d, inputs)

            @test residuals["R"][1] ≈ 6.0
        end

        @testset "Residual at x=1" begin
            # For x² - 5x + 6, at x=1: R = 1 - 5 + 6 = 2
            inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0], "x" => [1.0])
            residuals = Philote.compute_residuals(d, inputs)

            @test residuals["R"][1] ≈ 2.0
        end
    end

    @testset "Residual is Zero at Solved Solution" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        test_cases = [
            ("a" => [1.0], "b" => [-5.0], "c" => [6.0]),
            ("a" => [1.0], "b" => [-2.0], "c" => [-3.0]),
            ("a" => [2.0], "b" => [3.0], "c" => [-2.0]),
            ("a" => [1.0], "b" => [0.0], "c" => [-9.0]),
        ]

        for test_inputs in test_cases
            inputs = Dict(test_inputs...)
            outputs = Philote.solve_residuals(d, inputs)
            x = outputs["x"][1]

            # Verify residual is zero at solution
            inputs_with_x = merge(inputs, Dict("x" => [x]))
            residuals = Philote.compute_residuals(d, inputs_with_x)

            @test abs(residuals["R"][1]) < 1e-10
        end
    end

    @testset "Compute Residual Partials" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        @testset "Partials at x=3, a=1, b=-5, c=6" begin
            inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0], "x" => [3.0])
            partials = Philote.compute_residual_partials(d, inputs)

            # dR/dx = 2ax + b = 2*1*3 + (-5) = 1
            @test partials["R"]["x"][1] ≈ 1.0

            # dR/da = x² = 9
            @test partials["R"]["a"][1] ≈ 9.0

            # dR/db = x = 3
            @test partials["R"]["b"][1] ≈ 3.0

            # dR/dc = 1
            @test partials["R"]["c"][1] ≈ 1.0
        end

        @testset "Partials at x=0" begin
            inputs = Dict("a" => [2.0], "b" => [3.0], "c" => [-2.0], "x" => [0.0])
            partials = Philote.compute_residual_partials(d, inputs)

            # dR/dx = 2*2*0 + 3 = 3
            @test partials["R"]["x"][1] ≈ 3.0

            # dR/da = 0² = 0
            @test partials["R"]["a"][1] ≈ 0.0

            # dR/db = 0
            @test partials["R"]["b"][1] ≈ 0.0

            # dR/dc = 1
            @test partials["R"]["c"][1] ≈ 1.0
        end
    end

    @testset "Finite Difference Check" begin
        # Verify analytical Jacobian against finite differences
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        a, b, c, x = 1.5, -2.0, 0.5, 1.0
        h = 1e-7

        # Compute residual at center point
        inputs_center = Dict("a" => [a], "b" => [b], "c" => [c], "x" => [x])
        R_center = Philote.compute_residuals(d, inputs_center)["R"][1]

        # Finite difference for dR/dx
        inputs_x_plus = Dict("a" => [a], "b" => [b], "c" => [c], "x" => [x + h])
        R_x_plus = Philote.compute_residuals(d, inputs_x_plus)["R"][1]
        fd_dx = (R_x_plus - R_center) / h

        # Finite difference for dR/da
        inputs_a_plus = Dict("a" => [a + h], "b" => [b], "c" => [c], "x" => [x])
        R_a_plus = Philote.compute_residuals(d, inputs_a_plus)["R"][1]
        fd_da = (R_a_plus - R_center) / h

        # Finite difference for dR/db
        inputs_b_plus = Dict("a" => [a], "b" => [b + h], "c" => [c], "x" => [x])
        R_b_plus = Philote.compute_residuals(d, inputs_b_plus)["R"][1]
        fd_db = (R_b_plus - R_center) / h

        # Finite difference for dR/dc
        inputs_c_plus = Dict("a" => [a], "b" => [b], "c" => [c + h], "x" => [x])
        R_c_plus = Philote.compute_residuals(d, inputs_c_plus)["R"][1]
        fd_dc = (R_c_plus - R_center) / h

        # Analytical partials
        partials = Philote.compute_residual_partials(d, inputs_center)
        analytical_dx = partials["R"]["x"][1]
        analytical_da = partials["R"]["a"][1]
        analytical_db = partials["R"]["b"][1]
        analytical_dc = partials["R"]["c"][1]

        # Compare
        @test analytical_dx ≈ fd_dx atol=1e-5
        @test analytical_da ≈ fd_da atol=1e-5
        @test analytical_db ≈ fd_db atol=1e-5
        @test analytical_dc ≈ fd_dc atol=1e-5
    end

    @testset "Edge Cases" begin
        d = QuadraticImplicitDiscipline()
        Philote.setup!(d)

        @testset "Linear equation (a=0)" begin
            # 0*x² + 2x + 4 = 0 → x = -2
            inputs = Dict("a" => [0.0], "b" => [2.0], "c" => [4.0])
            outputs = Philote.solve_residuals(d, inputs)

            x = outputs["x"][1]
            @test x ≈ -2.0
        end

        @testset "No real solutions (negative discriminant)" begin
            # x² + x + 1 = 0 has no real solutions
            inputs = Dict("a" => [1.0], "b" => [1.0], "c" => [1.0])

            @test_throws ErrorException Philote.solve_residuals(d, inputs)
        end
    end
end
