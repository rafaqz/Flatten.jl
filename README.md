# Flatten

[![Build Status](https://travis-ci.org/rdeits/Flatten.jl.svg?branch=master)](https://travis-ci.org/rdeits/Flatten.jl)

Flatten Julia types to tuples or vectors, and restore them later.

# Why?

Let's say you have a function that takes structured data (i.e. data defined by a Julia type). You may want to interface with external tools, like optimization solvers, which expect to operate only on flat vectors of numbers. Rather than writing code yourself to pack or unpack your particular data into vectors, you can just use Flatten.jl to automatically handle all the conversions.

## Example

Let's define a data type:

```julia
julia> type Foo{T}
       a::T
       b::T
       c::T
       end

julia> f = Foo(1,2,3)
Foo{Int64}(1,2,3)
```

Now we can flatten this data type into a tuple:

```julia
julia> to_tuple(f)
(1,2,3)
```

or a vector:

```julia
julia> to_vector(f)
3-element Array{Int64,1}:
 1
 2
 3
```

We can also unflatten the data to recover the original structure:

```julia
julia> from_tuple(Foo, (1,2,3))
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

julia> to_tuple(n)
(1,2,3,4.0,5.0)

julia> to_vector(n)
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
 julia> from_tuple(Nested, (1,2,3,4,5))
Nested{Int64,Int64}(Foo{Int64}(1,2,3),4,5)
```

Tuples of nested types work too:

```julia
julia> to_tuple((Nested(Foo(1,2,3),4,5), Nested(Foo(6,7,8),9,10)))
(1,2,3,4,5,6,7,8,9,10)

julia> from_tuple(Tuple{Nested, Nested}, (1,2,3,4,5,6,7,8,9,10))
(Nested{Int64,Int64}(Foo{Int64}(1,2,3),4,5),Nested{Int64,Int64}(Foo{Int64}(6,7,8),9,10))
```

# How? 

Flatten.jl uses Julia's [generated functions](http://docs.julialang.org/en/release-0.4/manual/metaprogramming/#generated-functions) to generate efficient code for your particular data types, which can be 10 to 100 times faster than naively packing and unpacking data. You can look at the generated expressions for a particular type:

```julia
julia> Flatten.to_tuple_internal(typeof(Foo(1,2,3)))
:((T.a,T.b,T.c))

julia> Flatten.to_vector_internal(typeof(Foo(1,2,3)))
quote  # /Users/rdeits/.julia/Flatten/src/Flatten.jl, line 64:
    v = Array{Int64}(3)
    v[1] = T.a
    v[2] = T.b
    v[3] = T.c
    v
end

julia> Flatten.from_tuple_internal(Nested, (1,2,3,4,5))
:((Nested{T1,T2})((Foo{T1})(data[1],data[2],data[3]),data[4],data[5]))
```
