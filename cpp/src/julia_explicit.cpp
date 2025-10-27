#include "julia_explicit.h"
#include "julia_runtime.h"
#include "julia_marshal.h"
#include <iostream>

namespace philote {

JuliaExplicitDiscipline::JuliaExplicitDiscipline(const std::string& filepath,
                                                 const std::string& typename)
    : filepath_(filepath),
      typename_(typename),
      module_(nullptr),
      discipline_obj_(nullptr),
      setup_fn_(nullptr),
      compute_fn_(nullptr),
      compute_partials_fn_(nullptr),
      get_metadata_fn_(nullptr),
      set_options_fn_(nullptr) {

    // Initialize Julia runtime
    JuliaRuntime::Instance().Initialize();

    // Load the Julia discipline
    LoadDiscipline();
}

JuliaExplicitDiscipline::~JuliaExplicitDiscipline() {
    // Remove GC roots
    if (discipline_obj_ != nullptr) {
        JuliaRuntime::Instance().RemoveGCRoot(discipline_obj_);
    }
}

void JuliaExplicitDiscipline::Initialize() {
    // Base class initialization
    Discipline::Initialize();

    // Julia-specific initialization (if needed)
    // This is called before Setup()
}

void JuliaExplicitDiscipline::LoadDiscipline() {
    auto& runtime = JuliaRuntime::Instance();

    // Load the Julia module
    std::cout << "Loading Julia module from: " << filepath_ << std::endl;
    module_ = runtime.LoadModule(filepath_);

    // Get the discipline constructor
    jl_function_t* constructor = runtime.GetFunction(module_, typename_);

    // Create discipline instance: discipline = MyDiscipline()
    std::cout << "Creating Julia discipline instance: " << typename_ << std::endl;
    discipline_obj_ = jl_call0(constructor);
    runtime.CheckException();

    // Protect from GC
    runtime.AddGCRoot(discipline_obj_);

    // Cache function pointers from Philote module
    // We need to get Philote.setup!, Philote.compute, etc.

    // First, we need to load/access the Philote module
    jl_value_t* philote_module = jl_eval_string("Philote");
    runtime.CheckException();

    // Get setup! function from Philote module
    setup_fn_ = jl_get_function((jl_module_t*)philote_module, "setup!");
    if (setup_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.setup! function");
    }

    // Get compute function
    compute_fn_ = jl_get_function((jl_module_t*)philote_module, "compute");
    if (compute_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.compute function");
    }

    // Get compute_partials function
    compute_partials_fn_ = jl_get_function((jl_module_t*)philote_module, "compute_partials");
    if (compute_partials_fn_ == nullptr) {
        throw JuliaException("Could not find Philote.compute_partials function");
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

    std::cout << "Julia discipline loaded successfully" << std::endl;
}

void JuliaExplicitDiscipline::Setup() {
    std::cout << "Setting up Julia discipline..." << std::endl;

    // Call the Julia setup! function
    CallSetup();

    // Extract metadata from Julia and populate C++ discipline
    ExtractMetadata();

    std::cout << "Julia discipline setup complete" << std::endl;
}

void JuliaExplicitDiscipline::CallSetup() {
    auto& runtime = JuliaRuntime::Instance();

    // Call Philote.setup!(discipline)
    jl_call1(setup_fn_, discipline_obj_);
    runtime.CheckException();
}

void JuliaExplicitDiscipline::ExtractMetadata() {
    auto& runtime = JuliaRuntime::Instance();

    // Call Philote.get_metadata(discipline)
    jl_value_t* meta = jl_call1(get_metadata_fn_, discipline_obj_);
    runtime.CheckException();

    // Extract metadata fields
    // Metadata structure:
    // - inputs::Dict{String, Tuple{Vector{Int64}, String}}
    // - outputs::Dict{String, Tuple{Vector{Int64}, String}}
    // - residuals::Dict{String, Tuple{Vector{Int64}, String}}
    // - options::Dict{String, String}
    // - partials::Vector{Tuple{String, String}}
    // - name::String
    // - version::String

    // Get inputs dictionary (field 0)
    jl_value_t* inputs_dict = jl_get_nth_field(meta, 0);
    std::vector<std::string> input_names = JuliaMarshal::GetDictKeys(inputs_dict);

    for (const std::string& name : input_names) {
        jl_value_t* tuple = JuliaMarshal::GetDictValue(inputs_dict, name);

        // Extract shape (first element of tuple)
        jl_value_t* shape_vec = jl_get_nth_field(tuple, 0);
        std::vector<int64_t> shape = JuliaMarshal::FromJuliaVector(shape_vec);

        // Extract units (second element of tuple)
        jl_value_t* units_str = jl_get_nth_field(tuple, 1);
        std::string units(jl_string_ptr(units_str));

        // Add input to C++ discipline
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

void JuliaExplicitDiscipline::SetupPartials() {
    std::cout << "Setting up partials..." << std::endl;

    auto& runtime = JuliaRuntime::Instance();

    // Get metadata again (or cache it from Setup())
    jl_value_t* meta = jl_call1(get_metadata_fn_, discipline_obj_);
    runtime.CheckException();

    // Get partials vector (field 4)
    jl_value_t* partials_vec = jl_get_nth_field(meta, 4);

    if (jl_is_array(partials_vec)) {
        jl_array_t* arr = (jl_array_t*)partials_vec;
        size_t length = jl_array_len(arr);

        for (size_t i = 0; i < length; i++) {
            jl_value_t* tuple = jl_arrayref(arr, i);

            // Extract (output, input) pair
            jl_value_t* output_str = jl_get_nth_field(tuple, 0);
            jl_value_t* input_str = jl_get_nth_field(tuple, 1);

            std::string output(jl_string_ptr(output_str));
            std::string input(jl_string_ptr(input_str));

            // Declare partial in C++ discipline
            DeclarePartials(output, input);
            std::cout << "  Partial: ∂" << output << "/∂" << input << std::endl;
        }
    }

    std::cout << "Partials setup complete" << std::endl;
}

void JuliaExplicitDiscipline::Compute(const Variables& inputs,
                                     Variables& outputs) {
    auto& runtime = JuliaRuntime::Instance();

    // Convert C++ inputs to Julia Dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    // Protect from GC during computation
    JL_GC_PUSH1(&inputs_dict);

    // Call Philote.compute(discipline, inputs)
    jl_value_t* outputs_dict = jl_call2(compute_fn_,
                                       discipline_obj_,
                                       inputs_dict);
    runtime.CheckException();

    JL_GC_POP();

    // Convert Julia Dict to C++ outputs
    JuliaMarshal::FromJuliaDict(outputs_dict, outputs);
}

void JuliaExplicitDiscipline::ComputePartials(const Variables& inputs,
                                             Partials& partials) {
    auto& runtime = JuliaRuntime::Instance();

    // Convert C++ inputs to Julia Dict
    jl_value_t* inputs_dict = JuliaMarshal::ToJuliaDict(inputs);

    JL_GC_PUSH1(&inputs_dict);

    // Call Philote.compute_partials(discipline, inputs)
    jl_value_t* partials_dict = jl_call2(compute_partials_fn_,
                                        discipline_obj_,
                                        inputs_dict);
    runtime.CheckException();

    JL_GC_POP();

    // Convert nested Julia Dict to C++ partials
    if (partials_dict != nullptr && !jl_is_nothing(partials_dict)) {
        JuliaMarshal::FromJuliaDict(partials_dict, partials);
    }
}

void JuliaExplicitDiscipline::SetOptions(
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
