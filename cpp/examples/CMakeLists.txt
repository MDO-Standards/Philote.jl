# Examples CMakeLists.txt

add_executable(paraboloid_server
    paraboloid_server.cpp
)

target_link_libraries(paraboloid_server
    PhiloteJulia
    PhiloteCpp
    gRPC::grpc++
    protobuf::libprotobuf
)

# Set output directory
set_target_properties(paraboloid_server
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Installation
install(TARGETS paraboloid_server
    RUNTIME DESTINATION bin
)
