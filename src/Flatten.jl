module Flatten

export to_tuple, to_vector, from_tuple, from_vector

@generated function to_tuple(T)
    expr = Expr(:tuple)
    for (i, field) in enumerate(fieldnames(T))
        push!(expr.args, :(T.$(field)))
    end
    return expr
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
