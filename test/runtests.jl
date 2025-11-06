using Test
using Philote

# Define test disciplines at module scope so methods are visible to Philote
mutable struct TestExplicitDiscipline <: Philote.ExplicitDiscipline
    TestExplicitDiscipline() = new()
end

function Philote.setup!(discipline::TestExplicitDiscipline)
    Philote.add_input!(discipline, "x", [1], "m")
    Philote.add_output!(discipline, "y", [1], "m^2")
    Philote.declare_partials!(discipline, "y", "x")
end

function Philote.compute(
    discipline::TestExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}}
)
    x = inputs["x"][1]
    return Dict("y" => [x^2])
end

function Philote.compute_partials(
    discipline::TestExplicitDiscipline, inputs::Dict{String, <:AbstractArray{Float64}}
)
    x = inputs["x"][1]
    return Dict("y" => Dict("x" => reshape([2*x], 1, 1)))
end

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

function Philote.compute_residuals(
    discipline::TestImplicitDiscipline,
    inputs::Dict{String, <:AbstractArray{Float64}},
    outputs::Dict{String, <:AbstractArray{Float64}},
)
    a = inputs["a"][1]
    b = inputs["b"][1]
    x = outputs["x"][1]
    r = a * x - b
    return Dict("r" => [r])
end

function Philote.solve_residuals(
    discipline::TestImplicitDiscipline,
    inputs::Dict{String, <:AbstractArray{Float64}},
    outputs::Dict{String, <:AbstractArray{Float64}},
)
    a = inputs["a"][1]
    b = inputs["b"][1]
    x = b / a
    outputs["x"][1] = x
end

function Philote.residual_partials(
    discipline::TestImplicitDiscipline,
    inputs::Dict{String, <:AbstractArray{Float64}},
    outputs::Dict{String, <:AbstractArray{Float64}},
)
    a = inputs["a"][1]
    x = outputs["x"][1]
    return Dict(
        "r" => Dict(
            "a" => reshape([x], 1, 1),
            "b" => reshape([-1.0], 1, 1),
            "x" => reshape([a], 1, 1),
        ),
    )
end

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
        # Test discipline instantiation
        disc = TestExplicitDiscipline()
        @test disc isa Philote.ExplicitDiscipline
        @test disc isa Philote.AbstractDiscipline

        # Test setup
        Philote.setup!(disc)
        metadata = Philote.get_metadata(disc)
        @test metadata.name == "UnnamedDiscipline"  # Default name
        @test haskey(metadata.inputs, "x")
        @test haskey(metadata.outputs, "y")
        @test ("y", "x") in metadata.partials

        # Test compute
        inputs = Dict("x" => [3.0])
        outputs = Philote.compute(disc, inputs)
        @test outputs["y"][1] ≈ 9.0

        # Test compute_partials
        partials = Philote.compute_partials(disc, inputs)
        @test partials["y"]["x"][1, 1] ≈ 6.0
    end

    @testset "Simple Implicit Discipline" begin
        # Test discipline instantiation
        disc = TestImplicitDiscipline()
        @test disc isa Philote.ImplicitDiscipline
        @test disc isa Philote.AbstractDiscipline

        # Test setup
        Philote.setup!(disc)
        metadata = Philote.get_metadata(disc)
        @test metadata.name == "UnnamedDiscipline"  # Default name
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
        @test partials["r"]["a"][1, 1] ≈ 3.0
        @test partials["r"]["b"][1, 1] ≈ -1.0
        @test partials["r"]["x"][1, 1] ≈ 2.0
    end

    @testset "Input Validation" begin
        disc = TestExplicitDiscipline()

        # Test invalid shape dimensions (non-positive values)
        @test_throws ArgumentError Philote.add_input!(disc, "bad", [0], "m")
        @test_throws ArgumentError Philote.add_input!(disc, "bad", [-1], "m")
        @test_throws ArgumentError Philote.add_input!(disc, "bad", [1, 0, 1], "m")

        @test_throws ArgumentError Philote.add_output!(disc, "bad", [0], "m")
        @test_throws ArgumentError Philote.add_output!(disc, "bad", [-5], "m")

        # Test that positive shapes work
        @test_nowarn Philote.add_input!(disc, "good", [1], "m")
        @test_nowarn Philote.add_input!(disc, "multi", [2, 3], "m")
        @test_nowarn Philote.add_output!(disc, "out", [10, 20, 30], "m^3")
    end

    @testset "Metadata Edge Cases" begin
        disc = TestExplicitDiscipline()

        # Test metadata before setup
        metadata = Philote.get_metadata(disc)
        @test metadata.name == "UnnamedDiscipline"
        @test isempty(metadata.inputs)
        @test isempty(metadata.outputs)

        # Test metadata shapes and units
        Philote.add_input!(disc, "vec", [3], "kg")
        Philote.add_output!(disc, "matrix", [2, 2], "N")
        metadata = Philote.get_metadata(disc)

        @test metadata.inputs["vec"] == ([3], "kg")
        @test metadata.outputs["matrix"] == ([2, 2], "N")
    end

    @testset "Multi-dimensional Arrays" begin
        mutable struct VectorDiscipline <: Philote.ExplicitDiscipline
            VectorDiscipline() = new()
        end

        function Philote.setup!(discipline::VectorDiscipline)
            Philote.add_input!(discipline, "vec", [3], "m")
            Philote.add_output!(discipline, "norm", [1], "m")
        end

        function Philote.compute(
            discipline::VectorDiscipline, inputs::Dict{String, <:AbstractArray{Float64}}
        )
            vec = inputs["vec"]
            norm_val = sqrt(sum(vec .^ 2))
            return Dict("norm" => [norm_val])
        end

        disc = VectorDiscipline()
        Philote.setup!(disc)

        inputs = Dict("vec" => [3.0, 4.0, 0.0])
        outputs = Philote.compute(disc, inputs)
        @test outputs["norm"][1] ≈ 5.0
    end

    @testset "Example Integration Tests" begin
        # Test paraboloid example (skip Pkg.activate which doesn't work in test env)
        # Define the discipline inline instead
        mutable struct ParaboloidDisciplineTest <: Philote.ExplicitDiscipline
            scale_factor::Float64
            offset::Float64
            ParaboloidDisciplineTest() = new(1.0, 0.0)
        end

        function Philote.setup!(discipline::ParaboloidDisciplineTest)
            Philote.add_option!(discipline, "scale_factor", "float")
            Philote.add_option!(discipline, "offset", "float")
            Philote.add_input!(discipline, "x", [1], "m")
            Philote.add_input!(discipline, "y", [1], "m")
            Philote.add_output!(discipline, "f_xy", [1], "m**2")
            Philote.declare_partials!(discipline, "f_xy", "x")
            Philote.declare_partials!(discipline, "f_xy", "y")
            meta = Philote.get_metadata(discipline)
            meta.name = "ParaboloidDiscipline"
            meta.version = "0.1.0"
        end

        function Philote.compute(discipline::ParaboloidDisciplineTest, inputs::Dict{String,<:AbstractArray{Float64}})
            x = inputs["x"][1]
            y = inputs["y"][1]
            f = (x - 3)^2 + x*y + (y + 4)^2 - 3
            scaled = f * discipline.scale_factor + discipline.offset
            return Dict("f_xy" => [scaled])
        end

        function Philote.compute_partials(discipline::ParaboloidDisciplineTest, inputs::Dict{String,<:AbstractArray{Float64}})
            x = inputs["x"][1]
            y = inputs["y"][1]
            df_dx = 2.0 * (x - 3.0) + y
            df_dy = x + 2.0 * (y + 4.0)
            scaled_dx = df_dx * discipline.scale_factor
            scaled_dy = df_dy * discipline.scale_factor
            return Dict(
                "f_xy" => Dict(
                    "x" => [scaled_dx],
                    "y" => [scaled_dy]
                )
            )
        end

        paraboloid = ParaboloidDisciplineTest()
        Philote.setup!(paraboloid)

        # Test metadata
        meta = Philote.get_metadata(paraboloid)
        @test meta.name == "ParaboloidDiscipline"
        @test haskey(meta.inputs, "x")
        @test haskey(meta.inputs, "y")
        @test haskey(meta.outputs, "f_xy")

        # Test compute
        inputs = Dict("x" => [0.0], "y" => [0.0])
        outputs = Philote.compute(paraboloid, inputs)
        expected = (0.0 - 3.0)^2 + 0.0 * 0.0 + (0.0 + 4.0)^2 - 3.0
        @test outputs["f_xy"][1] ≈ expected

        # Test partials
        partials = Philote.compute_partials(paraboloid, inputs)
        @test haskey(partials["f_xy"], "x")
        @test haskey(partials["f_xy"], "y")

        # Test quadratic example
        include("../examples/quadratic.jl")

        quadratic = QuadraticImplicitDiscipline()
        Philote.setup!(quadratic)

        # Test metadata
        meta = Philote.get_metadata(quadratic)
        @test meta.name == "QuadraticImplicitDiscipline"
        @test haskey(meta.inputs, "a")
        @test haskey(meta.inputs, "b")
        @test haskey(meta.inputs, "c")
        @test haskey(meta.outputs, "x")
        @test haskey(meta.residuals, "R")

        # Test solve: x² - 5x + 6 = 0 (solutions: 2 or 3)
        inputs = Dict("a" => [1.0], "b" => [-5.0], "c" => [6.0])
        outputs = Dict("x" => [0.0])
        Philote.solve_residuals(quadratic, inputs, outputs)

        # Should find one of the two roots
        x_sol = outputs["x"][1]
        @test x_sol ≈ 3.0 || x_sol ≈ 2.0

        # Verify residual is near zero
        residuals = Philote.compute_residuals(quadratic, inputs, outputs)
        @test abs(residuals["R"][1]) < 1e-10
    end

    @testset "Options and Configuration" begin
        mutable struct ConfigurableDiscipline <: Philote.ExplicitDiscipline
            scale::Float64
            ConfigurableDiscipline() = new(1.0)
        end

        function Philote.setup!(discipline::ConfigurableDiscipline)
            Philote.add_option!(discipline, "scale", "float")
            Philote.add_input!(discipline, "x", [1], "m")
            Philote.add_output!(discipline, "y", [1], "m")
        end

        function Philote.set_options!(
            discipline::ConfigurableDiscipline, options::Dict{String, <:Any}
        )
            if haskey(options, "scale")
                discipline.scale = Float64(options["scale"])
            end
        end

        function Philote.compute(
            discipline::ConfigurableDiscipline,
            inputs::Dict{String, <:AbstractArray{Float64}},
        )
            return Dict("y" => [discipline.scale * inputs["x"][1]])
        end

        disc = ConfigurableDiscipline()
        Philote.setup!(disc)

        meta = Philote.get_metadata(disc)
        @test haskey(meta.options, "scale")

        # Test with default scale
        @test disc.scale == 1.0
        outputs = Philote.compute(disc, Dict("x" => [5.0]))
        @test outputs["y"][1] ≈ 5.0

        # Test with modified scale
        Philote.set_options!(disc, Dict("scale" => 2.5))
        @test disc.scale == 2.5
        outputs = Philote.compute(disc, Dict("x" => [5.0]))
        @test outputs["y"][1] ≈ 12.5
    end
end
