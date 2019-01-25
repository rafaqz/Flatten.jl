# Flatten

[![Build Status](https://travis-ci.org/rafaqz/Flatten.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Flatten.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/dpf055yo50y21g1v?svg=true)](https://ci.appveyor.com/project/rafaqz/flatten-jl)
[![codecov.io](http://codecov.io/github/rafaqz/Flatten.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/Flatten.jl?branch=master)
[![Coverage Status](https://coveralls.io/repos/rafaqz/Flatten.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/Flatten.jl?branch=master)

Flatten.jl converts data between nested and flat structures, using `flatten()`,
`reconstruct()` and `retype()` functions. This facilitates building modular,
compostable code while still providing access to differentiation, solvers and
optimisers that require flat vectors of parameters. Importantly it's also type-stable 
and _very_ fast.

Flatten.jl uses [FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl)
to provide `@flattenable` macro to indicate which struct fields are to be
flattened, defaulting to `true` for all fields. It also provides `metaflatten()`
to flatten any other FieldMetadata.jl meta-fields into the same sized vector as
`flatten()`. This can be useful for attaching Bayesian priors or optional units
to each field. Regular field data can also be collected with metaflatten:
`fieldnameflatten`, `parentflatten`, `fieldtypeflatten` and `parenttypeflatten`
provide lists of fieldnames and types that may be useful for building parameter
display tables. Any user-defined function of the form `func(::T,
::Type{Val{fn}}) = ` can be used in `metaflatten`, where T is the struct type
and fn is the fieldname symbol.

One limitation of `reconstruct` is that it requires an outer constructor that
accept all fields in the order they come in the type. If some fields are
recalculated at construction time, they should be calculated in this
constructor. 

[UnitlessFlatten.jl](https://github.com/rafaqz/UnitlessFlatten.jl) extends
Flatten.jl to automatically strip and add Unitful units.

This basis of this package was originally written by Robin Deits (@rdeits). The current form
owes much to discussions and ideas from Jan Weidner (@jw3126) and Robin Deits. 


## Basic struct flattening

Let's define a data type:

```julia
struct Foo{T}
   a::T
   b::T
   c::T
end

julia> foo = Foo(1,2,3)
Foo{Int64}(1,2,3)
```

Now we can flatten this data type into a tuple:

```julia
julia> flatten(Tuple, foo)
(1, 2, 3)
```

or a vector:

```julia
julia> flatten(Vector, foo)
3-element Array{Int64,1}:
 1
 2
 3
```

We can also reconstruct the data to recover the original structure.

`reconstruct()` rebuilds from an object and a partial tuple or vector, useful
when some fields have been deactivated with the `@flattenable` macro.

```julia

julia> reconstruct(foo, (1, 2, 3))
Foo{Int64}(1, 2, 3)
```

Nested types work too:

```julia
struct Nested{T1, T2}
    f::Foo{T1}
    b::T2
    c::T2
end

julia> nested = Nested(Foo(1,2,3), 4.0, 5.0)
Nested{Int64,Float64}(Foo{Int64}(1,2,3),4.0,5.0)

julia> flatten(Tuple, nested)
(1, 2, 3, 4.0, 5.0)

julia> flatten(Vector, nested)
5-element Array{Float64,1}:
 1.0
 2.0
 3.0
 4.0
 5.0

julia> reconstruct(nested, (1, 2, 3, 4, 5))
Nested{Int64,Float64}(Foo{Int64}(1, 2, 3), 4, 5)
```

Reconstruct returns the same type as the original. If you want a new struct
matching the passed in values, use `retype`.

```
julia> retype(nested, (1, 2, 3, 4, 5))
Nested{Int64,Int64}(Foo{Int64}(1, 2, 3), 4, 5)
```

## Updating mutable structs

If we want to update mutable structs in place, you can use `update!`:

```julia
mutable struct MutableFoo1{T}
   a::T
   b::T
   c::T
end

julia> mufoo = MutableFoo(1,2,3)
MuFoo{Int64}(1,2,3)

julia> update!(mufoo, (2,4,6))
MutableFoo{Int64}(2, 4, 6)
```

## Stripping units

An array of floats is a most common input for optimisers
and other numerical tools, and unitful parameters can make this tricky.

Loading [Unitful.jl](https://github.com/ajkeller34/Unitful.jl),
`ulflatten()`, `ulreconstruct()` and `ulretype()` will be available for
unit-less flattening. This greatly improves the speed of flattening unitful
structs to Vector and reconstructing them, as it will be type stable. It then
allows reconstructing the vector back to the same unit types given a Vector of
floats. 


## Excluding fields from flattening


Fields can be excluded from flattening with the `flattenable(struct, field)`
method, easily defined using `@flattenable` from
[FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl). I'll
also define a `@foobar` metadata to use later:


```julia
using FieldMetadata
using Flatten 
import Flatten: flattenable

@metadata foobar :nobar

@flattenable @foobar struct Partial{A,B,C}
    a::A | :foo | true
    b::B | :foo | true
    c::C | :foo | false
end

@flattenable @foobar struct NestedPartial{P,A,B}
    np::P | :bar | true
    nb::A | :bar | true
    nc::B | :bar | false
end

julia> nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5)
NestedPartial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)

julia> nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5)
NestedPartial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)

julia> flatten(Tuple, nestedpartial)
(1.0, 2.0, 4)

julia> flatten(Vector, nestedpartial)
5-element Array{Float64,1}:
 1.0
 2.0
 4.0
```

Of course, `reconstruct` and `retype` and `update!` also respect `flattenable` fields: 

```
julia> reconstruct(nestedpartial, (1, 2, 4.0))
NestedPartial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)

julia> retype(nestedpartial, (1, 2, 4.0))
NestedPartial{Partial{Int64,Float64,Float64},Float64,Int64}(Partial{Int64,Float64,Float64}(1, 2.0, 3.0), 4.0, 5)
```

*Note: use Tuples of parameters when using mixed types. Vectors of mixed
type will not be type-stable, and Flatten.jl methods will be slow.*


## Meta flattening

We can also flatten the @foobar metadata defined earlier:

```julia
julia> metaflatten(partial, foobar) 
(:foo, :foo)

julia> metaflatten(nestedpartial, foobar)
(:foo, :foo, :bar)
```


Or flatten the fieldnames:
```julia
julia> fieldnameflatten(nestedpartial)                                            
(:a, :b, :nb) 
```
