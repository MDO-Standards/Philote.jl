/**
 * @file test_julia_explicit.cpp
 * @brief Tests for JuliaExplicitDiscipline class
 */

#include <gtest/gtest.h>
#include "julia_explicit.h"
#include "julia_runtime.h"
#include <philote/variable.h>
#include <cmath>

using namespace philote;

class JuliaExplicitDisciplineTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Path to test discipline (paraboloid example)
        discipline_path_ = "../examples/paraboloid.jl";
    }

    std::string discipline_path_;
};

TEST_F(JuliaExplicitDisciplineTest, Construction) {
    EXPECT_NO_THROW({
        JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    });
}

TEST_F(JuliaExplicitDisciplineTest, InvalidFileThrows) {
    EXPECT_THROW({
        JuliaExplicitDiscipline discipline("nonexistent.jl", "MyDiscipline");
    }, JuliaException);
}

TEST_F(JuliaExplicitDisciplineTest, InvalidTypeThrows) {
    EXPECT_THROW({
        JuliaExplicitDiscipline discipline(discipline_path_, "NonExistentDiscipline");
    }, JuliaException);
}

TEST_F(JuliaExplicitDisciplineTest, Setup) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");

    EXPECT_NO_THROW(discipline.Setup());

    // Check that metadata was extracted
    // The discipline should have inputs, outputs declared
    // Note: We'd need access to protected members or public getters to test this fully
    // For now, just verify Setup doesn't throw
}

TEST_F(JuliaExplicitDisciplineTest, SetupPartials) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();

    EXPECT_NO_THROW(discipline.SetupPartials());
}

TEST_F(JuliaExplicitDisciplineTest, ComputeBasic) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    // Create inputs
    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 1.0;
    inputs["y"](0) = 2.0;

    // Create outputs
    Variables outputs;
    outputs["f_xy"] = Variable(kOutput, {1});

    // Compute
    EXPECT_NO_THROW(discipline.Compute(inputs, outputs));

    // Expected: f(1, 2) = (1-3)^2 + 1*2 + (2+4)^2 - 3
    //                   = 4 + 2 + 36 - 3 = 39
    EXPECT_DOUBLE_EQ(outputs["f_xy"](0), 39.0);
}

TEST_F(JuliaExplicitDisciplineTest, ComputeAtOrigin) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 0.0;
    inputs["y"](0) = 0.0;

    Variables outputs;
    outputs["f_xy"] = Variable(kOutput, {1});

    discipline.Compute(inputs, outputs);

    // f(0, 0) = (0-3)^2 + 0*0 + (0+4)^2 - 3 = 9 + 0 + 16 - 3 = 22
    EXPECT_DOUBLE_EQ(outputs["f_xy"](0), 22.0);
}

TEST_F(JuliaExplicitDisciplineTest, ComputeNegativeValues) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 3.0;
    inputs["y"](0) = -4.0;

    Variables outputs;
    outputs["f_xy"] = Variable(kOutput, {1});

    discipline.Compute(inputs, outputs);

    // f(3, -4) = (3-3)^2 + 3*(-4) + (-4+4)^2 - 3 = 0 - 12 + 0 - 3 = -15
    EXPECT_DOUBLE_EQ(outputs["f_xy"](0), -15.0);
}

TEST_F(JuliaExplicitDisciplineTest, ComputeMultipleTimes) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});

    Variables outputs;
    outputs["f_xy"] = Variable(kOutput, {1});

    // Test multiple evaluations
    std::vector<std::pair<double, double>> test_points = {
        {0.0, 0.0},
        {1.0, 1.0},
        {2.0, -1.0},
        {-1.0, 3.0},
        {5.0, -2.0}
    };

    for (const auto& [x, y] : test_points) {
        inputs["x"](0) = x;
        inputs["y"](0) = y;

        discipline.Compute(inputs, outputs);

        // Manually compute expected value
        double expected = (x - 3.0) * (x - 3.0) + x * y + (y + 4.0) * (y + 4.0) - 3.0;
        EXPECT_DOUBLE_EQ(outputs["f_xy"](0), expected) << "Failed at point (" << x << ", " << y << ")";
    }
}

TEST_F(JuliaExplicitDisciplineTest, ComputePartialsBasic) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 1.0;
    inputs["y"](0) = 2.0;

    Partials partials;
    partials["f_xy"] = std::map<std::string, Variable>();
    partials["f_xy"]["x"] = Variable(kInput, {1});
    partials["f_xy"]["y"] = Variable(kInput, {1});

    EXPECT_NO_THROW(discipline.ComputePartials(inputs, partials));

    // Expected: df/dx = 2(x-3) + y = 2(1-3) + 2 = -4 + 2 = -2
    //          df/dy = 2(y+4) + x = 2(2+4) + 1 = 12 + 1 = 13
    EXPECT_DOUBLE_EQ(partials["f_xy"]["x"](0), -2.0);
    EXPECT_DOUBLE_EQ(partials["f_xy"]["y"](0), 13.0);
}

TEST_F(JuliaExplicitDisciplineTest, ComputePartialsAtOrigin) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 0.0;
    inputs["y"](0) = 0.0;

    Partials partials;
    partials["f_xy"] = std::map<std::string, Variable>();
    partials["f_xy"]["x"] = Variable(kInput, {1});
    partials["f_xy"]["y"] = Variable(kInput, {1});

    discipline.ComputePartials(inputs, partials);

    // df/dx = 2(0-3) + 0 = -6
    // df/dy = 2(0+4) + 0 = 8
    EXPECT_DOUBLE_EQ(partials["f_xy"]["x"](0), -6.0);
    EXPECT_DOUBLE_EQ(partials["f_xy"]["y"](0), 8.0);
}

TEST_F(JuliaExplicitDisciplineTest, ComputePartialsMultipleTimes) {
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});

    Partials partials;
    partials["f_xy"] = std::map<std::string, Variable>();
    partials["f_xy"]["x"] = Variable(kInput, {1});
    partials["f_xy"]["y"] = Variable(kInput, {1});

    // Test multiple gradient evaluations
    std::vector<std::pair<double, double>> test_points = {
        {0.0, 0.0},
        {1.0, 2.0},
        {3.0, -4.0},
        {-2.5, 1.5}
    };

    for (const auto& [x, y] : test_points) {
        inputs["x"](0) = x;
        inputs["y"](0) = y;

        discipline.ComputePartials(inputs, partials);

        // Analytical gradients
        double df_dx = 2.0 * (x - 3.0) + y;
        double df_dy = 2.0 * (y + 4.0) + x;

        EXPECT_DOUBLE_EQ(partials["f_xy"]["x"](0), df_dx) << "df/dx failed at (" << x << ", " << y << ")";
        EXPECT_DOUBLE_EQ(partials["f_xy"]["y"](0), df_dy) << "df/dy failed at (" << x << ", " << y << ")";
    }
}

TEST_F(JuliaExplicitDisciplineTest, FiniteDifferenceCheck) {
    // Verify analytical gradients against finite differences
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    double x0 = 2.0;
    double y0 = -1.0;
    double h = 1e-7;

    // Compute function at center point
    Variables inputs_center;
    inputs_center["x"] = Variable(kInput, {1});
    inputs_center["y"] = Variable(kInput, {1});
    inputs_center["x"](0) = x0;
    inputs_center["y"](0) = y0;

    Variables outputs_center;
    outputs_center["f_xy"] = Variable(kOutput, {1});
    discipline.Compute(inputs_center, outputs_center);
    double f_center = outputs_center["f_xy"](0);

    // Finite difference for df/dx
    Variables inputs_x_plus;
    inputs_x_plus["x"] = Variable(kInput, {1});
    inputs_x_plus["y"] = Variable(kInput, {1});
    inputs_x_plus["x"](0) = x0 + h;
    inputs_x_plus["y"](0) = y0;

    Variables outputs_x_plus;
    outputs_x_plus["f_xy"] = Variable(kOutput, {1});
    discipline.Compute(inputs_x_plus, outputs_x_plus);
    double f_x_plus = outputs_x_plus["f_xy"](0);

    double fd_dx = (f_x_plus - f_center) / h;

    // Finite difference for df/dy
    Variables inputs_y_plus;
    inputs_y_plus["x"] = Variable(kInput, {1});
    inputs_y_plus["y"] = Variable(kInput, {1});
    inputs_y_plus["x"](0) = x0;
    inputs_y_plus["y"](0) = y0 + h;

    Variables outputs_y_plus;
    outputs_y_plus["f_xy"] = Variable(kOutput, {1});
    discipline.Compute(inputs_y_plus, outputs_y_plus);
    double f_y_plus = outputs_y_plus["f_xy"](0);

    double fd_dy = (f_y_plus - f_center) / h;

    // Analytical gradients
    Partials partials;
    partials["f_xy"] = std::map<std::string, Variable>();
    partials["f_xy"]["x"] = Variable(kInput, {1});
    partials["f_xy"]["y"] = Variable(kInput, {1});
    discipline.ComputePartials(inputs_center, partials);

    double analytical_dx = partials["f_xy"]["x"](0);
    double analytical_dy = partials["f_xy"]["y"](0);

    // Should match to high precision
    EXPECT_NEAR(analytical_dx, fd_dx, 1e-5);
    EXPECT_NEAR(analytical_dy, fd_dy, 1e-5);
}

TEST_F(JuliaExplicitDisciplineTest, MultipleDisciplineInstances) {
    // Test that multiple discipline instances can coexist
    JuliaExplicitDiscipline discipline1(discipline_path_, "ParaboloidDiscipline");
    JuliaExplicitDiscipline discipline2(discipline_path_, "ParaboloidDiscipline");

    discipline1.Setup();
    discipline2.Setup();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 1.0;
    inputs["y"](0) = 2.0;

    Variables outputs1, outputs2;
    outputs1["f_xy"] = Variable(kOutput, {1});
    outputs2["f_xy"] = Variable(kOutput, {1});

    discipline1.Compute(inputs, outputs1);
    discipline2.Compute(inputs, outputs2);

    // Both should produce same result
    EXPECT_DOUBLE_EQ(outputs1["f_xy"](0), outputs2["f_xy"](0));
    EXPECT_DOUBLE_EQ(outputs1["f_xy"](0), 39.0);
}

TEST_F(JuliaExplicitDisciplineTest, ThreadSafetySameInputs) {
    // Test computing with same discipline multiple times
    // (Julia is single-threaded, but this tests sequential calls)
    JuliaExplicitDiscipline discipline(discipline_path_, "ParaboloidDiscipline");
    discipline.Setup();
    discipline.SetupPartials();

    Variables inputs;
    inputs["x"] = Variable(kInput, {1});
    inputs["y"] = Variable(kInput, {1});
    inputs["x"](0) = 5.0;
    inputs["y"](0) = -3.0;

    Variables outputs;
    outputs["f_xy"] = Variable(kOutput, {1});

    // Compute same inputs multiple times
    double expected = (5.0 - 3.0) * (5.0 - 3.0) + 5.0 * (-3.0) + (-3.0 + 4.0) * (-3.0 + 4.0) - 3.0;

    for (int i = 0; i < 10; i++) {
        discipline.Compute(inputs, outputs);
        EXPECT_DOUBLE_EQ(outputs["f_xy"](0), expected) << "Iteration " << i;
    }
}
