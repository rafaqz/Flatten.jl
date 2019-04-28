module Flatten

using FieldMetadata, Requires 
import FieldMetadata: @flattenable, @reflattenable, flattenable

export @flattenable, @reflattenable, flattenable, flatten, reconstruct, retype, update!, 
       metaflatten, fieldnameflatten, parentflatten, fieldtypeflatten, parenttypeflatten 

# Optionally load Unitful and unlittless falttening 
function __init__()
    @require Unitful="1986cc42-f94f-5a68-af5c-568840ba703d" include("unitless.jl")
end


# Connect types to actions
abstract type FlattenAction end
struct Use <: FlattenAction end
struct Ignore <: FlattenAction end
struct Recurse <: FlattenAction end

action(::Number) = Use()
action(::Nothing) = Ignore()
action(::AbstractArray) = Ignore()
action(x) = Recurse()


# Generalised nested struct walker 
nested(T::Type, expr_builder, expr_combiner, funcname) = 
    nested(T, Nothing, expr_builder, expr_combiner, funcname)
nested(T::Type, P::Type, expr_builder, expr_combiner, funcname) = 
    expr_combiner(T, [Expr(:..., expr_builder(T, fn, funcname)) for fn in fieldnames(T)])

default_combiner(T, expressions) = Expr(:tuple, expressions...)


# Flatten

flatten_builder(T, fname, funcname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        $funcname(getfield(t, $(QuoteNode(fname))))
    else
        ()
    end
end

flatten_inner(T, funcname) = nested(T, flatten_builder, default_combiner, funcname)

flatten(::Ignore, x) = ()
flatten(::Use, x) = (x,) 
@generated flatten(::Recurse, t) = flatten_inner(t, :flatten)

flatten(::Type{V}, t) where V <: AbstractVector = V([flatten(t)...])
flatten(::Type{Tuple}, t) = flatten(t)

"Flattening. Flattens a nested type to a Tuple or Vector"
flatten(t) = flatten(action(t), t) 


# Reconstruct

reconstruct_builder(T, fname, funcname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        val, n = $funcname(action(x), x, data, n)
        val
    else
        (getfield(t, $(QuoteNode(fname))),)
    end
end

reconstruct_combiner(T, expressions) = :(($(Expr(:call, :($T), expressions...)),), n)
reconstruct_combiner(T::Type{<:Tuple}, expressions) = :(($(Expr(:tuple, expressions...)),), n)

reconstruct_inner(::Type{T}, funcname) where T = nested(T, reconstruct_builder, reconstruct_combiner, funcname)

reconstruct(::Ignore, x, data, n) = (x,), n
# Return a value from the data vector/tuple
# Also increment vector position counter - the returned n + 1 becomes the new n
reconstruct(::Use, x, data, n) = (data[n],), n + 1 
@generated reconstruct(::Recurse, t, data, n) = reconstruct_inner(t, :reconstruct)

" Reconstruct an object from partial Tuple or Vector data and another object"
reconstruct(t, data) = reconstruct(action(t), t, data, 1)[1][1]


# Retype

retype_combiner(T, expressions) = reconstruct_combiner(T.name.wrapper, expressions)

# Reuse the reconstruct expression builder
retype_inner(::Type{T}, funcname) where T = nested(T, reconstruct_builder, retype_combiner, funcname)

retype(::Ignore, x, data, n) = (x,), n
retype(::Use, x, data, n) = (data[n],), n + 1 
@generated retype(::Recurse, t, data, n) = retype_inner(t, :retype)

" Retype an object from partial Tuple or Vector data and another object"
retype(t, data) = retype(action(t), t, data, 1)[1][1]


# Update

update_builder(T, fname, funcname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        val, n = $funcname(action(x), x, data, n)
        setfield!(t, $(QuoteNode(fname)), val[1]) 
    end
    ()
end

# Use the reconstruct builder for tuples, they're immutable
update_builder(T::Type{<:Tuple}, fname, funcname) = reconstruct_builder(T, fname, funcname)

update_combiner(T, expressions) = :($(Expr(:tuple, expressions...)); ((t,), n))
update_combiner(T::Type{<:Tuple}, expressions) = reconstruct_combiner(T, expressions)

update_inner(::Type{T}, funcname) where T = nested(T, update_builder, update_combiner, funcname)

update!(::Ignore, x, data, n) = (x,), n
update!(::Use, x, data, n) = (data[n],), n + 1 
@generated update!(::Recurse, t::T, data, n) where T = update_inner(T, :update!)

" Update a mutable object with a Tuple or Vector"
update!(t, data) = begin
    update!(action(t), t, data, 1)
    t
end


# Metaflatten

metaflatten_builder(T, fname, funcname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        x = getfield(t, $(QuoteNode(fname)))
        $funcname(action(x), x, func, $T, Val{$(QuoteNode(fname))})
    else
        ()
    end
end

metaflatten_inner(T::Type, funcname) = nested(T, metaflatten_builder, default_combiner, funcname)

metaflatten(::Type{Tuple}, t, func) = metaflatten(t, func)
metaflatten(::Type{V}, t, func) where V <: AbstractVector = [metaflatten(t, func)...]

metaflatten(::Ignore, x, func, P, fname) = ()
metaflatten(::Use, x, func, P, fname) = (func(P, fname),)
# TODO what about mixed type tuples?
metaflatten(::Recurse, xs::NTuple{N,Number}, func, P, fname) where N = map(x -> func(P, fname), xs)
@generated metaflatten(::Recurse, t, func, P, fname) = metaflatten_inner(t, :metaflatten)

" Metadata flattening. Flattens data attached to a field using a passed in function"
metaflatten(t, func) = metaflatten(action(t), t, func, Nothing, Val{:none})


# Helper functions to get field data with metaflatten
#
fieldname_meta(T, ::Type{Val{N}}) where N = N

fieldnameflatten(T::Type, t) = metaflatten(T, t, fieldname_meta)
fieldnameflatten(t) = fieldnameflatten(Tuple, t)  

fieldtype_meta(T, ::Type{Val{N}}) where N = fieldtype(T, N)

fieldtypeflatten(T::Type, t) = metaflatten(T, t, fieldtype_meta)
fieldtypeflatten(t) = fieldtypeflatten(Tuple, t) 

fieldparent_meta(T, ::Type{Val{N}}) where N = T.name.name

parentflatten(T::Type, t) = metaflatten(T, t, fieldparent_meta)
parentflatten(t) = parentflatten(Tuple, t) 

fieldparenttype_meta(T, ::Type{Val{N}}) where N = T 

parenttypeflatten(T::Type, t) = metaflatten(T, t, fieldparenttype_meta)
parenttypeflatten(t) = parenttypeflatten(Tuple, t)


end # module
