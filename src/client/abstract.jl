# Abstract types for Philote gRPC clients

"""
    AbstractDisciplineClient

Abstract base type for all Philote discipline clients.

All discipline clients (explicit and implicit) inherit from this type.
"""
abstract type AbstractDisciplineClient end

"""
    AbstractExplicitClient <: AbstractDisciplineClient

Abstract type for explicit discipline clients.

Explicit disciplines compute outputs directly from inputs: `outputs = f(inputs)`
"""
abstract type AbstractExplicitClient <: AbstractDisciplineClient end

"""
    AbstractImplicitClient <: AbstractDisciplineClient

Abstract type for implicit discipline clients.

Implicit disciplines solve residual equations: `R(inputs, outputs) = 0`
"""
abstract type AbstractImplicitClient <: AbstractDisciplineClient end
