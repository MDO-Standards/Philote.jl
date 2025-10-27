#ifndef PHILOTE_JULIA_CONFIG_H
#define PHILOTE_JULIA_CONFIG_H

#include <string>
#include <stdexcept>

namespace philote {

/**
 * @brief Type of discipline to load
 */
enum class DisciplineKind {
    Explicit,
    Implicit
};

/**
 * @brief Server configuration loaded from YAML file
 *
 * Example YAML:
 * ```yaml
 * discipline:
 *   kind: explicit
 *   julia_file: examples/paraboloid.jl
 *   julia_type: ParaboloidDiscipline
 *
 * server:
 *   address: localhost:50051
 * ```
 */
struct ServerConfig {
    // Discipline configuration
    DisciplineKind discipline_kind;
    std::string julia_file;
    std::string julia_type;

    // Server configuration
    std::string server_address;

    /**
     * @brief Load configuration from YAML file
     *
     * @param filepath Path to YAML configuration file
     * @return ServerConfig parsed configuration
     * @throws std::runtime_error if file cannot be read or parsed
     */
    static ServerConfig LoadFromFile(const std::string& filepath);

    /**
     * @brief Validate configuration
     *
     * @throws std::runtime_error if configuration is invalid
     */
    void Validate() const;
};

/**
 * @brief Exception thrown for configuration errors
 */
class ConfigException : public std::runtime_error {
public:
    explicit ConfigException(const std::string& msg)
        : std::runtime_error("Configuration error: " + msg) {}
};

} // namespace philote

#endif // PHILOTE_JULIA_CONFIG_H
