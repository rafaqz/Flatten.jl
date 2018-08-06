__precompile__()

module Flatten

using MetaFields, Unitful

export @flattenable, flattenable, Flat, NotFlat, flatten, construct, reconstruct, wrap, 
       metaflatten, fieldname_meta, fieldparent_meta, fieldtype_meta, fieldparenttype_meta

# Stopgap singletons until boolean constants work, in 0.7
struct Flat end
struct NotFlat end

@metafield flattenable Flat()
flatten_all(x, field) = Flat()


"""
Builds a list of expressions for each field of the struct. 

Includes checks to see if each field is included, which are performed
after the generated function, but still at compile time. 

Arguments:
- `T`: the type of the current object
- `P`: the typoe of the last parent object
- `path`: the ast path from the original type to the current object. Not sure what else to call this??
- `val`: a function that returns the expression that gives the value for the field
- `check`: a a symbol or expression for the function that checks if a field should be included.
   this function takes two arguments: struct type and fieldname.
- `alt`: alternate value if the field is not to be included
- `structwrap`: a function that wraps the expression returned when a struct is parsed, maybe adding a constructor.
"""
field_expressions(T, P, path, val, check, alt, structwrap) = begin
    fnames = fieldnames(T)
    expressions = []
    for (i, fname) in enumerate(fnames)
        expr = :(
            if $check($T, $(Expr(:curly, :Val, QuoteNode(fnames[i])))) == Flat()
                $(field_expressions(fieldtype(T, i), T, Expr(:., path, Expr(:quote, fname)), val, check, alt, structwrap))
            else
                $(alt(path, fnames[i]))
            end
        )
        push!(expressions, Expr(:..., expr))
    end
    structwrap(T, expressions)
end
field_expressions(::Type{T}, P, path, args...) where T <: Tuple = begin
    expressions = Expr(:tuple)
    for i in 1:length(T.types)
        expr = field_expressions(fieldtype(T, i), T, Expr(:ref, path, i), args...)
        push!(expressions.args, Expr(:..., expr))
    end
    expressions
end
field_expressions(::Type{T}, P, path, args...) where T <: Unitful.Quantity = 
    field_expressions(fieldtype(T, :val), P, Expr(:., path, QuoteNode(:val)), args...)
field_expressions(::Type{T}, P, path, val, args...) where T <: Number = Expr(:tuple, val(T, P, path)) 
field_expressions(::Type{Any}, P, path, val, args...) = Expr(:tuple, val(Any, P, path))


# Flattening
flatten_alt(path, fname) = ()
flatten_structwrap(T, expressions) = Expr(:tuple, expressions...)
flatten_val(T, P, path) = path
flatten_inner(T) = field_expressions(T, :T, :T, flatten_val, :flattenable, flatten_alt, flatten_structwrap)

@generated function flatten(::Type{Tuple}, T)
    flatten_inner(T)
end
@generated function flatten(::Type{V}, T) where V <: AbstractVector
    :(V([$(flatten_inner(T))...]))
end
flatten(T) = flatten(Tuple, T)


# Metaflattening
metaflatten_val(T, P, path) = Expr(:call, :func, P, Expr(:curly, :Val, path.args[2]))
metaflatten_inner(::Type{T}) where T = field_expressions(T, :T, :T, metaflatten_val, :flattenable, flatten_alt, flatten_structwrap)

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


# Reconstruction from data and a struct
reconstruct_val(T, P, path) = quote
    n += 1
    data[n]
end
reconstruct_alt(path, fname) = Expr(:tuple, Expr(:., path, QuoteNode(fname)))
reconstruct_structwrap(T, expressions) = Expr(:tuple, Expr(:call, Expr(:., Expr(:., T, QuoteNode(:name)), QuoteNode(:wrapper)), expressions...))

function reconstruct_inner(::Type{T}) where T
    quote
        n = 0
        $(field_expressions(T, :T, :T, reconstruct_val, :flattenable, reconstruct_alt, reconstruct_structwrap))
    end
end

@generated function reconstruct(T, data) 
    reconstruct_inner(T)
end


# Construction from data and a type
function construct_inner(::Type{T}) where T
    quote
        n = 0
        $(field_expressions(T, :T, :T, reconstruct_val, :flatten_all, reconstruct_alt, reconstruct_structwrap))
    end
end

@generated function construct(::Type{T}, data) where T
    construct_inner(T)
end

end # module
