# Flatten

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/Flatten.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/Flatten.jl/dev)
[![Build Status](https://travis-ci.org/rafaqz/Flatten.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Flatten.jl)
[![codecov.io](http://codecov.io/github/rafaqz/Flatten.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/Flatten.jl?branch=master)
[![Coverage Status](https://coveralls.io/repos/rafaqz/Flatten.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/Flatten.jl?branch=master)

Flatten.jl converts data from arbitrary nested structs to tuples, using
`flatten()`, `reconstruct()`, `update!()` and `modify()` functions. This
facilitates building modular, composable structs while allowing access to
solvers and optimisers that require flat lists of parameters. Importantly it's
type-stable and _very_ fast. It is not intended for use with arrays, as we do
not know their length at compile time. But you can easily splat the output Tuple
into a vector.

Flatten is also flexible. The types to return and ignore can be specified, and
individual fields can be ignored using field-level traits like `flattenable`
from FieldMetadata.jl. Method overrides can also be defined for custom types.

## Type queries

Flatten allows a kind of querying to extract some types and ignore others,
here using `flatten`:

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> struct Bar{X}
           x::X
       end

julia> obj = Foo(1, :two, Foo(Bar(3), 4.0, 5.0f0));

julia> use = Union{Int, Float32}; # Return Int and Float32 fields

julia> ignore = Bar;              # Dont return Bar or iterate over Bar fields

julia> flatten(obj, use, ignore)  # `flatten` all Int and Float32 except fields of Bar
(1, 5.0f0)

julia> modify(string, obj, Int)   # `modify`: convert all Int to String
Foo{String,Symbol,Foo{Bar{String},Float64,Float32}}("1", :two, Foo{Bar{String},Float64,Float32}(Bar{String}("3"), 4.0, 5.0f0))
```

The default type used is `Real`. These rules also apply in `reconstruct`,
`update!` and `modify`.

## Field removal

There are often cases where you want to ignore certain fields that have the same
type as the fields you want to extract. Flatten.jl also
[FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl) to provide
`@flattenable` macro and methods, allowing you to choose fields to include and
remove from flattening. The default is `true` for all fields.

```jldoctest
using Flatten
import Flatten: flattenable

@flattenable struct Bar{X,Y}
    x::X | true
    y::Y | false
end

flatten(Bar(1, 2))

# output
(1,)
```
Custom `@metadata` methods from FieldMetadata can be used, if they return a Bool.
You can also use custom functions that follow the following form, returning a boolean:

```julia
f(::Type, ::Type{Var{:fieldname}}) = false
```

# Metatdata flattening

Flatten also provides `metaflatten()` to flatten any FieldMetadata.jl
metadata for the same fields `flatten()` returns. This can be useful for attaching
information like descriptions or prior probability distributions to each field.
Regular field data can also be collected with convenience versions of metaflatten:
`fieldnameflatten`, `parentflatten`, `fieldtypeflatten` and `parenttypeflatten`
functions provide lists of fieldnames and types that may be useful for building
parameter display tables.


This package was started by Robin Deits (@rdeits), and its early development
owes much to discussions and ideas from Jan Weidner (@jw3126) and Robin Deits.
"""

# Flattening StaticArrays

`SArray` and other objects from StaticArrays.jl can not be constructed from their fields. 
Dealing with this in the long term will require either a dependency on ConstructionBase.jl
in StaticArrays.jl, or a glue package that provides the required `constructorof` methods,
which for now you can define manually:

```julia
using StaticArrays, ConstructionBase, Flatten

struct SArrayConstructor{S,N,L} end
(::SArrayConstructor{S,N,L})(data::NTuple{L,T}) where {S,T,N,L} = SArray{S,T,N,L}(data)

ConstructionBase.constructorof(sa::Type{<:SArray{S,<:Any,N,L}}) where {S,N,L} = 
    SArrayConstructor{S,N,L}()
```    
