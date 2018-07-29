__precompile__()

module Flatten

using MetaFields, Requires
using Base: tail

export @flattenable, flattenable, Flat, NotFlat, flatten, construct, reconstruct, wrap, 
       metaflatten, fieldname_meta, fielddoc_meta

@metafield flattenable Flat()

struct Flat end
struct NotFlat end


field_expressions(T, path) = begin
    expressions = Expr(:tuple)
    fnames = fieldnames(T)
    for (i, field) in enumerate(fieldnames(T))
        field_expr = :(
            if flattenable($T, $(Expr(:curly, :Val, QuoteNode(fnames[i])))) == Flat()
                $(field_expressions(fieldtype(T, i), Expr(:., path, Expr(:quote, field))))
            else
                ()
            end...
        )
        push!(expressions.args, Expr(:..., field_expr))
    end
    expressions
end
field_expressions(::Type{T}, path)  where T <: Tuple = begin
    expressions = Expr(:tuple)
    for i in 1:length(T.types)
        field_expr = field_expressions(fieldtype(T, i), Expr(:ref, path, i))
        push!(expressions.args, Expr(:..., field_expr))
    end
    expressions
end
field_expressions(::Type{Any}, path) = Expr(:tuple, path)
field_expressions(::Type{T}, path) where T <: Number = Expr(:tuple, path)
field_expressions(::Type{T}, path) where T <: AbstractArray = error("Cannot flatten variable-length objects like arrays. Replace any arrays with tuples if possible.")
@require Unitful begin
    field_expressions(::Type{T}, path) where T <: Unitful.Quantity = Expr(:tuple, Expr(:., path, QuoteNode(:val)))
end

function flatten_inner(T)
    field_expressions(T, :T)
end

@generated function flatten(::Type{Tuple}, T)
    flatten_inner(T)
end
@generated function flatten(::Type{V}, T) where V <: AbstractVector
    :(V([$(flatten_inner(T))...]))
end
flatten(T) = flatten(Tuple, T)


type Counter
    value::Int

    Counter() = new(1)
end

_construct(T, counter) = begin
    expr = Expr(:call, T)
    for subtype in T.types
        push!(expr.args, _construct(subtype, counter))
    end
    expr
end
_construct(::Type{T}, counter) where T <: Tuple = begin
    expr = Expr(:tuple)
    for subtype in T.types
        push!(expr.args, _construct(subtype, counter))
    end
    expr
end
_construct(T::TypeVar, counter) = construct_element(counter)
_construct(::Type{Any}, counter) = construct_element(counter)
_construct(::Type{T}, counter) where T <: Number = construct_element(counter)
@require Unitful begin
    _construct(::Type{T}, counter) where T <: Unitful.Quantity =
        Expr(:call, T, construct_element(counter))
end

function construct_element(counter)
    expr = Expr(:ref, :data, counter.value)
    counter.value += 1
    expr
end

construct_inner(::Type{T} ) where T = _construct(T, Counter())

@generated function construct(::Type{T}, data) where T
    construct_inner(T)
end


_reconstruct(T, path) = begin
    expr = Expr(:call, T)
    subfieldnames = fieldnames(T)
    for (i, subtype) in enumerate(T.types)
        field = quote
            if flattenable($T, $(Expr(:curly, :Val, QuoteNode(subfieldnames[i])))) == Flat()
                $(_reconstruct(subtype, Expr(:., path, QuoteNode(subfieldnames[i]))))
            else
                $(Expr(:., path, QuoteNode(subfieldnames[i])))
            end
        end
        push!(expr.args, field)
    end
    expr
end
_reconstruct(::Type{T}, path) where T <: Tuple = begin
    expr = Expr(:tuple)
    for (i, subtype) in enumerate(T.types)
        push!(expr.args, _reconstruct(subtype, Expr(:ref, path, 1)))
    end
    expr
end
_reconstruct(T::TypeVar, path) = element()
_reconstruct(::Type{Any}, path) = element()
_reconstruct(::Type{T}, path) where T <: Number = element()

@require Unitful begin
    _reconstruct(::Type{T}, path) where T <: Unitful.Quantity =
        Expr(:call, T, construct_element())
end

element() = quote
        n += 1
        data[n]
    end

function reconstruct_inner(::Type{T}) where T
    quote
        n = 0
        $(_reconstruct(T, :original))
    end
end

@generated function reconstruct(original::T, data) where T
    reconstruct_inner(T)
end

function wrap(func, InputType)
	x -> flatten(Vector, func(construct(InputType, x)))
end


_metaflatten(T, P, fname) = begin
    expressions = Expr(:tuple)
    subfieldnames = fieldnames(T)
    for (i, subfieldname) in enumerate(subfieldnames)
        field_expr = :(
            if flattenable($T, $(Expr(:curly, :Val, QuoteNode(subfieldname)))) == Flat()
                $(_metaflatten(fieldtype(T, i), T, subfieldname))
            else
                ()
            end...
        )
        push!(expressions.args, Expr(:..., field_expr))
    end
    expressions
end
_metaflatten(::Type{T}, P, fname) where T <: Tuple = begin
    expressions = Expr(:tuple)
    for i in 1:length(T.types)
        field_expr = _metaflatten(fieldtype(T, i), fname)
        push!(expressions.args, Expr(:..., field_expr))
    end
    expressions
end
_metaflatten(::Type{Any}, P, fname) = func_expr(P, fname)
_metaflatten(::Type{T}, P, fname) where T <: Number = func_expr(P, fname)
_metaflatten(::Type{T}, P, fname) where T <: AbstractArray = error("Cannot flatten variable-length objects like arrays. Replace any arrays with tuples if possible.")

func_expr(P, fname) = Expr(:tuple, Expr(:call, :func, P, Expr(:curly, :Val, QuoteNode(fname))))

metaflatten_inner(::Type{T}) where T = _metaflatten(T, :T, :unnamed)
@generated function metaflatten(::Type{V}, ::Type{T}, func) where {V <: Tuple,T}
    metaflatten_inner(T)
end
@generated function metaflatten(::Type{V}, ::Type{T}, func) where {V <: AbstractVector,T}
    :(V([$(metaflatten_func(T))...]))
end
metaflatten(::Type{V}, ::T, func) where {V,T} = metaflatten(V, T, func)
metaflatten(::Type{T}, func) where T = metaflatten(Tuple, T, func)
metaflatten(::T, func) where T = metaflatten(T, func)

fieldname_meta(T, ::Type{Val{N}}) where N = N

end # module
