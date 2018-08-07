__precompile__()

module Flatten

using MetaFields, Nested

export @flattenable, flattenable, Include, Exclude, flatten, construct, reconstruct, wrap, 
       metaflatten, fieldname_meta, fieldparent_meta, fieldtype_meta, fieldparenttype_meta

@metafield flattenable Include()



flatten_inner(T) = nested(T, :T, :flattenable)

"Flattening. Flattens a nested type to a Tuple or Vector"
@generated function flatten(::Type{Tuple}, T)
    flatten_inner(T)
end
@generated function flatten(::Type{V}, T) where V <: AbstractVector
    :(V([$(flatten_inner(T))...]))
end
flatten(T) = flatten(Tuple, T)



metaflatten_val(T, P, path) = Expr(:call, :func, P, Expr(:curly, :Val, path.args[2]))
metaflatten_inner(::Type{T}) where T = nested(T, :T, :flattenable, metaflatten_val)

" Metaflattening. Flattens data attached to a field by methods of a passed in function"
@generated function metaflatten(::Type{Tuple}, T, func)
    metaflatten_inner(T)
end
@generated function metaflatten(::Type{V}, T, func) where V <: AbstractVector
    :(V([$(metaflatten_inner(T))...]))
end
metaflatten(T, func) = metaflatten(Tuple, T, func)

# Helper functions to get field data with metaflatten
fieldname_meta(T, ::Type{Val{N}}) where N = N
fieldtype_meta(T, ::Type{Val{N}}) where N = fieldtype(T, N)
fieldparent_meta(T, ::Type{Val{N}}) where N = T.name.name
fieldparenttype_meta(T, ::Type{Val{N}}) where N = T 



reconstruct_val(T, P, path) = quote
    n += 1
    data[n]
end
reconstruct_alt(path, fname) = Expr(:tuple, Expr(:., path, QuoteNode(fname)))
reconstruct_tuplewrap(T, expressions) = Expr(:tuple, Expr(:tuple, expressions...))
reconstruct_structwrap(T, expressions) = Expr(:tuple, Expr(:call, Expr(:., Expr(:., T, QuoteNode(:name)), QuoteNode(:wrapper)), expressions...))

reconstruct_inner(::Type{T}) where T = quote
    n = 0
    $(nested(T, :T, :flattenable, reconstruct_val, reconstruct_alt, reconstruct_tuplewrap, reconstruct_structwrap))
end

" Reconstruct an object from partial Tuple or Vector data and another object"
@generated function reconstruct(T, data) 
    reconstruct_inner(T)
end



construct_inner(::Type{T}) where T = quote
    n = 0
    $(nested(T, :T, :nested_include_all, reconstruct_val, reconstruct_alt, reconstruct_tuplewrap, reconstruct_structwrap))
end

"Construct an object from Tuple or Vector data and a type"
@generated function construct(::Type{T}, data) where T
    construct_inner(T)
end


end # module
