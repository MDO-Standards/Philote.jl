# gRPC Service Client Generators for Philote
# These create gRPC clients for the Philote discipline services

using gRPCClient2
using ..PhiloteProto
using ..PhiloteProto.google.protobuf: Empty

# DisciplineService clients

"""
    DisciplineService_GetInfo_Client(host, port; kwargs...)

Create a gRPC client for the GetInfo RPC of DisciplineService.
Returns discipline properties.
"""
function DisciplineService_GetInfo_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{Empty, false, DisciplineProperties, false}(
        host, port, "/philote.DisciplineService/GetInfo";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_SetStreamOptions_Client(host, port; kwargs...)

Create a gRPC client for the SetStreamOptions RPC of DisciplineService.
"""
function DisciplineService_SetStreamOptions_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{StreamOptions, false, Empty, false}(
        host, port, "/philote.DisciplineService/SetStreamOptions";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_GetAvailableOptions_Client(host, port; kwargs...)

Create a gRPC client for the GetAvailableOptions RPC of DisciplineService.
"""
function DisciplineService_GetAvailableOptions_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{Empty, false, OptionsList, false}(
        host, port, "/philote.DisciplineService/GetAvailableOptions";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_SetOptions_Client(host, port; kwargs...)

Create a gRPC client for the SetOptions RPC of DisciplineService.
"""
function DisciplineService_SetOptions_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{DisciplineOptions, false, Empty, false}(
        host, port, "/philote.DisciplineService/SetOptions";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_Setup_Client(host, port; kwargs...)

Create a gRPC client for the Setup RPC of DisciplineService.
"""
function DisciplineService_Setup_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{Empty, false, Empty, false}(
        host, port, "/philote.DisciplineService/Setup";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_GetVariableDefinitions_Client(host, port; kwargs...)

Create a gRPC client for the GetVariableDefinitions RPC (server streaming).
"""
function DisciplineService_GetVariableDefinitions_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{Empty, false, VariableMetaData, true}(
        host, port, "/philote.DisciplineService/GetVariableDefinitions";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    DisciplineService_GetPartialDefinitions_Client(host, port; kwargs...)

Create a gRPC client for the GetPartialDefinitions RPC (server streaming).
"""
function DisciplineService_GetPartialDefinitions_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{Empty, false, PartialsMetaData, true}(
        host, port, "/philote.DisciplineService/GetPartialDefinitions";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

# ExplicitService clients

"""
    ExplicitService_ComputeFunction_Client(host, port; kwargs...)

Create a gRPC client for the ComputeFunction RPC (bidirectional streaming).
"""
function ExplicitService_ComputeFunction_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{PhiloteProto.philote.var"#Array", true, PhiloteProto.philote.var"#Array", true}(
        host, port, "/philote.ExplicitService/ComputeFunction";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    ExplicitService_ComputeGradient_Client(host, port; kwargs...)

Create a gRPC client for the ComputeGradient RPC (bidirectional streaming).
"""
function ExplicitService_ComputeGradient_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{PhiloteProto.philote.var"#Array", true, PhiloteProto.philote.var"#Array", true}(
        host, port, "/philote.ExplicitService/ComputeGradient";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

# ImplicitService clients

"""
    ImplicitService_ComputeResiduals_Client(host, port; kwargs...)

Create a gRPC client for the ComputeResiduals RPC (bidirectional streaming).
"""
function ImplicitService_ComputeResiduals_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{PhiloteProto.philote.var"#Array", true, PhiloteProto.philote.var"#Array", true}(
        host, port, "/philote.ImplicitService/ComputeResiduals";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    ImplicitService_SolveResiduals_Client(host, port; kwargs...)

Create a gRPC client for the SolveResiduals RPC (bidirectional streaming).
"""
function ImplicitService_SolveResiduals_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{PhiloteProto.philote.var"#Array", true, PhiloteProto.philote.var"#Array", true}(
        host, port, "/philote.ImplicitService/SolveResiduals";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end

"""
    ImplicitService_ComputeResidualGradients_Client(host, port; kwargs...)

Create a gRPC client for the ComputeResidualGradients RPC (bidirectional streaming).
"""
function ImplicitService_ComputeResidualGradients_Client(
    host, port;
    secure=false,
    grpc=grpc_global_handle(),
    deadline=10,
    keepalive=60,
    max_send_message_length=4*1024*1024,
    max_recieve_message_length=4*1024*1024,
)
    return gRPCClient{PhiloteProto.philote.var"#Array", true, PhiloteProto.philote.var"#Array", true}(
        host, port, "/philote.ImplicitService/ComputeResidualGradients";
        secure=secure,
        grpc=grpc,
        deadline=deadline,
        keepalive=keepalive,
        max_send_message_length=max_send_message_length,
        max_recieve_message_length=max_recieve_message_length,
    )
end
