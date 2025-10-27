#ifndef PHILOTE_JULIA_EXPLICIT_H
#define PHILOTE_JULIA_EXPLICIT_H

#include <philote/explicit.h>
#include <julia.h>
#include <string>

namespace philote {

/**
 * @brief C++ wrapper for Julia explicit disciplines
 *
 * This class wraps a Julia ExplicitDiscipline and exposes it as a
 * Philote C++ ExplicitDiscipline, allowing it to be served via gRPC.
 *
 * Usage:
 * ```cpp
 * JuliaExplicitDiscipline discipline(
 *     "path/to/discipline.jl",
 *     "MyDiscipline"
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
class JuliaExplicitDiscipline : public ExplicitDiscipline {
public:
    /**
     * @brief Construct a Julia explicit discipline wrapper
     *
     * @param filepath Path to the .jl file containing the discipline
     * @param typename Name of the Julia type (must be a subtype of ExplicitDiscipline)
     *
     * @throws JuliaException if file cannot be loaded or type not found
     */
    JuliaExplicitDiscipline(const std::string& filepath,
                           const std::string& typename);

    /**
     * @brief Destructor
     *
     * Cleans up GC roots for Julia objects
     */
    virtual ~JuliaExplicitDiscipline();

    // Override Discipline lifecycle methods
    void Initialize() override;
    void Setup() override;
    void SetupPartials() override;

    // Override computation methods
    void Compute(const Variables& inputs, Variables& outputs) override;
    void ComputePartials(const Variables& inputs, Partials& partials) override;

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
     * with inputs, outputs, and partials declarations.
     */
    void ExtractMetadata();

    /**
     * @brief Call Julia's setup! function
     */
    void CallSetup();

    // Julia discipline information
    std::string filepath_;
    std::string typename_;

    // Julia objects (protected from GC)
    jl_module_t* module_;
    jl_value_t* discipline_obj_;

    // Cached Julia function pointers
    jl_function_t* setup_fn_;
    jl_function_t* compute_fn_;
    jl_function_t* compute_partials_fn_;
    jl_function_t* get_metadata_fn_;
    jl_function_t* set_options_fn_;
};

} // namespace philote

#endif // PHILOTE_JULIA_EXPLICIT_H
