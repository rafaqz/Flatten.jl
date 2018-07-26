# Flatten

[![Build Status](https://travis-ci.org/rafaqz/Flatten.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Flatten.jl)

This is a fork of rdeits original package, with a number of name
simplifications.

It also adds some features, making this package even more magical and 
weird than it already was.

First it adds support for Unitful.jl units: they are stripped from the vector, and added
back on reconstruction. 

It also adds [MetaField.jl](https://github.com/rafaqz/MetaFields.jl) compatibility via
[Flattenable.jl](https://github.com/rafaqz/Flattenable.jl) to optionally exclude
certain fields. This requires using `reconstruct()` instead of `construct()` and
passing in data instead of a type --- the fields excluded with `@flattenable
false` are taken from the original data. 

TODO: Properly document changes.

---

Flatten Julia types to tuples or vectors, and restore them later. Think of it as
a primitive form of serialization, in which the serialized data is a meaningful
list of numbers, rather than an arbitrary string of bytes. 


# Why?

Let's say you have a function that takes structured data (i.e. data defined by a
Julia type). You may want to interface with external tools, like optimization
solvers, which expect to operate only on flat vectors of numbers. Rather than
writing code yourself to pack or unpack your particular data into vectors, you
can just use Flatten.jl to automatically handle all the conversions.

# Is this a good idea?

Uh...I'm not sure. Possibly not. Use at your own risk. 

## Example

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
(1,2,3)
```

or a vector:

```julia
julia> flatten(Vector, f)
3-element Array{Int64,1}:
 1
 2
 3
```

We can also unflatten the data to recover the original structure:

```julia
julia> construct(Foo{Int64}, (1,2,3))
Foo{Int64}(1,2,3)
```

Things start getting more magical when we introduce nested types:

```
julia> type Nested{T1, T2}
           f::Foo{T1}
           b::T2
           c::T2
       end

julia> n = Nested(Foo(1,2,3), 4.0, 5.0)
Nested{Int64,Float64}(Foo{Int64}(1,2,3),4.0,5.0)

julia> flatten(Tuple, n)
(1,2,3,4.0,5.0)

julia> flatten(Vector, n)
5-element Array{Float64,1}:
 1.0
 2.0
 3.0
 4.0
 5.0
```

Note that to_vector has automatically promoted all elements to `Float64`, since the original type had a mixture of `Float64` and `Int64`.

We can also recover nested types from flat data:

```julia
 julia> construct(Nested{Int64,Int64}, (1,2,3,4,5))
Nested{Int64,Int64}(Foo{Int64}(1,2,3),4,5)
```

Tuples of nested types work too:

```julia
julia> flatten(Tuple, (Nested(Foo(1,2,3),4,5), Nested(Foo(6,7,8),9,10)))
(1,2,3,4,5,6,7,8,9,10)

julia> construct(Tuple{Nested{Int64,Int64}, Nested{Int64,Int64}}, (1,2,3,4,5,6,7,8,9,10))
(Nested{Int64,Int64}(Foo{Int64}(1,2,3),4,5),Nested{Int64,Int64}(Foo{Int64}(6,7,8),9,10))
```

With this fork you can also exclude fields. The magic gets almost incomprehensible at this point. 

```
using Flattenable
import Flattenable: flattenable
type Foo{T}
   a::T
   b::T
   c::T
end

@flattenable struct Partial{T1, T2}
           f::Foo{T1} | true
           b::T2      | true
           c::T2      | false
       end

# This must be declared *after* all flattenable macros have run:
using Flatten 

julia> 
n = Partial(Foo(1,2,3), 4.0, 5.0)
Partial{Int64,Float64}(Foo{Int64}(1, 2,3),4.0,5.0)

julia> flatten(Tuple, n)
(1,2,3,4.0)

julia> flatten(Vector, n)
5-element Array{Float64,1}:
 1.0
 2.0
 3.0
 4.0
```


# How? 

Flatten.jl uses Julia's [generated functions](http://docs.julialang.org/en/release-0.4/manual/metaprogramming/#generated-functions) to generate efficient code for your particular data types, which can be 10 to 100 times faster than naively packing and unpacking data. You can look at the generated expressions for a particular type:
