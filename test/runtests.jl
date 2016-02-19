using Flatten
using Base.Test

type Foo{T}
    a::T
    b::T
    c::T
end

type Nested{T}
    f::Foo{T}
    b::T
    c::T
end

foo = Foo(1.0, 2.0, 3.0)
@test to_vector(from_vector(Foo, to_vector(foo))) == to_vector(foo)
@test to_tuple(from_tuple(Foo, to_tuple(foo))) == to_tuple(foo)
@test to_tuple(Nested(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test to_tuple((Nested(Foo(1,2,3),4,5), Nested(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)

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
    for i = 1:1e5
        data = to_vector(foo)
    end
end

function test_to_vector_naive()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e5
        data = to_vector_naive(foo)
    end
end

function test_to_tuple()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e5
        data = to_tuple(foo)
    end
end

function test_to_tuple_naive()
    foo = Foo(1.0, 2.0, 3.0)
    for i = 1:1e5
        data = to_tuple_naive(foo)
    end
end

function test_from_vector()
    foo = Foo(1.0, 2.0, 3.0)
    data = to_vector(foo)
    for i = 1:1e5
        foo2 = from_vector(Foo, data)
    end
end

function test_from_vector_naive()
    foo = Foo(1.0, 2.0, 3.0)
    data = to_vector(foo)
    for i = 1:1e5
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
