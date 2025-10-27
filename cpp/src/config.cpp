#include "config.h"
#include <yaml-cpp/yaml.h>
#include <fstream>
#include <algorithm>

namespace philote {

ServerConfig ServerConfig::LoadFromFile(const std::string& filepath) {
    ServerConfig config;

    try {
        // Load YAML file
        YAML::Node yaml = YAML::LoadFile(filepath);

        // Parse discipline section
        if (!yaml["discipline"]) {
            throw ConfigException("Missing 'discipline' section");
        }

        YAML::Node discipline = yaml["discipline"];

        // Parse discipline kind
        if (!discipline["kind"]) {
            throw ConfigException("Missing 'discipline.kind'");
        }
        std::string kind_str = discipline["kind"].as<std::string>();
        std::transform(kind_str.begin(), kind_str.end(), kind_str.begin(), ::tolower);

        if (kind_str == "explicit") {
            config.discipline_kind = DisciplineKind::Explicit;
        } else if (kind_str == "implicit") {
            config.discipline_kind = DisciplineKind::Implicit;
        } else {
            throw ConfigException("Invalid discipline.kind: '" + kind_str +
                                "'. Must be 'explicit' or 'implicit'");
        }

        // Parse julia_file
        if (!discipline["julia_file"]) {
            throw ConfigException("Missing 'discipline.julia_file'");
        }
        config.julia_file = discipline["julia_file"].as<std::string>();

        // Parse julia_type
        if (!discipline["julia_type"]) {
            throw ConfigException("Missing 'discipline.julia_type'");
        }
        config.julia_type = discipline["julia_type"].as<std::string>();

        // Parse server section
        if (!yaml["server"]) {
            throw ConfigException("Missing 'server' section");
        }

        YAML::Node server = yaml["server"];

        // Parse server address
        if (!server["address"]) {
            throw ConfigException("Missing 'server.address'");
        }
        config.server_address = server["address"].as<std::string>();

        // Validate configuration
        config.Validate();

        return config;

    } catch (const YAML::Exception& e) {
        throw ConfigException("YAML parsing error: " + std::string(e.what()));
    } catch (const ConfigException& e) {
        throw;  // Re-throw our own exceptions
    } catch (const std::exception& e) {
        throw ConfigException("Error loading config: " + std::string(e.what()));
    }
}

void ServerConfig::Validate() const {
    // Validate julia_file is not empty
    if (julia_file.empty()) {
        throw ConfigException("discipline.julia_file cannot be empty");
    }

    // Validate julia_type is not empty
    if (julia_type.empty()) {
        throw ConfigException("discipline.julia_type cannot be empty");
    }

    // Validate server_address is not empty
    if (server_address.empty()) {
        throw ConfigException("server.address cannot be empty");
    }

    // Basic validation of address format (should contain host:port)
    if (server_address.find(':') == std::string::npos) {
        throw ConfigException("server.address must be in format 'host:port'");
    }
}

} // namespace philote
