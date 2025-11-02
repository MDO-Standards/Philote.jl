# gRPC Package Research for Pure Julia Philote

## Date: 2025-01-02

## Research Question
Which gRPC package should be used for implementing pure Julia Philote with server and client capabilities?

## Findings

### Julia gRPC Ecosystem Status

1. **gRPCClient.jl** (Official, JuliaComputing)
   - **Status**: Active, maintained
   - **Capabilities**: CLIENT ONLY
   - **Pros**: Official, well-maintained, works with ProtoBuf.jl
   - **Cons**: No server implementation
   - **Use case**: Can call remote gRPC services (e.g., Python/C++ Philote servers)

2. **gRPC.jl** (tanmaykm/gRPC.jl)
   - **Status**: ABANDONED, removed from package registry
   - **Capabilities**: Intended full stack (client + server)
   - **Cons**: Dependencies abandoned, not installable
   - **Verdict**: NOT VIABLE

3. **HTTP2.jl** (sorpaas/HTTP2.jl)
   - **Status**: Unmaintained (last update: years ago)
   - **Capabilities**: Low-level HTTP/2 support
   - **Cons**: Outdated, incomplete
   - **Verdict**: NOT VIABLE for building gRPC server

### Alternative Approaches

#### Option A: PyCall Wrapper Around Python grpcio
**Pros:**
- Leverages mature Python grpcio (client + server)
- Proven to work (Python interop is solid)
- Quick implementation

**Cons:**
- Adds Python as a runtime dependency
- Performance overhead from Julia ↔ Python calls
- Defeats the "pure Julia" goal
- Complex to debug across language boundary

#### Option B: Build Custom gRPC Server
**Approach:** Implement gRPC server using HTTP.jl + ProtoBuf.jl manually

**Pros:**
- Pure Julia solution
- Full control over implementation
- Could contribute to Julia ecosystem

**Cons:**
- **Significant development effort** (weeks/months)
- Need to implement:
  - HTTP/2 framing
  - gRPC protocol details
  - Streaming support
  - Error handling
  - Connection management
- Maintenance burden
- May have bugs/edge cases
- Not the core goal of Philote project

#### Option 3: Hybrid Approach - Adjust Project Scope
**Proposal:** Rethink what "pure Julia" means for Philote

1. **Keep core disciplines pure Julia** (already done ✓)
2. **Implement Julia gRPC client** using gRPCClient.jl
   - Call remote Philote servers (C++/Python)
3. **For serving Julia disciplines:**
   - **Short term**: Keep C++ wrapper (it works!)
   - **Medium term**: Use PyCall + grpcio
   - **Long term**: Contribute to Julia gRPC server development

**Pros:**
- Pragmatic, achievable now
- Julia users get:
  - Native discipline development (zero overhead)
  - Ability to call remote disciplines (via gRPCClient.jl)
- Can serve Julia disciplines via existing C++ server
- Incremental path forward

**Cons:**
- Still has C++ dependency for serving
- Not "pure Julia" server

## Recommendation

Given the current Julia ecosystem limitations, I recommend **Option C: Hybrid Approach** with this specific plan:

### Phase 1: Pure Julia Core + Client (Immediate Value)
1. Keep existing pure Julia discipline interface (src/Philote.jl)
2. Implement Julia gRPC **client** using gRPCClient.jl
3. Julia users can:
   - Write disciplines in pure Julia (local, zero overhead)
   - Call remote Philote disciplines (C++/Python servers)
   - Compose hybrid workflows

### Phase 2: Server Options (User Choice)
Provide multiple server options, let users choose:

**Option A: C++ Server** (existing, proven)
- Use current Philote-Cpp with Julia embedding
- Pros: Works today, battle-tested
- Cons: Requires C++ toolchain

**Option B: Python Server** (via PyCall)
- Wrap Python grpcio server, call Julia from Python
- Pros: Pure Julia + Python (no C++ needed)
- Cons: Python dependency

**Option C: Future Pure Julia Server**
- When Julia gRPC server matures, migrate to it
- Keep an eye on Julia ecosystem development

### Benefits of This Approach
- ✅ Achievable now with existing Julia packages
- ✅ Provides immediate value (client functionality)
- ✅ Pure Julia for core disciplines (main benefit)
- ✅ Pragmatic about server realities
- ✅ Incremental path to full pure Julia when ecosystem matures
- ✅ Doesn't block on implementing a gRPC server from scratch

## Next Steps

**If we proceed with Hybrid Approach:**
1. Install and test gRPCClient.jl
2. Generate Julia proto files from Philote .proto files
3. Implement DisciplineClient, ExplicitClient, ImplicitClient
4. Test Julia client against existing C++/Python servers
5. Document how to serve Julia disciplines (via C++ or PyCall)
6. Create examples showing hybrid workflows

**Estimated Timeline:** 1-2 weeks (vs. months for custom server)

## Question for User

Do you want to:
1. **Proceed with Hybrid Approach** (Julia client + existing C++/Python server options)?
2. **Implement custom gRPC server** (pure Julia but significant effort)?
3. **Use PyCall wrapper** (Julia + Python, no C++)?
4. **Wait for Julia ecosystem** (delay project until gRPC server exists)?

My recommendation is Option 1 (Hybrid) as it provides immediate value while staying true to the goal of pure Julia disciplines.
