module Flatten

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    # Use [`XX`](@ref) in the docs but not the readme
    replace(read(path, String), r"`(\w+\w)`" => s"[`\1`](@ref)")
    # Use doctests
    replace(read(path, String), "```julia" => "```jldoctest")
end Flatten

using ConstructionBase, FieldMetadata

import FieldMetadata: @flattenable, flattenable

export @flattenable, flattenable, flatten, reconstruct, update!, modify,
       metaflatten, fieldnameflatten, parentnameflatten, fieldtypeflatten, parenttypeflatten

struct EmptyIgnore end

# Default behaviour when no flattentrait/use/ignore args are given
const USE = Real
const IGNORE = EmptyIgnore
const FLATTENTRAIT = flattenable

_fieldnames(::Type{<:Type}) = ()
_fieldnames(::Type{T}) where {T} = fieldnames(T)

# Generalised nested struct walker
nested(T::Type, P::Type, expr_builder, expr_combiner) =
    expr_combiner(T, [Expr(:..., expr_builder(T, fn)) for fn in _fieldnames(T)])
# Unknown parent type is replaced with Nothing
nested(T::Type, expr_builder, expr_combiner) =
    nested(T, Nothing, expr_builder, expr_combiner)


"""
    flatten(obj, [flattentrait::Function], [use::Type], [ignore::Type])

Flattening. Flattens a nested struct or tuple to a flat tuple.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.


# Arguments

- `obj`: The target type to be reconstructed
- `flattentrait`: A function returning a Bool, such as a FielMetadata method. With the form:
  `f(::Type, ::Type{Val{:fieldname}}) = true`
- `use`: Type or `Union` of types to return in the tuple.
- `ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

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

To convert the tuple to a vector, simply use [flatten(x)...], or
using static arrays to avoid allocations: `SVector(flatten(x))`.
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


flatten_builder(T, fname) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        flatten(getfield(obj, $(QuoteNode(fname))), flattentrait, use, ignore)
    else
        ()
    end
end

flatten_combiner(T, expressions) = Expr(:tuple, expressions...)

flatten_inner(T) = nested(T, flatten_builder, flatten_combiner)

flatten(obj) = flatten(obj, flattenable)
flatten(obj, args...) = flatten(obj, flattenable, args...)
flatten(obj, ft::Function) = flatten(obj, ft, USE)
flatten(obj, ft::Function, use) = flatten(obj, ft, use, IGNORE)
flatten(x::X, ft::Function, use::Type{U}, ignore::Type{I}) where {X,U,I} =
    if X <: I
        ()
    elseif X <: U
        (x,)
    else
        _flatten(x, ft, use, ignore)
    end

@generated _flatten(obj, flattentrait, use, ignore) = flatten_inner(obj)

"""
    reconstruct(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])

Reconstruct an object from Tuple or Vector data and an existing object.
Data should be at least as long as the queried fields in the obj.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments
- `obj`: The target type to be reconstructed
- `data`: Replacement data - an `AbstractArray`, `Tuple` or type that defines `getfield`.
- `flattentrait`: A function returning a Bool, such as a FielMetadata method. With the form:
  `f(::Type, ::Type{Val{:fieldname}}) = true`
- `use`: Type or `Union` of types to return in the tuple.
- `ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

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
reconstruct(obj, data, use::Type=USE, ignore::Type=IGNORE) = _reconstruct(obj, data, flattenable, use, ignore, 1)[1]
reconstruct(obj, data, flattentrait, use::Type=USE, ignore::Type=IGNORE) = _reconstruct(obj, data, flattentrait, use, ignore, 1)[1]

# Internal type used to generate contructor expressions.
# Represents a bi-directional (doubly linked) type tree where child nodes correspond to fields of composite types.
mutable struct TypeNode{T,TChildren}
    type::Type{T}
    name::Union{Int,Symbol}
    parent::Union{Missing,TypeNode}
    children::TChildren
    TypeNode(type::Type{T}, name::Union{Int,Symbol}, children::Union{Missing,<:Tuple{Vararg{TypeNode}}}=missing) where {T} = new{T,typeof(children)}(type, name, missing, children)
end
function _buildtree(::Type{T}, name) where {T}
    if isabstracttype(T) || isa(T, Union) || isa(T, UnionAll)
        return TypeNode(T, name)
    elseif T <: Type # treat meta types as leaf nodes
        return TypeNode(T, name, ())
    else
        names = fieldnames(T)
        types = fieldtypes(T)
        children = map(_buildtree, types, names)
        node = TypeNode(T, name, children)
        # set parent field on children
        for child in children
            child.parent = node
        end
        return node
    end
end
# Recursive accessor (getfield) expression builder
_accessor_expr(::Missing, child::TypeNode) = :obj
_accessor_expr(parent::TypeNode, child::TypeNode) = Expr(:call, :getfield, _accessor_expr(parent.parent, parent), QuoteNode(child.name))
# Recursive reconstruct expression builder;
# Case 1: Leaf node (i.e. no fields)
_reconstruct_expr(node::TypeNode{T,Tuple{}}, use::Type{U}, ignore::Type) where {T,U} = :(($(_accessor_expr(node.parent, node)), n))
# Case 2: Ignored type; value is taken from accessor
_reconstruct_expr(node::TypeNode{<:I}, use::Type, ignore::Type{I}) where {I} = :(($(_accessor_expr(node.parent, node)), n))
# Case 3: Matched type; if marked as flattenable, value is taken from `data` at index `n`;
# Dispatch doesn't seem to work properly between Case 1 above and TypeNode{<:U} here. To ameliorate this,
# we provide dispatches for both the leaf and non-leaf case where T<:U and move the common implementation to __reconstruct_expr.
_reconstruct_expr(node::TypeNode{<:U}, use::Type{U}, ignore::Type{I}) where {U,I} = __reconstruct_expr(node, U, I)
_reconstruct_expr(node::TypeNode{<:U,Tuple{}}, use::Type{U}, ignore::Type{I}) where {U,I} = __reconstruct_expr(node, U, I)
function __reconstruct_expr(node::TypeNode{<:U}, use::Type{U}, ignore::Type) where {U}
    if ismissing(node.parent)
        :(data[n], n+1)
    else
        # if field is flattenable, then take from data, otherwise, use accessor on current object
        :(flattentrait($(node.parent.type),Val{$(QuoteNode(node.name))}) ? (data[n],n+1) : ($(_accessor_expr(node.parent, node)), n))
    end
end
# Case 4: Abstract type whose fields are unknown at compile-time. Here we fall back to a runtime invocation of _reconstruct.
_reconstruct_expr(node::TypeNode{T,Missing}, ::Type{U}, ::Type{I}) where {T,U,I} = :(_reconstruct($(_accessor_expr(node.parent, node)), data, flattentrait, U, I, n))
# Case 5: Composite type fields (i.e. with fields) are reconstructed recursively;
# Recursion is used only at compile time in building the constructor expression. This ensures type stability.
function _reconstruct_expr(node::TypeNode{T}, ::Type{U}, ::Type{I}) where {T,U,I} 
    expr = Expr(:block)
    argnames = []
    # Generate constructor expression for each child/field
    for child in node.children
        flattened_expr = _reconstruct_expr(child, U, I)
        accessor_expr = _accessor_expr(node, child)
        name = gensym("arg")
        child_expr = quote
            ($name, n) =
                if flattentrait($T, Val{$(QuoteNode(child.name))})
                    $flattened_expr
                else
                    ($accessor_expr, n)
                end
        end
        push!(expr.args, child_expr)
        push!(argnames, name)
    end
    # Combine into constructor call
    callexpr = Expr(:call, :(ConstructionBase.constructorof($T)), argnames...)
    # Return result along with current `data` index, `n`
    push!(expr.args, :(($callexpr, n)))
    return expr
end
@inline @generated _reconstruct(obj::T, data, flattentrait, use::Type{U}, ignore::Type{I}, n) where {T,U,I} = _reconstruct_expr(_buildtree(T, :obj), U, I)

"""
    modify(func, obj, args...)

Modify field in a type with a function
"""
modify(f, obj, args...) = reconstruct(obj, map(f, flatten(obj, args...)), args...)

"""
    update!(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])

Update a mutable object with a `Tuple` or `Vector` of data.
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments

- `obj`: The target type to be reconstructed
- `data`: Replacement data - an `AbstractArray`, `Tuple` or type that defines `getfield`.
- `flattentrait`: A function returning a Bool, such as a FielMetadat method. With the form:
  `f(::Type, ::Type{Val{:fieldname}}) = true`
- `use`: Types to return in the tuple.
- `ignore`: Types to ignore completly. These are not reurned or recursed over.

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

julia> update!(mufoo, (:foo,), Symbol)
MutableFoo{Int64,Int64,Symbol}(1, 2, :foo)
```
"""
function update! end

update_builder(T, fname) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(obj, $(QuoteNode(fname)))
        val, n = update!(x, data, flattentrait, use, ignore, n)
        setfield!(obj, $(QuoteNode(fname)), val[1])
    end
    ()
end

# Identical to the reconstruct builder for tuples, they're immutable
update_builder(T::Type{<:Tuple}, fname) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(obj, $(QuoteNode(fname)))
        val, n = update!(x, data, flattentrait, use, ignore, n)
        val
    else
        (getfield(obj, $(QuoteNode(fname))),)
    end
end

update_combiner(T, expressions) = :($(Expr(:tuple, expressions...)); ((obj,), n))
update_combiner(T::Type{<:Tuple}, expressions) = :($(Expr(:tuple, expressions...)), n)

update_inner(::Type{T}) where T =
    nested(T, update_builder, update_combiner)

update!(obj, data) = update!(obj, data, flattenable)
update!(obj, data, args...) = update!(obj, data, flattenable, args...)
update!(obj, data, ft::Function) = update!(obj, data, ft, USE)
update!(obj, data, ft::Function, use) = update!(obj, data, ft, use, IGNORE)
update!(obj, data, ft::Function, use, ignore) = begin
    update!(obj, data, ft, use, ignore, firstindex(data))[1][1]
    obj
end
update!(x::I, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} = (x,), n
update!(x::U, data, ft::Function, use::Type{U}, ignore::Type{I}, n) where {U,I} = (data[n],), n + 1
@generated update!(obj, data, flattentrait::Function, use, ignore, n) =
    quote
        x, n = $(update_inner(obj))
        (obj,), n
    end


"""
    metaflatten(obj, func, [flattentrait::Function], [use::Type], [ignore::Type])

Metadata flattening. Flattens data attached to a field using a passed in function
Query types and flatten trait arguments are optional, but you must pass `use` to pass `ignore`.

# Arguments

- `obj`: The target type to be reconstructed
- `func`: A function with the form: `f(::Type, ::Type{Val{:fieldname}}) = metadata`
- `flattentrait`: A function returning a Bool, such as a FielMetadata method. With the form:
  `f(::Type, ::Type{Val{:fieldname}}) = true`
- `use`: Type or `Union` of types to return in the tuple.
- `ignore`: Types or `Union` of types  to ignore completly. These are not reurned or recursed over.

We can flatten this `@foobar` metadata:

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

metaflatten_builder(T, fname) = quote
    if flattentrait($T, Val{$(QuoteNode(fname))})
        x = getfield(obj, $(QuoteNode(fname)))
        metaflatten(x, func, flattentrait, use, ignore, $T, Val{$(QuoteNode(fname))})
    else
        ()
    end
end

metaflatten_inner(T::Type) =
    nested(T, metaflatten_builder, flatten_combiner)

metaflatten(obj, func::Function) = metaflatten(obj, func, flattenable)
metaflatten(obj, func::Function, args...) = metaflatten(obj, func, flattenable, args...)
metaflatten(obj, func::Function, ft::Function) = metaflatten(obj, func, ft, USE)
metaflatten(obj, func::Function, ft::Function, use) = metaflatten(obj, func, ft, use, IGNORE)
metaflatten(obj, func::Function, ft::Function, use, ignore) =
    metaflatten(obj, func::Function, ft::Function, use, ignore, Nothing, Val{:none})

metaflatten(x::I, func::Function, ft::Function, use::Type{U}, ignore::Type{I}, P, fname) where {U,I} = ()
metaflatten(x::U, func::Function, ft::Function, use::Type{U}, ignore::Type{I}, P, fname) where {U,I} =
    (func(P, fname),)
@generated metaflatten(obj, func::Function, flattentrait::Function, use, ignore, P, fname) =
    metaflatten_inner(obj)


# Helper functions to get field data with metaflatten

fieldname_meta(T, ::Type{Val{N}}) where N = N


"""jldoctest
    fieldnameflatten(obj, args...)

Flatten the field names of an object. Args are passed to [`metaflatten`](@ref).

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
fieldnameflatten(obj, args...) = metaflatten(obj, fieldname_meta, args...)


fieldtype_meta(T, ::Type{Val{N}}) where N = fieldtype(T, N)

"""
    fieldtypeflatten(obj, args...)

Flatten the field types of an object. Args are passed to [`metaflatten`](@ref).

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
fieldtypeflatten(obj, args...) = metaflatten(obj, fieldtype_meta, args...)



fieldparent_meta(T, ::Type{Val{N}}) where N = T.name.name

"""
    parentnameflatten(obj, args...)

Flatten the name of the parent type of an object. Args are passed to [`metaflatten`](@ref).

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
parentnameflatten(obj, args...) = metaflatten(obj, fieldparent_meta, args...)


fieldparenttype_meta(T, ::Type{Val{N}}) where N = T

"""
    parenttypeflatten(obj, args...)

Flatten the parent type of an object. Args are passed to [`metaflatten`](@ref).

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
parenttypeflatten(obj, args...) = metaflatten(obj, fieldparenttype_meta, args...)


end # module
