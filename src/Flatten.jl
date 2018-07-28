__precompile__()

module Flatten

using MetaFields, Requires
using Base: tail

export @flattenable, flattenable, Flat, NotFlat, flatten, construct, reconstruct, wrap

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
field_expressions{T2 <: Tuple}(T::Type{T2}, path) = begin
    expressions = Expr(:tuple)
    for i in 1:length(T.types)
        field_expr = field_expressions(fieldtype(T, i), Expr(:ref, path, i))
        push!(expressions.args, Expr(:..., field_expr))
    end
    expressions
end
field_expressions(T::Type{Any}, path) = Expr(:tuple, path)
field_expressions(T::Type{T2}, path) where T2 <: Number = Expr(:tuple, path)
field_expressions(T::Type{T2}, path) where T2 <: AbstractArray = error("Cannot flatten variable-length objects like arrays. Replace any arrays with tuples if possible.")
@require Unitful begin
    field_expressions(T::Type{T2}, path) where T2 <: Unitful.Quantity = Expr(:tuple, Expr(:., path, QuoteNode(:val)))
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

_reconstruct(T, path) = begin
    expr = Expr(:call, T)
    fnames = fieldnames(T)
    for (i, subtype) in enumerate(T.types)
        field = quote
            if flattenable($T, $(Expr(:curly, :Val, QuoteNode(fnames[i])))) == Flat()
                $(_reconstruct(subtype, Expr(:., path, QuoteNode(fnames[i]))))
            else
                $(Expr(:., path, QuoteNode(fnames[i])))
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

function construct_inner(::Type{T} ) where T
    _construct(T, Counter())
end

@generated function construct(::Type{T}, data) where T
    construct_inner(T)
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


end # module
