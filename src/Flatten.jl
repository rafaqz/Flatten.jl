module Flatten

export to_tuple, to_vector, from_tuple, from_vector

function field_expressions(T, expr::Union{Expr, Symbol})
    expressions = Expr[]
    for (i, field) in enumerate(fieldnames(T))
        field_expr = Expr(:., expr, Expr(:quote, field))
        append!(expressions, field_expressions(fieldtype(T, i), field_expr))
    end
    expressions
end

field_expressions{T2 <: AbstractArray}(T::Type{T2}, expr::Union{Expr, Symbol}) = error("Cannot flatten variable-length objects like arrays. Replace any arrays with tuples if possible.")

function field_expressions{T2 <: Tuple}(T::Type{T2}, expr::Union{Expr, Symbol})
    expressions = Expr[]
    for i in 1:length(T.types)
        field_expr = Expr(:ref, expr, i)
        append!(expressions, field_expressions(fieldtype(T, i), field_expr))
    end
    expressions
end

function field_expressions{T2 <: Number}(T::Type{T2}, expr::Union{Expr, Symbol})
    [expr]
end

function to_tuple_internal(T)
    expr = Expr(:tuple)
    append!(expr.args, field_expressions(T, :(T)))
    expr
end

@generated function to_tuple(T)
    to_tuple_internal(T)
end

function all_field_types(T)
    field_types = DataType[]
    for i in 1:length(fieldnames(T))
        append!(field_types, all_field_types(fieldtype(T, i)))
    end
    field_types
end

function all_field_types{T2 <: Number}(T::Type{T2})
    [T]
end

function all_field_types{T2 <: Tuple}(T::Type{T2})
    field_types = DataType[]
    for i in 1:length(T.types)
        append!(field_types, all_field_types(T.types[i]))
    end
    field_types
end

function to_vector_internal(T)
    field_types = all_field_types(T)
    num_elements = length(field_types)
    element_type = reduce(promote_type, field_types)
    expr = quote
        v = Array{$(element_type)}($(num_elements))
    end
    for (i, field_expr) in enumerate(field_expressions(T, :(T)))
        push!(expr.args, Expr(:(=), Expr(:ref, :v, i), field_expr))
    end
    push!(expr.args, :v)
    return expr
end

@generated function to_vector(T)
    to_vector_internal(T)
end

type Counter
    value::Int

    Counter() = new(1)
end

function construct(T, counter)
    expr = Expr(:call, T)
    for subtype in T.types
        push!(expr.args, construct(subtype, counter))
        # push!(expr.args, :(data[$(i)]))
    end
    expr
end

function construct(T::TypeVar, counter)
    expr = Expr(:ref, :data, counter.value)
    counter.value += 1
    expr
end

function construct{T <: Number}(::Type{T}, counter)
    expr = Expr(:ref, :data, counter.value)
    counter.value += 1
    expr
end


function from_tuple_internal(T, data)
    construct(T, Counter())
end

@generated function from_tuple{T}(::Type{T}, data)
    from_tuple_internal(T, data)
end

from_vector(T, data) = from_tuple(T, data)

end # module
