/**
 * @file paraboloid_server.cpp
 * @brief Example server wrapping a Julia paraboloid discipline
 *
 * This example demonstrates how to wrap a Julia ExplicitDiscipline
 * and serve it via gRPC using the Philote protocol.
 *
 * The Julia discipline is defined in ../../examples/paraboloid.jl
 *
 * Build and run:
 *   mkdir build && cd build
 *   cmake .. -DBUILD_EXAMPLES=ON
 *   make
 *   ./paraboloid_server
 *
 * Test with a C++ client:
 *   # In another terminal
 *   cd Philote-Cpp/build
 *   ./examples/paraboloid/paraboloid_client
 */

#include "julia_explicit.h"
#include <grpc++/grpc++.h>
#include <iostream>
#include <memory>
#include <string>
#include <filesystem>

using grpc::Server;
using grpc::ServerBuilder;

int main(int argc, char** argv) {
    std::cout << "====================================================\n";
    std::cout << "  Philote Julia Paraboloid Server\n";
    std::cout << "====================================================\n\n";

    // Default server address
    std::string server_address("localhost:50051");

    // Determine path to Julia discipline file
    // Assume we're running from build directory
    std::filesystem::path exe_path = std::filesystem::canonical(argv[0]);
    std::filesystem::path build_dir = exe_path.parent_path();
    std::filesystem::path repo_root = build_dir.parent_path();
    std::filesystem::path discipline_path = repo_root / "examples" / "paraboloid.jl";

    // Check if file exists
    if (!std::filesystem::exists(discipline_path)) {
        std::cerr << "Error: Julia discipline file not found at: "
                  << discipline_path << std::endl;
        std::cerr << "\nPlease run from the build directory or ensure the "
                  << "paraboloid.jl file exists." << std::endl;
        return 1;
    }

    std::cout << "Loading Julia discipline from:\n";
    std::cout << "  " << discipline_path << "\n\n";

    try {
        // Create Julia-wrapped discipline
        philote::JuliaExplicitDiscipline discipline(
            discipline_path.string(),
            "ParaboloidDiscipline"
        );

        std::cout << "\n====================================================\n";
        std::cout << "  Starting gRPC Server\n";
        std::cout << "====================================================\n\n";

        // Build and start gRPC server
        ServerBuilder builder;
        builder.AddListeningPort(server_address,
                                grpc::InsecureServerCredentials());
        discipline.RegisterServices(builder);

        std::unique_ptr<Server> server(builder.BuildAndStart());

        std::cout << "Server listening on: " << server_address << "\n";
        std::cout << "\nThe server is now ready to accept connections.\n";
        std::cout << "Press Ctrl+C to stop the server.\n\n";
        std::cout << "====================================================\n";

        // Wait for server to be shutdown
        server->Wait();

    } catch (const philote::JuliaException& e) {
        std::cerr << "\n❌ Julia Error: " << e.what() << std::endl;
        return 1;
    } catch (const std::exception& e) {
        std::cerr << "\n❌ Error: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "\nServer shutdown complete.\n";
    return 0;
}
