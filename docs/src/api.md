# API Reference

Complete API documentation for Philote.jl.

## Abstract Types

```@docs
Philote.AbstractDiscipline
Philote.ExplicitDiscipline
Philote.ImplicitDiscipline
```

## Metadata

```@docs
Philote.DisciplineMetadata
Philote.get_metadata
```

## Setup Functions

These functions are used within `setup!()` to declare the discipline interface.

```@docs
Philote.add_input!
Philote.add_output!
Philote.add_residual!
Philote.add_option!
Philote.declare_partials!
```

## Discipline Methods

These are the core methods you implement for your discipline.

### Required for All Disciplines

```@docs
Philote.setup!
```

### Explicit Disciplines

```@docs
Philote.compute
Philote.compute_partials
```

### Implicit Disciplines

```@docs
Philote.compute_residuals
Philote.solve_residuals
Philote.residual_partials
```

### Optional Methods

```@docs
Philote.set_options!
```

## Index

```@index
```
