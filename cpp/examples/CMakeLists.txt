# Examples CMakeLists.txt

# ============================================================================
# Generic Julia Server (YAML-based configuration)
# ============================================================================

add_executable(philote_julia_server
    philote_julia_server.cpp
)

target_link_libraries(philote_julia_server
    PhiloteJulia
    gRPC::grpc++
    protobuf::libprotobuf
    yaml-cpp::yaml-cpp
)

set_target_properties(philote_julia_server
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS philote_julia_server
    RUNTIME DESTINATION bin
)

# ============================================================================
# Legacy Example: Hardcoded Paraboloid Server
# ============================================================================

add_executable(paraboloid_server
    paraboloid_server.cpp
)

target_link_libraries(paraboloid_server
    PhiloteJulia
    gRPC::grpc++
    protobuf::libprotobuf
)

set_target_properties(paraboloid_server
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS paraboloid_server
    RUNTIME DESTINATION bin
)

# ============================================================================
# Install Configuration Files
# ============================================================================

install(DIRECTORY configs
    DESTINATION share/philote-julia/examples
)
