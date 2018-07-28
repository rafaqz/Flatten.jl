using Revise
using Flattenable
import Flattenable: flattenable

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

@flattenable struct Partial{T}
    a::T | Flat()
    b::T | Flat()
    c::T | NotFlat()
end

@flattenable struct NestedPartial{P,T}
    p::P | Flat()
    b::T | Flat()
    c::T | NotFlat()
end


using Flatten
using Base.Test

foo = Foo(1.0, 2.0, 3.0)
nested = Nested(Foo(1,2,3), 4.0, 5.0)

@test flatten(Vector, Foo(1,2,3)) == Int[1,2,3]
@test typeof(flatten(Vector, Foo(1,2,3))) == Array{Int, 1}
@test flatten(Tuple, Nested(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten(Tuple, (Nested(Foo(1,2,3),4,5), Nested(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Tuple, Nested(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)

@test flatten(Vector, construct(Foo{Float64}, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, construct(Foo{Float64}, flatten(Tuple, foo))) == flatten(Tuple, foo)
@test flatten(Vector, reconstruct(foo, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, reconstruct(foo, flatten(Tuple, foo))) == flatten(Tuple, foo)
reconstruct(foo, [5.0, 5.0, 5.0])

# Test nested types and tuples
@test flatten(Vector, (Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test typeof(flatten(Vector, (Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10)))) == Array{Float64, 1}
@test flatten(Tuple, (Nested(Foo(1,2,3),4.0,5.0), Nested(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test flatten(Tuple, construct(Nested{Int,Float64}, flatten(Tuple, nested))) == flatten(Tuple, nested)
@test flatten(Tuple, reconstruct(nested, flatten(Tuple, nested))) == flatten(Tuple, nested)
@test flatten(Vector, construct(Nested{Int,Float64}, flatten(Vector, nested))) == flatten(Vector, nested)
@test flatten(Vector, reconstruct(nested, flatten(Vector, nested))) == flatten(Vector, nested)
@test flatten(Tuple, construct(Tuple{Nested{Int,Float64}, Nested{Int,Float64}}, flatten(Tuple, (nested, nested)))) == flatten(Tuple, (nested, nested))
@test flatten(Tuple, reconstruct((nested, nested), flatten(Tuple, (nested, nested)))) == flatten(Tuple, (nested, nested))

# Partial fields with @flattenable
partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4.0, 5.0) 
@test flatten(Vector, nestedpartial) == [1.0, 2.0, 4.0]
@test flatten(Tuple, nestedpartial) == (1.0, 2.0, 4.0)
@test flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

@flattenable struct Partial{T}
    a::T | NotFlat()
    b::T | NotFlat()
    c::T | Flat()
end

@flattenable struct NestedPartial{P,T}
    p::P | Flat()
    b::T | NotFlat()
    c::T | Flat()
end

# Test with changed fields
@test flatten(Vector, nestedpartial) == [3.0, 5.0]
@test flatten(Tuple, nestedpartial) == (3.0, 5.0)
@test flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

# Test non-parametric types
type AnyPoint
    x
    y
end
anypoint = AnyPoint(1,2)
@test flatten(Tuple, anypoint) == (1,2)
@test flatten(Tuple, construct(AnyPoint, (1,2))) == (1,2)
@test flatten(Tuple, reconstruct(anypoint, (1,2))) == (1,2)


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
    v = Vector{Float64}(length(fieldnames(obj)))
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

@test to_vector_naive(foo) == flatten(Vector,foo)
@test to_tuple_naive(foo) == flatten(Tuple, foo)

function test_to_vector()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e3
        data = flatten(Vector, foo)
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
        data = flatten(Tuple, foo)
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
    data = flatten(Vector, foo)
    for i = 1:1e3
        foo2 = construct(Foo{Float64}, data)
    end
end

function test_from_vector_naive()
    foo = Foo(1.0, 2.0, 3.0)
    data = flatten(Vector, foo)
    for i = 1:1e3
        foo2 = from_vector_naive(Foo, data)
    end
end

gc_enable(false)
println("flatten to vector")
test_to_vector()
@time test_to_vector()
println("flatten to vector naive")
test_to_vector_naive()
@time test_to_vector_naive()
println("flatten to tuple")
test_to_tuple()
@time test_to_tuple()
println("flatten to tuple naive")
test_to_tuple_naive()
@time test_to_tuple_naive()
println("reconstruct vector")
test_from_vector()
@time test_from_vector()
println("reconstruc vector naive")
test_from_vector_naive()
@time test_from_vector_naive()
gc_enable(true)

