module Flatten

using Unitful, Flattenable
export flatten, construct, reconstruct, wrap

field_expressions(T, expr::Union{Expr, Symbol}) = begin
    expressions = Expr[]
    isflat = flattenable(T)
    for (i, field) in enumerate(fieldnames(T))
        if isflat[i]
            field_expr = Expr(:., expr, Expr(:quote, field))
            append!(expressions, field_expressions(fieldtype(T, i), field_expr))
        end
    end
    expressions
end
field_expressions{T2 <: Tuple}(T::Type{T2}, expr::Union{Expr, Symbol}) = begin
    expressions = Expr[]
    for i in 1:length(T.types)
        field_expr = Expr(:ref, expr, i)
        append!(expressions, field_expressions(fieldtype(T, i), field_expr))
    end
    expressions
end
field_expressions(T::Type{Any}, expr::Union{Expr, Symbol}) = [expr]
field_expressions(T::Type{T2}, expr::Union{Expr, Symbol}) where T2 <: Unitful.Quantity = [Expr(:., expr, QuoteNode(:val))]
field_expressions(T::Type{T2}, expr::Union{Expr, Symbol}) where T2 <: Number = [expr]
field_expressions(T::Type{T2}, expr::Union{Expr, Symbol}) where T2 <: AbstractArray = error("Cannot flatten variable-length objects like arrays. Replace any arrays with tuples if possible.")

all_field_types(T) = begin
    field_types = DataType[]
    isflat = flattenable(T)
    for (i, field) in enumerate(fieldnames(T))
        isflat[i] && append!(field_types, all_field_types(fieldtype(T, i)))
    end
    field_types
end
all_field_types(T::Type{T2}) where T2 <: Number = [T]
all_field_types(T::Type{T2}) where T2 <: Unitful.Quantity = [fieldtype(T, :val)]
all_field_types(T::Type{T2}) where T2 <: Tuple = begin
    field_types = DataType[]
    for i in 1:length(T.types)
        append!(field_types, all_field_types(T.types[i]))
    end
    field_types
end

@generated function flatten(::Type{Tuple}, T)
    expr = Expr(:tuple)
    append!(expr.args, field_expressions(T, :T))
    expr
end
@generated function flatten(::Type{V}, T) where V <: AbstractVector
    field_types = all_field_types(T)
    num_elements = length(field_types)
    element_type = reduce(promote_type, field_types)
    expr = quote
        v = V{$element_type}($num_elements)
    end
    for (i, field_expr) in enumerate(field_expressions(T, :T))
        push!(expr.args, Expr(:(=), Expr(:ref, :v, i), field_expr))
    end
    push!(expr.args, :v)
    return expr
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
_construct(::Type{T}, counter) where T <: Unitful.Quantity =
    Expr(:call, T, construct_element(counter))

_reconstruct(T, path, counter) = begin
    expr = Expr(:call, T)
    isflat = flattenable(T)
    fnames = fieldnames(T)
    for (i, subtype) in enumerate(T.types)
        if isflat[i]
            push!(expr.args, _reconstruct(subtype, Expr(:., path, QuoteNode(fnames[i])), counter))
        else
            push!(expr.args, Expr(:., path, QuoteNode(fnames[i])))
        end
    end
    expr
end
_reconstruct(::Type{T}, path, counter) where T <: Tuple = begin
    expr = Expr(:tuple)
    for (i, subtype) in enumerate(T.types)
        push!(expr.args, _reconstruct(subtype, Expr(:ref, path, 1), counter))
    end
    expr
end
_reconstruct(T::TypeVar, path, counter) = construct_element(counter)
_reconstruct(::Type{Any}, path, counter) = construct_element(counter)
_reconstruct(::Type{T}, path, counter) where T <: Number = construct_element(counter)
_reconstruct(::Type{T}, path, counter) where T <: Unitful.Quantity =
    Expr(:call, T, construct_element(counter))

function construct_element(counter)
    expr = Expr(:ref, :data, counter.value)
    counter.value += 1
    expr
end

function construct_inner(::Type{T}, data) where T
    _construct(T, Counter())
end

@generated function construct(::Type{T}, data) where T
    construct_inner(T, Counter())
end

function reconstruct_inner(::Type{T}, data) where T
    _reconstruct(T, :original, Counter())
end

@generated function reconstruct(original::T, data) where T
    reconstruct_inner(T, Counter())
end

function wrap(func, InputType)
	x -> flatten(Vector, func(construct(InputType, x)))
end

end # module
