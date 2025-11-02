/**
 * @file philote_julia_server.cpp
 * @brief Generic launcher for Julia disciplines via YAML configuration
 *
 * This is a generic server that can load any Julia discipline based on
 * a YAML configuration file. This eliminates the need to create separate
 * executables for each discipline.
 *
 * Usage:
 *   ./philote_julia_server config.yaml
 *
 * Example YAML configuration:
 * ```yaml
 * discipline:
 *   kind: explicit  # or 'implicit'
 *   julia_file: examples/paraboloid.jl
 *   julia_type: ParaboloidDiscipline
 *
 * server:
 *   address: localhost:50051
 * ```
 *
 * Build:
 *   mkdir build && cd build
 *   cmake .. -DBUILD_EXAMPLES=ON
 *   make
 *
 * Run:
 *   ./philote_julia_server ../examples/configs/paraboloid.yaml
 */

#include "config.h"
#include "julia_explicit.h"
#include "julia_implicit.h"
#include "julia_runtime.h"
#include <grpc++/grpc++.h>
#include <iostream>
#include <memory>
#include <string>
#include <filesystem>

using grpc::Server;
using grpc::ServerBuilder;

/**
 * @brief Print usage information
 */
void PrintUsage(const char* program_name) {
    std::cout << "Usage: " << program_name << " <config.yaml>\n\n";
    std::cout << "Generic Philote Julia discipline server that loads configuration\n";
    std::cout << "from a YAML file.\n\n";
    std::cout << "Example configuration:\n";
    std::cout << "  discipline:\n";
    std::cout << "    kind: explicit  # or 'implicit'\n";
    std::cout << "    julia_file: examples/paraboloid.jl\n";
    std::cout << "    julia_type: ParaboloidDiscipline\n";
    std::cout << "  server:\n";
    std::cout << "    address: localhost:50051\n";
}

int main(int argc, char** argv) {
    // Check for config file argument
    if (argc != 2) {
        PrintUsage(argv[0]);
        return 1;
    }

    std::string config_path = argv[1];

    std::cout << "====================================================\n";
    std::cout << "  Philote Julia Server (Generic Launcher)\n";
    std::cout << "====================================================\n\n";

    // Load configuration
    philote::ServerConfig config;
    try {
        std::cout << "Loading configuration from: " << config_path << "\n\n";
        config = philote::ServerConfig::LoadFromFile(config_path);
    } catch (const philote::ConfigException& e) {
        std::cerr << "❌ Configuration Error: " << e.what() << "\n\n";
        PrintUsage(argv[0]);
        return 1;
    } catch (const std::exception& e) {
        std::cerr << "❌ Error loading configuration: " << e.what() << "\n";
        return 1;
    }

    // Print configuration
    std::cout << "Configuration loaded:\n";
    std::cout << "  Discipline kind: "
              << (config.discipline_kind == philote::DisciplineKind::Explicit
                      ? "Explicit" : "Implicit") << "\n";
    std::cout << "  Julia file:      " << config.julia_file << "\n";
    std::cout << "  Julia type:      " << config.julia_type << "\n";
    std::cout << "  Server address:  " << config.server_address << "\n\n";

    // Check if Julia file exists
    if (!std::filesystem::exists(config.julia_file)) {
        std::cerr << "❌ Error: Julia discipline file not found: "
                  << config.julia_file << "\n";
        std::cerr << "\nPlease check the path in your configuration file.\n";
        return 1;
    }

    try {
        std::cout << "Loading Julia discipline...\n";

        // Create discipline based on kind
        if (config.discipline_kind == philote::DisciplineKind::Explicit) {
            philote::JuliaExplicitDiscipline discipline(
                config.julia_file,
                config.julia_type
            );

            std::cout << "\n====================================================\n";
            std::cout << "  Starting gRPC Server\n";
            std::cout << "====================================================\n\n";

            // Build and start gRPC server
            ServerBuilder builder;
            builder.AddListeningPort(config.server_address,
                                    grpc::InsecureServerCredentials());
            discipline.RegisterServices(builder);

            std::unique_ptr<Server> server(builder.BuildAndStart());

            std::cout << "✓ Server listening on: " << config.server_address << "\n";
            std::cout << "\nThe server is now ready to accept connections.\n";
            std::cout << "Press Ctrl+C to stop the server.\n\n";
            std::cout << "====================================================\n";

            // Wait for server to be shutdown
            server->Wait();

        } else {
            philote::JuliaImplicitDiscipline discipline(
                config.julia_file,
                config.julia_type
            );

            std::cout << "\n====================================================\n";
            std::cout << "  Starting gRPC Server\n";
            std::cout << "====================================================\n\n";

            // Build and start gRPC server
            ServerBuilder builder;
            builder.AddListeningPort(config.server_address,
                                    grpc::InsecureServerCredentials());
            discipline.RegisterServices(builder);

            std::unique_ptr<Server> server(builder.BuildAndStart());

            std::cout << "✓ Server listening on: " << config.server_address << "\n";
            std::cout << "\nThe server is now ready to accept connections.\n";
            std::cout << "Press Ctrl+C to stop the server.\n\n";
            std::cout << "====================================================\n";

            // Wait for server to be shutdown
            server->Wait();
        }

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
