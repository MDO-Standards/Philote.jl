#include "julia_implicit.h"
#include "julia_runtime.h"
#include "julia_marshal.h"
#include <iostream>

namespace philote {

JuliaImplicitDiscipline::JuliaImplicitDiscipline(const std::string& filepath,
                                                 const std::string& type_name)
    : filepath_(filepath),
      type_name_(type_name),
      module_(nullptr),
      discipline_obj_(nullptr),
      setup_fn_(nullptr),
      compute_residuals_fn_(nullptr),
      solve_residuals_fn_(nullptr),
      compute_residual_partials_fn_(nullptr),
      get_metadata_fn_(nullptr),
      set_options_fn_(nullptr) {

    // Initialize Julia runtime
    JuliaRuntime::Instance().Initialize();

    // Load the Julia discipline
    LoadDiscipline();
}

JuliaImplicitDiscipline::~JuliaImplicitDiscipline() {
    // Remove GC roots
    if (discipline_obj_ != nullptr) {
        JuliaRuntime::Instance().RemoveGCRoot(discipline_obj_);
    }
}

void JuliaImplicitDiscipline::Initialize() {
    // Base class initialization
    Discipline::Initialize();

    // Julia-specific initialization (if needed)
    // This is called before Setup()
}

void JuliaImplicitDiscipline::LoadDiscipline() {
    auto& runtime = JuliaRuntime::Instance();

    // Load the Julia module
    std::cout << "Loading Julia implicit discipline from: " << filepath_ << std::endl;
    module_ = runtime.LoadModule(filepath_);

    // Get the discipline constructor
    jl_function_t* constructor = runtime.GetFunction(module_, type_name_);

    // Create discipline instance: discipline = MyImplicitDiscipline()
    std::cout << "Creating Julia implicit discipline instance: " << type_name_ << std::endl;
    discipline_obj_ = jl_call0(constructor);
    runtime.CheckException();

    // Protect from GC
    runtime.AddGCRoot(discipline_obj_);

    // Cache function pointers from Philote module
    // First, load/access the Philote module
    jl_value_t* philote_module = jl_eval_string("Philote");
    runtime.CheckException();

    // Get setup! function
    setup_fn_ = jl_get_function((jl_module_t*)philote_module, "setup!");
    if (setup_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.setup! function");
    }

    // Get compute_residuals function
    compute_residuals_fn_ = jl_get_function((jl_module_t*)philote_module, "compute_residuals");
    if (compute_residuals_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.compute_residuals function");
    }

    // Get solve_residuals function
    solve_residuals_fn_ = jl_get_function((jl_module_t*)philote_module, "solve_residuals");
    if (solve_residuals_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.solve_residuals function");
    }

    // Get compute_residual_partials function
    compute_residual_partials_fn_ = jl_get_function((jl_module_t*)philote_module, "compute_residual_partials");
    if (compute_residual_partials_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.compute_residual_partials function");
    }

    // Get get_metadata function
    get_metadata_fn_ = jl_get_function((jl_module_t*)philote_module, "get_metadata");
    if (get_metadata_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.get_metadata function");
    }

    // Get set_options! function
    set_options_fn_ = jl_get_function((jl_module_t*)philote_module, "set_options!");
    if (set_options_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.set_options! function");
    }

    std::cout << "Julia implicit discipline loaded successfully" << std::endl;
}

void JuliaImplicitDiscipline::Setup() {
    std::cout << "Setting up Julia implicit discipline..." << std::endl;

    // Call the Julia setup! function
    CallSetup();

    // Extract metadata from Julia and populate C++ discipline
    ExtractMetadata();

    std::cout << "Julia implicit discipline setup complete" << std::endl;
}

void JuliaImplicitDiscipline::CallSetup() {
    auto& runtime = JuliaRuntime::Instance();

    // Call Philote.setup!(discipline)
    jl_call1(setup_fn_, discipline_obj_);
    runtime.CheckException();
}

void JuliaImplicitDiscipline::ExtractMetadata() {
    auto& runtime = JuliaRuntime::Instance();

    // Call Philote.get_metadata(discipline)
    jl_value_t* meta = jl_call1(get_metadata_fn_, discipline_obj_);
    runtime.CheckException();

    // Extract metadata fields
    // Metadata structure:
    // - inputs::Dict{String, Tuple{Vector{Int64}, String}}     (field 0)
    // - outputs::Dict{String, Tuple{Vector{Int64}, String}}    (field 1)
    // - residuals::Dict{String, Tuple{Vector{Int64}, String}}  (field 2)
    // - options::Dict{String, String}                          (field 3)
    // - partials::Vector{Tuple{String, String}}                (field 4)
    // - name::String                                           (field 5)
    // - version::String                                        (field 6)

    // Get inputs dictionary (field 0)
    jl_value_t* inputs_dict = jl_get_nth_field(meta, 0);
    std::vector<std::string> input_names = JuliaMarshal::GetDictKeys(inputs_dict);

    for (const std::string& name : input_names) {
        jl_value_t* tuple = JuliaMarshal::GetDictValue(inputs_dict, name);

        jl_value_t* shape_vec = jl_get_nth_field(tuple, 0);
        std::vector<int64_t> shape = JuliaMarshal::FromJuliaVector(shape_vec);

        jl_value_t* units_str = jl_get_nth_field(tuple, 1);
        std::string units(jl_string_ptr(units_str));

        AddInput(name, shape, units);
        std::cout << "  Input: " << name << " shape=[";
        for (size_t i = 0; i < shape.size(); i++) {
            std::cout << shape[i];
            if (i < shape.size() - 1) std::cout << ", ";
        }
        std::cout << "] units=" << units << std::endl;
    }

    // Get outputs dictionary (field 1)
    jl_value_t* outputs_dict = jl_get_nth_field(meta, 1);
    std::vector<std::string> output_names = JuliaMarshal::GetDictKeys(outputs_dict);

    for (const std::string& name : output_names) {
        jl_value_t* tuple = JuliaMarshal::GetDictValue(outputs_dict, name);

        jl_value_t* shape_vec = jl_get_nth_field(tuple, 0);
        std::vector<int64_t> shape = JuliaMarshal::FromJuliaVector(shape_vec);

        jl_value_t* units_str = jl_get_nth_field(tuple, 1);
        std::string units(jl_string_ptr(units_str));

        AddOutput(name, shape, units);
        std::cout << "  Output: " << name << " shape=[";
        for (size_t i = 0; i < shape.size(); i++) {
            std::cout << shape[i];
            if (i < shape.size() - 1) std::cout << ", ";
        }
        std::cout << "] units=" << units << std::endl;
    }

    // Get residuals dictionary (field 2) - specific to implicit disciplines
    jl_value_t* residuals_dict = jl_get_nth_field(meta, 2);
    std::vector<std::string> residual_names = JuliaMarshal::GetDictKeys(residuals_dict);

    for (const std::string& name : residual_names) {
        jl_value_t* tuple = JuliaMarshal::GetDictValue(residuals_dict, name);

        jl_value_t* shape_vec = jl_get_nth_field(tuple, 0);
        std::vector<int64_t> shape = JuliaMarshal::FromJuliaVector(shape_vec);

        jl_value_t* units_str = jl_get_nth_field(tuple, 1);
        std::string units(jl_string_ptr(units_str));

        AddOutput(name, shape, units);
        std::cout << "  Residual: " << name << " shape=[";
        for (size_t i = 0; i < shape.size(); i++) {
            std::cout << shape[i];
            if (i < shape.size() - 1) std::cout << ", ";
        }
        std::cout << "] units=" << units << std::endl;
    }

    // Get options dictionary (field 3)
    jl_value_t* options_dict = jl_get_nth_field(meta, 3);
    std::vector<std::string> option_names = JuliaMarshal::GetDictKeys(options_dict);

    for (const std::string& name : option_names) {
        jl_value_t* type_str = JuliaMarshal::GetDictValue(options_dict, name);
        std::string type(jl_string_ptr(type_str));

        AddOption(name, type);
        std::cout << "  Option: " << name << " type=" << type << std::endl;
    }

    // Get discipline name and version (fields 5 and 6)
    jl_value_t* name_str = jl_get_nth_field(meta, 5);
    jl_value_t* version_str = jl_get_nth_field(meta, 6);

    if (jl_is_string(name_str)) {
        std::cout << "  Discipline name: " << jl_string_ptr(name_str) << std::endl;
    }
    if (jl_is_string(version_str)) {
        std::cout << "  Version: " << jl_string_ptr(version_str) << std::endl;
    }
}

void JuliaImplicitDiscipline::SetupPartials() {
    std::cout << "Setting up partials..." << std::endl;

    auto& runtime = JuliaRuntime::Instance();

    // Get metadata
    jl_value_t* meta = jl_call1(get_metadata_fn_, discipline_obj_);
    runtime.CheckException();

    // Get partials vector (field 4)
    jl_value_t* partials_vec = jl_get_nth_field(meta, 4);

    if (jl_is_array(partials_vec)) {
        jl_array_t* arr = (jl_array_t*)partials_vec;
        size_t length = jl_array_len(arr);

        for (size_t i = 0; i < length; i++) {
            // Access array element - for Julia arrays of objects, use data pointer
            jl_value_t** data = (jl_value_t**)jl_array_data(arr, jl_value_t*);
            jl_value_t* tuple = data[i];

            // Extract (residual, input) pair
            jl_value_t* residual_str = jl_get_nth_field(tuple, 0);
            jl_value_t* input_str = jl_get_nth_field(tuple, 1);

            std::string residual(jl_string_ptr(residual_str));
            std::string input(jl_string_ptr(input_str));

            // Declare partial in C++ discipline
            DeclarePartials(residual, input);
            std::cout << "  Partial: ∂" << residual << "/∂" << input << std::endl;
        }
    }

    std::cout << "Partials setup complete" << std::endl;
}

void JuliaImplicitDiscipline::ComputeResiduals(const Variables& inputs,
                                               const Variables& outputs,
                                               Variables& residuals) {
    auto& runtime = JuliaRuntime::Instance();

    // Convert C++ inputs to Julia Dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    // Convert C++ outputs to Julia Dict
    jl_value_t* outputs_dict = JuliaMarshal::ToJuliaDict(outputs);

    // Protect from GC during computation
    JL_GC_PUSH2(&inputs_dict, &outputs_dict);

    // Call Philote.compute_residuals(discipline, inputs, outputs)
    // Note: The Julia interface signature is compute_residuals(discipline, inputs)
    // For implicit disciplines, outputs are typically part of inputs or the discipline state
    // Let's follow the simple signature for now
    jl_value_t* residuals_dict = jl_call2(compute_residuals_fn_,
                                         discipline_obj_,
                                         inputs_dict);
    runtime.CheckException();

    JL_GC_POP();

    // Convert Julia Dict to C++ residuals
    JuliaMarshal::FromJuliaDict(residuals_dict, residuals);
}

void JuliaImplicitDiscipline::SolveResiduals(const Variables& inputs,
                                            Variables& outputs) {
    auto& runtime = JuliaRuntime::Instance();

    // Convert C++ inputs to Julia Dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    JL_GC_PUSH1(&inputs_dict);

    // Call Philote.solve_residuals(discipline, inputs)
    // This should return a Dict of outputs that satisfy the residuals
    jl_value_t* outputs_dict = jl_call2(solve_residuals_fn_,
                                       discipline_obj_,
                                       inputs_dict);
    runtime.CheckException();

    JL_GC_POP();

    // Convert Julia Dict to C++ outputs
    JuliaMarshal::FromJuliaDict(outputs_dict, outputs);
}

void JuliaImplicitDiscipline::ComputeResidualGradients(const Variables& inputs,
                                                       const Variables& outputs,
                                                       Partials& partials) {
    auto& runtime = JuliaRuntime::Instance();

    // Convert C++ inputs to Julia Dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    // Convert C++ outputs to Julia Dict
    jl_value_t* outputs_dict = JuliaMarshal::ToJuliaDict(outputs);

    JL_GC_PUSH2(&inputs_dict, &outputs_dict);

    // Call Philote.compute_residual_partials(discipline, inputs)
    // Similar to compute_residuals, using simple signature
    jl_value_t* partials_dict = jl_call2(compute_residual_partials_fn_,
                                        discipline_obj_,
                                        inputs_dict);
    runtime.CheckException();

    JL_GC_POP();

    // Convert nested Julia Dict to C++ partials
    if (partials_dict != nullptr && !jl_is_nothing(partials_dict)) {
        JuliaMarshal::FromJuliaDict(partials_dict, partials);
    }
}

void JuliaImplicitDiscipline::SetOptions(
    const std::map<std::string, std::pair<std::string, std::string>>& options) {

    auto& runtime = JuliaRuntime::Instance();

    // Convert options map to Julia Dict
    jl_value_t* options_dict = JuliaMarshal::OptionsToJuliaDict(options);

    JL_GC_PUSH1(&options_dict);

    // Call Philote.set_options!(discipline, options_dict)
    jl_call2(set_options_fn_, discipline_obj_, options_dict);
    runtime.CheckException();

    JL_GC_POP();

    std::cout << "Options set successfully" << std::endl;
}

} // namespace philote
