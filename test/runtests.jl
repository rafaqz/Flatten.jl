using Flatten
using Base.Test

type Foo{T}
    a::T
    b::T
    c::T
end

type Nested{T1, T2}
    f::Foo{T1}
    b::T2
    c::T2
end

foo = Foo(1.0, 2.0, 3.0)
nested = Nested(Foo(1,2,3), 4.0, 5.0)

@test to_vector(from_vector(Foo, to_vector(foo))) == to_vector(foo)
@test to_tuple(from_tuple(Foo, to_tuple(foo))) == to_tuple(foo)
@test to_tuple(Nested(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test to_tuple((Nested(Foo(1,2,3),4,5), Nested(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test to_tuple(Nested(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)
@test to_vector(Foo(1,2,3)) == Int[1,2,3]
@test typeof(to_vector(Foo(1,2,3))) == Array{Int, 1}

# Test nested types and tuples
@test to_vector((Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test typeof(to_vector((Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10)))) == Array{Float64, 1}
@test to_tuple((Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test to_tuple(from_tuple(Nested, to_tuple(nested))) == to_tuple(nested)
@test to_vector(from_vector(Nested, to_vector(nested))) == to_vector(nested)
@test to_tuple(from_tuple(Tuple{Nested, Nested}, to_tuple((nested, nested)))) == to_tuple((nested, nested))

# Test non-parametric types
type AnyPoint
    x
    y
end
@test to_tuple(AnyPoint(1,2)) == (1,2)
@test to_tuple(from_tuple(AnyPoint, (1,2))) == (1,2)

# Test function wrapping
type Point
	x
	y
end

function distance(p::Point)
	sqrt(p.x^2 + p.y^2)
end

wrapped_distance = wrap(distance, Point)
@test wrapped_distance([1,2]) == [norm([1,2])]

# Test performance
function to_vector_naive(obj)
    v = Array(Float64, length(fieldnames(obj)))
    for (i, field) in enumerate(fieldnames(obj))
        v[i] = getfield(obj, field)
    end
    v
end

function to_tuple_naive(obj)
    v = (map(field -> getfield(obj, field), fieldnames(obj))...)
end

function from_vector_naive(T, data)
    T(data...)
end

@test to_vector_naive(foo) == to_vector(foo)
@test to_tuple_naive(foo) == to_tuple(foo)

function test_to_vector()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e3
        data = to_vector(foo)
    end
end

function test_to_vector_naive()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e3
        data = to_vector_naive(foo)
    end
end

function test_to_tuple()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e3
        data = to_tuple(foo)
    end
end

function test_to_tuple_naive()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e3
        data = to_tuple_naive(foo)
    end
end

function test_from_vector()
    foo = Foo(1.0, 2.0, 3.0)
    data = to_vector(foo)
    for i = 1:1e3
        foo2 = from_vector(Foo, data)
    end
end

function test_from_vector_naive()
    foo = Foo(1.0, 2.0, 3.0)
    data = to_vector(foo)
    for i = 1:1e3
        foo2 = from_vector_naive(Foo, data)
    end
end

gc_enable(false)
println("to vector")
test_to_vector()
@time test_to_vector()
println("to vector naive")
test_to_vector_naive()
@time test_to_vector_naive()
println("to tuple")
test_to_tuple()
@time test_to_tuple()
println("to tuple naive")
test_to_tuple_naive()
@time test_to_tuple_naive()
println("from vector")
test_from_vector()
@time test_from_vector()
println("from vector naive")
test_from_vector_naive()
@time test_from_vector_naive()
gc_enable(true)

