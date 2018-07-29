# Flatten

[![Build Status](https://travis-ci.org/rafaqz/Flatten.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Flatten.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/dpf055yo50y21g1v?svg=true)](https://ci.appveyor.com/project/rafaqz/flatten-jl)
[![codecov.io](http://codecov.io/github/rafaqz/Cellular.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/Cellular.jl?branch=master)

Flatten.jl converts data between nested and flat structures, using `flatten()`
and `reconstruct()` functions. This facilitates building modular, compostable code
while still providing access to differentiation, solvers and optimisers that
require flat vectors of parameters. Importantly it's also fast and type-stable.


Flatten.jl uses [MetaField.jl](https://github.com/rafaqz/MetaFields.jl) to provide
`@flattenable` macro to define which struct fields are to be flattened. It also
provides `metaflatten()` to flatten any other MetaFiels.jl metafields into the same sized
vector as `flatten()`. This can be useful for attaching Bayesian priors or optional
units to each field. Pseudo-metafileds `fieldname_meta`, `fieldparent_meta`, `fieltype_meta`
and `fielparenttype_meta` provide lists of fieldnames and types that may be useful for building parameter display
tables. Any user-defined funciton of the form `func(::T, ::Type{Val{FN}}) = ` can be used in `metaflatten`,
where T is the struct type and FN is the fieldname symbol.

Flatten.jl also has optional support for Unitful.jl units: they are stripped from the
vector, and added back on reconstruction if `using Unitful` has been called.


This basis of this package was originally written by Robin Deits (@rdeits). The current form
owes much to discussions and ideas from Jan Weidner (@jw3126) and Robin Deits. 


## Examples

Let's define a data type:

```julia
julia> 
type Foo{T}
   a::T
   b::T
   c::T
end

julia> f = Foo(1,2,3)
Foo{Int64}(1,2,3)
```

Now we can flatten this data type into a tuple:

```julia
julia> flatten(Tuple, f)
(1, 2, 3)
```

or a vector:

```julia
julia> flatten(Vector, f)
3-element Array{Int64,1}:
 1
 2
 3
```

We can also reconstruct the data to recover the original structure.
`construct()` rebuilds from a type and tuple containing values for every field.

```julia
julia> construct(Foo{Int64}, (1,2,3))
Foo{Int64}(1,2,3)
```

`reconstruct()` rebuilds from an object and a partial tuple or vector, useful
when some fields have been deactivated with the @flattenable macro.

```julia
julia> construct(foo, (1, 2, 3))
Foo{Int64}(1, 2, 3)
```

Nested types work too:

```julia
type Nested{T1, T2}
    f::Foo{T1}
    b::T2
    c::T2
end

julia> n = Nested(Foo(1,2,3), 4.0, 5.0)
Nested{Int64,Float64}(Foo{Int64}(1,2,3),4.0,5.0)

julia> flatten(Tuple, n)
(1, 2, 3, 4.0, 5.0)

julia> flatten(Vector, n)
5-element Array{Float64,1}:
 1.0
 2.0
 3.0
 4.0
 5.0

julia> construct(Nested{Int64,Int64}, (1, 2, 3, 4, 5))

Nested{Int64,Int64}(Foo{Int64}(1, 2, 3), 4, 5)
```

Fields can be excluded from flattening with the `flattenable(struct, field)` method,
easily defined using @flattenable on a struct.


```julia
using Metafields
using Flatten 
import Flatten: flattenable

@metafield foobar :nobar

@flattenable @foobar struct Partial{T}
    a::T | :foo | Flat()
    b::T | :foo | Flat()
    c::T | :foo | NotFlat()
end

@flattenable @foobar struct NestedPartial{P,T}
    np::P | :bar | Flat()
    nb::T | :bar | Flat()
    nc::T | :bar | NotFlat()
end

julia> partial = Partial(1.0, 2.0, 3.0)                                      
Partial{Float64}(1.0, 2.0, 3.0)                                              
                                                                             
julia> nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5)           
NestedPartial{Partial{Float64},Int64}(Partial{Float64}(1.0, 2.0, 3.0), 4, 5) 

julia> flatten(Tuple, nestedpartial)
(1.0, 2.0, 4)

julia> flatten(Vector, nestedpartial)
5-element Array{Float64,1}:
 1.0
 2.0
 4.0
```

We can also flatten the @foobar metafield defined above:

```julia
julia> metaflatten(typeof(partial), foobar) 
(:foo, :foo)

julia> metaflatten(nestedpartial, foobar)
(:foo, :foo, :bar)
```

And flatten the fieldnames by passing in the fieldname_meta function:
```julia
julia> metaflatten(nestedpartial, fieldname_meta)                                            
(:a, :b, :nb) 
```
