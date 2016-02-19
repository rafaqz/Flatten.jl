module Flatten

export to_tuple, to_vector, from_tuple, from_vector

@generated function to_tuple(T)
    to_tuple_internal(T)
end

function to_tuple_internal(T)
    expr = Expr(:tuple)
    append!(expr.args, to_tuple_impl(T, :(T)))
    expr
end

function to_tuple_impl(T, expr)
    expressions = Expr[]
    for (i, field) in enumerate(fieldnames(T))
        field_expr = Expr(:., expr, Expr(:quote, field))
        append!(expressions, to_tuple_impl(fieldtype(T, i), field_expr))
    end
    expressions
end

function to_tuple_impl{T2 <: Tuple}(T::Type{T2}, expr)
    expressions = Expr[]
    for i in 1:length(T.types)
        field_expr = Expr(:ref, expr, i)
        append!(expressions, to_tuple_impl(fieldtype(T, i), field_expr))
    end
    expressions
end

function to_tuple_impl{T2 <: Number}(T::Type{T2}, expr)
    [expr]
end

@generated function to_vector(T)
    element_type = reduce(promote_type, map(i -> fieldtype(T, i), 1:length(fieldnames(T))))
    expr = quote
        v = Array{$(element_type)}($(length(fieldnames(T))))
    end
    for (i, field) in enumerate(fieldnames(T))
        push!(expr.args, :(v[$(i)] = T.$(field)))
    end
    push!(expr.args, :v)
    return expr
end

from_vector(T, data) = from_tuple(T, data)

@generated function from_tuple{T}(::Type{T}, data)
    expr = Expr(:call, :T)
    for (i, field) in enumerate(fieldnames(T))
        push!(expr.args, :(data[$(i)]))
    end
    return expr
end

end # module
