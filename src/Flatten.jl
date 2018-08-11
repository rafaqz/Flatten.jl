__precompile__()

module Flatten

using MetaFields, Nested, Unitful

export @flattenable, flattenable, Include, Exclude, flatten, construct, reconstruct, 
       metaflatten, fieldname_meta, fieldparent_meta, fieldtype_meta, fieldparenttype_meta

struct Include end
struct Exclude end

@metafield flattenable Include()


flatten_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))}) == Include()
        flatten(getfield($path, $(QuoteNode(fname))))
    else
        ()
    end
end

flatten_inner(T) = nested(T, :t, flatten_expr)

"Flattening. Flattens a nested type to a Tuple or Vector"
flatten(::Type{V}, t) where V <: AbstractVector = V([flatten(t)...])
flatten(::Type{Tuple}, t) = flatten(t)
flatten(x::Void) = ()
flatten(x::Any) = (x,) 
flatten(x::Number) = (x,) 
flatten(x::Unitful.Quantity) = (x.val,) 
@generated flatten(t) = flatten_inner(t)


metaflatten_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))}) == Include() 
        metaflatten(getfield($path, $(QuoteNode(fname))), func, $T, Val{$(QuoteNode(fname))})
    else
        ()
    end
end

metaflatten_inner(T::Type) = nested(T, :t, metaflatten_expr)

" Metaflattening. Flattens data attached to a field by methods of a passed in function"
metaflatten(::Type{Tuple}, t, func) = metaflatten(t, func)
metaflatten(::Type{V}, t, func) where V <: AbstractVector = [metaflatten(t, func)...]
metaflatten(x::Void, func, P, fname) = ()
metaflatten(x::Number, func, P, fname) = (func(P, fname),)
metaflatten(x::Any, func, P, fname) = (func(P, fname),)
metaflatten(t, func) = metaflatten(t, func, Void, Val{:none})
@generated metaflatten(t, func, P, fname) = metaflatten_inner(t)

# # Helper functions to get field data with metaflatten
fieldname_meta(T, ::Type{Val{N}}) where N = N
fieldtype_meta(T, ::Type{Val{N}}) where N = fieldtype(T, N)
fieldparent_meta(T, ::Type{Val{N}}) where N = T.name.name
fieldparenttype_meta(T, ::Type{Val{N}}) where N = T 


reconstruct_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))}) == Include()
        val, n = reconstruct(getfield($path, $(QuoteNode(fname))), data, n)
        val
    else
        (getfield($path, $(QuoteNode(fname))),)
    end
end

reconstruct_handler(T, expressions) = :(($(Expr(:call, :($T.name.wrapper), expressions...)),), n)
reconstruct_handler(T::Type{<:Tuple}, expressions) = :(($(Expr(:tuple, expressions...)),), n)

reconstruct_inner(::Type{T}) where T = nested(T, :t, reconstruct_expr, reconstruct_handler)

" Reconstruct an object from partial Tuple or Vector data and another object"
reconstruct(t, data) = reconstruct(t, data, 1)[1][1]
reconstruct(::Void, data, n) = (nothing,), n
reconstruct(::Number, data, n) = (data[n],), n + 1 
reconstruct(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated reconstruct(t, data, n) = reconstruct_inner(t)

end # module
