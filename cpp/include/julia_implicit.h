#ifndef PHILOTE_JULIA_IMPLICIT_H
#define PHILOTE_JULIA_IMPLICIT_H

#include <implicit.h>
#include <julia.h>
#include <string>

namespace philote {

/**
 * @brief C++ wrapper for Julia implicit disciplines
 *
 * This class wraps a Julia ImplicitDiscipline and exposes it as a
 * Philote C++ ImplicitDiscipline, allowing it to be served via gRPC.
 *
 * Implicit disciplines have residual equations that must be solved
 * to determine outputs. They provide:
 * - compute_residuals(): Evaluate residual equations
 * - solve_residuals(): Solve for outputs that drive residuals to zero
 * - compute_residual_partials(): Provide Jacobian information
 *
 * Usage:
 * ```cpp
 * JuliaImplicitDiscipline discipline(
 *     "path/to/discipline.jl",
 *     "MyImplicitDiscipline"
 * );
 *
 * grpc::ServerBuilder builder;
 * builder.AddListeningPort(address, grpc::InsecureServerCredentials());
 * discipline.RegisterServices(builder);
 *
 * auto server = builder.BuildAndStart();
 * server->Wait();
 * ```
 */
class JuliaImplicitDiscipline : public ImplicitDiscipline {
public:
    /**
     * @brief Construct a Julia implicit discipline wrapper
     *
     * @param filepath Path to the .jl file containing the discipline
     * @param type_name Name of the Julia type (must be a subtype of ImplicitDiscipline)
     *
     * @throws JuliaException if file cannot be loaded or type not found
     */
    JuliaImplicitDiscipline(const std::string& filepath,
                           const std::string& type_name);

    /**
     * @brief Destructor
     *
     * Cleans up GC roots for Julia objects
     */
    virtual ~JuliaImplicitDiscipline();

    // Override Discipline lifecycle methods
    void Initialize() override;
    void Setup() override;
    void SetupPartials() override;

    // Override implicit discipline computation methods
    void ComputeResiduals(const Variables& inputs,
                         const Variables& outputs,
                         Variables& residuals) override;

    void SolveResiduals(const Variables& inputs,
                       Variables& outputs) override;

    void ComputeResidualGradients(const Variables& inputs,
                                 const Variables& outputs,
                                 Partials& partials) override;

    /**
     * @brief Set discipline options
     *
     * Converts options to Julia Dict and calls Philote.set_options!()
     *
     * @param options Map of option name => (value string, type string)
     */
    void SetOptions(const std::map<std::string, std::pair<std::string, std::string>>& options);

private:
    /**
     * @brief Load the Julia module and create discipline instance
     */
    void LoadDiscipline();

    /**
     * @brief Extract metadata from Julia discipline
     *
     * Calls Philote.get_metadata() and populates the C++ discipline
     * with inputs, outputs, residuals, and partials declarations.
     */
    void ExtractMetadata();

    /**
     * @brief Call Julia's setup! function
     */
    void CallSetup();

    // Julia discipline information
    std::string filepath_;
    std::string type_name_;

    // Julia objects (protected from GC)
    jl_module_t* module_;
    jl_value_t* discipline_obj_;

    // Cached Julia function pointers
    jl_function_t* setup_fn_;
    jl_function_t* compute_residuals_fn_;
    jl_function_t* solve_residuals_fn_;
    jl_function_t* compute_residual_partials_fn_;
    jl_function_t* get_metadata_fn_;
    jl_function_t* set_options_fn_;
};

} // namespace philote

#endif // PHILOTE_JULIA_IMPLICIT_H
