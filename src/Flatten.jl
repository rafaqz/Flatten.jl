"""
Flatten.jl converts data between nested and flat structures, using `flatten()`,
`reconstruct()` and `update!()` functions. This facilitates building modular,
composed structs while allowing access to solvers and optimisers that require flat
tyuples of parameters, or any other use case that requires extraction of a flat list
of values from a nested type. Importantly it's type-stable and _very_ fast. 


Flatten is also flexible. Overrides can be defined for custom types for all methods, while 
custom querying methods and types can be used to extract and modify specify sets of fields
from any nested type. Flatten allows 'querying' to extract some types and ignore others, 
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

julia> use = Union{Int, Float32}; # Immediately return Int and AbstractFloat fields

julia> ignore = Bar;  # Dont return or iterate over AbstractArray fields

julia> flatten(obj, use, ignore) # Flatten all Int and Float32 except fields of Bar
(1, 5.0f0)

julia> flatten(Foo(:one, :two, Foo(Bar(:three), 4.0, :five)), Symbol, Bar) # Return all symbols, except in Bar
(:one, :two, :five)
```

The default type used is `Number`, while `AbstractArray` is ignored. These rules apply 
to all Flatten.jl functions.

Flatten.jl also uses [FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl)
to provide `@flattenable` macro choose struct fields to include and remove from
flattened, defaulting to `true` for all fields. Custom `@metadata` methods from
FieldMetadata can be used, if they return a Bool. You can also use cusom
functions that follow the following form, returning a boolean:

```julia
f(::Type, ::Type{Var{:fieldname}}) = false
```

Flatten also provides `metaflatten()` to flatten any FieldMetadata.jl
metadata for the fields `flatten()` returns. This can be useful for attaching information
like descriptions or optional units to each field. Regular field data can also be collected 
with convenience versions of metaflatten: `fieldnameflatten`, `parentflatten`, 
`fieldtypeflatten` and `parenttypeflatten` functions provide lists of fieldnames and types 
that may be useful for building parameter display tables.


This package was originally written by Robin Deits (@rdeits), and it owes much
to further discussions and ideas from Jan Weidner (@jw3126) and Robin Deits.
"""
module Flatten

using FieldMetadata
import FieldMetadata: @flattenable, @reflattenable, flattenable

export @flattenable, @reflattenable, flattenable, flatten, reconstruct, update!,
       metaflatten, fieldnameflatten, parentnameflatten, fieldtypeflatten, parenttypeflatten


# Default behaviour when no use/ignore args are given
const USE = Number
const IGNORE = AbstractArray


# Generalised nested struct walker
nested(T::Type, expr_builder, expr_combiner, action) =
    nested(T, Nothing, expr_builder, expr_combiner, action)
nested(T::Type, P::Type, expr_builder, expr_combiner, action) =
    expr_combiner(T, [Expr(:..., expr_builder(T, fn, action)) for fn in fieldnames(T)])

default_combiner(T, expressions) = Expr(:tuple, expressions...)


"""
    constructor_of(::Type)
Add methods to define constructors for types with custom type parameters.
"""
@generated constructor_of(::Type{T}) where T = getfield(T.name.module, Symbol(T.name.name))
constructor_of(::Type{T}) where T<:Tuple = :tuple
constructor_of(T::UnionAll) = constructor_of(T.body)



"""
    flatten(obj, [flattentrait::Function], [use::Type], [ignore::Type])

Flattening. Flattens a nested struct or tuple to a flat tuple.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.


# Arguments

`obj`: The target type to be reconstructed
`data`: Replacement data - an `AbstractArray`, `Tuple` or type that defines `getfield`.
`flattentrait`: A function returning a Bool, with the form `f(::Type, ::Type{Val{:fieldname}}) = true`.
`use`: Type or `Union` of types to return in the tuple.
`ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

# Examples

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> foo = Foo(1, 2, 3)
Foo{Int64,Int64,Int64}(1, 2, 3)

julia> flatten(foo)
(1, 2, 3)

julia> nested = Foo(Foo(1, 2, 3), 4.0, 5.0)
Foo{Foo{Int64,Int64,Int64},Float64,Float64}(Foo{Int64,Int64,Int64}(1, 2, 3), 4.0, 5.0)

julia> flatten(nested)
(1, 2, 3, 4.0, 5.0)
```


Fields can be excluded from flattening with the `flattenable(struct, field)`
method. These are easily defined using `@flattenable` from
[FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl), or defining your own
custom function with FieldMetadata, or manually with the form:


```julia
julia> import Flatten: flattenable

julia> @flattenable struct Partial{A,B,C}
           a::A | true
           b::B | true
           c::C | false
       end

julia> nestedpartial = Partial(Partial(1.0, 2.0, 3.0), 4, 5)
Partial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)

julia> nestedpartial = Partial(Partial(1.0, 2.0, 3.0), 4, 5)
Partial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)

julia> flatten(nestedpartial)
(1.0, 2.0, 4)
```

"""
function flatten end


flatten_builder(T, fname, action) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        $action(getfield(t, $(QuoteNode(fname))), flattentrait, use, ignore)
    else
        ()
    end
end

flatten_inner(T, action) =
    nested(T, flatten_builder, default_combiner, action)

flatten(t) = flatten(t, flattenable)
flatten(t, args...) = flatten(t, flattenable, args...)
flatten(t, ft::Function) = flatten(t, ft, USE)
flatten(t, ft::Function, use) = flatten(t, ft, use, IGNORE)

flatten(x::I, ft::Function, use::Type{U}, ignore::Type{I}) where {U,I} = ()
flatten(x::U, ft::Function, use::Type{U}, ignore::Type{I}) where {U,I} = (x,)
@generated flatten(t, flattentrait::Function, use, ignore) = flatten_inner(t, flatten)


"""
    reconstruct(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])

Reconstruct an object from Tuple or Vector data and an existing object.
Data should be at least as long as the queried fields in the obj.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments

`obj`: The target type to be reconstructed
`data`: Replacement data - an `AbstractArray`, `Tuple` or type that defines `getfield`.
`flattentrait`: A function returning a Bool, with the form `f(::Type, ::Type{Val{:fieldname}}) = true`.
`use`: Type or `Union` of types to return in the tuple.
`ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

# Examples

```julia
julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> reconstruct(Foo(1, 2, 3), (1, :two, 3.0))
Foo{Int64,Symbol,Float64}(1, :two, 3.0)
```
"""
function reconstruct end

reconstruct_builder(T, fname, action) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        val, n = $action(x, data, flattentrait, use, ignore, n)
        val
    else
        (getfield(t, $(QuoteNode(fname))),)
    end
end

reconstruct_combiner(T, expressions) =
    :(($(Expr(:call, constructor_of(T), expressions...)),), n)

reconstruct_inner(::Type{T}, action) where T =
    nested(T, reconstruct_builder, reconstruct_combiner, action)


reconstruct(t, data) = reconstruct(t, data, flattenable)
reconstruct(t, data, args...) = reconstruct(t, data, flattenable, args...)
reconstruct(t, data, ft::Function) = reconstruct(t, data, ft, USE)
reconstruct(t, data, ft::Function, use) = reconstruct(t, data, ft, use, IGNORE)
# Need to extract the final return value from the nested tuple
reconstruct(t, data, ft::Function, use, ignore) =
    reconstruct(t, data, ft, use, ignore, 1)[1][1]

# Return value unmodified
reconstruct(x::I, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} =
    (x,), n
# Return value from data. Increment position counter -  the returned n + 1 becomes n
reconstruct(x::U, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} =
    (data[n],), n + 1
@generated reconstruct(t, data, flattentrait::Function, use, ignore, n) =
    reconstruct_inner(t, reconstruct)


"""
    update!(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])
Update a mutable object with a `Tuple` or `Vector` of data.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments

`obj`: The target type to be reconstructed
`data`: Replacement data - an `AbstractArray`, `Tuple` or type that defines `getfield`.
`flattentrait`: A function that returns true or false given a type and `Val{:fieldname}`.
`use`: Types to return in the tuple.
`ignore`: Types to ignore completly. These are not reurned or recursed over.

# Examples

```jldoctest
julia> using Flatten

julia> mutable struct MutableFoo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> mufoo = MutableFoo(1, 2, 3)
MutableFoo{Int64,Int64,Int64}(1, 2, 3)

julia> update!(mufoo, (2, 4, 6))
MutableFoo{Int64,Int64,Int64}(2, 4, 6)

julia> mufoo = MutableFoo(1, 2, :three)
MutableFoo{Int64,Int64,Symbol}(1, 2, :three)

julia> update!(mufoo, (:four,), Symbol)
MutableFoo{Int64,Int64,Symbol}(1, 2, :four)
```
"""
function update! end

update_builder(T, fname, action) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        val, n = $action(x, data, flattentrait, use, ignore, n)
        setfield!(t, $(QuoteNode(fname)), val[1])
    end
    ()
end

# Use the reconstruct builder for tuples, they're immutable
update_builder(T::Type{<:Tuple}, fname, action) = reconstruct_builder(T, fname, action)

update_combiner(T, expressions) = :($(Expr(:tuple, expressions...)); ((t,), n))
update_combiner(T::Type{<:Tuple}, expressions) = reconstruct_combiner(T, expressions)

update_inner(::Type{T}, action) where T =
    nested(T, update_builder, update_combiner, action)

update!(t, data) = update!(t, data, flattenable)
update!(t, data, args...) = update!(t, data, flattenable, args...)
update!(t, data, ft::Function) = update!(t, data, ft, USE)
update!(t, data, ft::Function, use) = update!(t, data, ft, use, IGNORE)
update!(t, data, ft::Function, use, ignore) = begin
    update!(t, data, ft, use, ignore, firstindex(data))[1][1]
    t
end
update!(x::I, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} = (x,), n
update!(x::U, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} = (data[n],), n + 1
@generated update!(t, data, flattentrait::Function, use, ignore, n) = update_inner(t, update!)


"""
    metaflatten(obj, func, [flattentrait::Function], [use::Type], [ignore::Type])

Metadata flattening. Flattens data attached to a field using a passed in function
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments

`obj`: The target type to be reconstructed
`func`: A function with the form `f(::Type, ::Type{Val{:fieldname}}) = metadata`.
`flattentrait`: A function returning a Bool, with the form `f(::Type, ::Type{Val{:fieldname}}) = true`.
`use`: Type or `Union` of types to return in the tuple.
`ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

We can flatten the @foobar metadata defined earlier:

```jldoctest
julia> using Flatten, FieldMetadata

julia> import Flatten: flattenable

julia> @metadata foobar :foo;

julia> @foobar struct Foo{A,B,C}
           a::A | :bar
           b::B | :foobar
           c::C | :foo
       end;

julia> @foobar struct Bar{X,Y}
           x::X | :foobar
           y::Y | :bar
       end;

julia> metaflatten(Foo(1, 2, Bar(3, 4)), foobar)
(:bar, :foobar, :foobar, :bar)
```
"""
function metaflatten end

metaflatten_builder(T, fname, action) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        $action(x, func, flattentrait, use, ignore, $T, Val{$(QuoteNode(fname))})
    else
        ()
    end
end

metaflatten_inner(T::Type, action) =
    nested(T, metaflatten_builder, default_combiner, action)

metaflatten(t, func::Function) = metaflatten(t, func, flattenable)
metaflatten(t, func::Function, args...) = metaflatten(t, func, flattenable, args...)
metaflatten(t, func::Function, ft::Function) = metaflatten(t, func, ft, USE)
metaflatten(t, func::Function, ft::Function, use) = metaflatten(t, func, ft, use, IGNORE)
metaflatten(t, func::Function, ft::Function, use, ignore) =
    metaflatten(t, func::Function, ft::Function, use, ignore, Nothing, Val{:none})

metaflatten(x::I, func::Function, ft::Function, use::Type{U}, ignore::Type{I}, P, fname) where {U,I} = ()
metaflatten(x::U, func::Function, ft::Function, use::Type{U}, ignore::Type{I}, P, fname) where {U,I} =
    (func(P, fname),)
# Better field names for tuples.  TODO what about mixed type tuples?
metaflatten(xs::NTuple{N,Number}, func::Function, ft::Function, use, ignore, P, fname) where {N} =
    map(x -> func(P, fname), xs)
@generated metaflatten(t, func::Function, flattentrait::Function, use, ignore, P, fname) =
    metaflatten_inner(t, metaflatten)


# Helper functions to get field data with metaflatten

fieldname_meta(T, ::Type{Val{N}}) where N = N


"""jldoctest
    fieldnameflatten(t, args...)

# Examples

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> fieldnameflatten(Foo(1, 2, 3))
(:a, :b, :c)
```
"""
fieldnameflatten(t, args...) = metaflatten(t, fieldname_meta, args...)


fieldtype_meta(T, ::Type{Val{N}}) where N = fieldtype(T, N)

"""jldoctest
    fieldtypeflatten(t, args...)

# Examples

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> fieldtypeflatten(Foo(1.0, :two, "Three"), Union{Real,String})
(Float64, String)
```
"""
fieldtypeflatten(t, args...) = metaflatten(t, fieldtype_meta, args...)



fieldparent_meta(T, ::Type{Val{N}}) where N = T.name.name

"""
    parentnameflatten(t, args...)

# Examples

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> struct Bar{X,Y}
           x::X
           y::Y
       end

julia> parentnameflatten(Foo(1, 2, Bar(3, 4)))
(:Foo, :Foo, :Bar, :Bar)
```
"""
parentnameflatten(t, args...) = metaflatten(t, fieldparent_meta, args...)


fieldparenttype_meta(T, ::Type{Val{N}}) where N = T

"""
    parenttypeflatten(t, args...)

# Examples

```jldoctest
julia> using Flatten

julia> struct Foo{A,B,C}
           a::A
           b::B
           c::C
       end

julia> struct Bar{X,Y}
           x::X
           y::Y
       end

julia> parenttypeflatten(Foo(1, 2, Bar(3, 4)))
(Foo{Int64,Int64,Bar{Int64,Int64}}, Foo{Int64,Int64,Bar{Int64,Int64}}, Bar{Int64,Int64}, Bar{Int64,Int64})
```
"""
parenttypeflatten(t, args...) = metaflatten(t, fieldparenttype_meta, args...)


end # module
