using Revise
using Flatten, BenchmarkTools, MetaFields
import Flatten: flattenable

struct Foo{T}
    a::T
    b::T
    c::T
end

struct Nest{T1, T2}
    nf::Foo{T1}
    nb::T2
    nc::T2
end

struct NestTuple{T1, T2, T3, T4}
    nf::Tuple{Foo{T1},Nest{T2,T3}}
    nb::T4
    nc::T4
end


using Flatten
using Base.Test

foo = Foo(1.0, 2.0, 3.0)
nest = Nest(Foo(1,2,3), 4.0, 5.0)
nesttuple = NestTuple((foo, nest), 9, 10)

@test flatten(Vector, Foo(1,2,3)) == Int[1,2,3]
@test typeof(flatten(Vector, Foo(1,2,3))) == Array{Int, 1}
@test flatten(Tuple, Nest(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten(Tuple, (Nest(Foo(1,2,3),4,5), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Tuple, Nest(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)

# @test Flatten.flatten_inner(typeof(Nest(Foo(1,2,3), (4,5), (6,7))))

@test flatten(Vector, construct(Foo{Float64}, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, construct(Foo{Float64}, flatten(Tuple, foo))) == flatten(Tuple, foo)
@test flatten(Vector, reconstruct(foo, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, reconstruct(foo, flatten(Tuple, foo))) == flatten(Tuple, foo)
# Test nested types and tuples
@test flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test typeof(flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10)))) == Array{Float64, 1}
@test flatten(Tuple, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test flatten(Tuple, construct(Nest{Int,Float64}, flatten(Tuple, nest))) == flatten(Tuple, nest)
@test flatten(Tuple, reconstruct(nest, flatten(Tuple, nest))) == flatten(Tuple, nest)
@test flatten(Vector, construct(Nest{Int,Float64}, flatten(Vector, nest))) == flatten(Vector, nest)
@test flatten(Vector, reconstruct(nest, flatten(Vector, nest))) == flatten(Vector, nest)
@test flatten(Tuple, construct(Tuple{Nest{Int,Float64}, Nest{Int,Float64}}, flatten(Tuple, (nest, nest)))) == flatten(Tuple, (nest, nest))
@test flatten(Tuple, reconstruct((nest, nest), flatten(Tuple, (nest, nest)))) == flatten(Tuple, (nest, nest))

@test flatten(Tuple, reconstruct(nesttuple, flatten(Tuple, nesttuple))) == flatten(Tuple, nesttuple)


@metafield foobar :nobar

@flattenable @foobar struct Partial{T}
    " Field a"
    a::T | :foo | Include()
    " Field b"
    b::T | :foo | Include()
    " Field c"
    c::T | :foo | Exclude()
end

@flattenable @foobar struct NestedPartial{P,T}
    " Field np"
    np::P | :bar | Include()
    " Field nb"
    nb::T | :bar | Include()
    " Field nc"
    nc::T | :bar | Exclude()
end

# Partial fields with @flattenable
partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5) 
Flatten.flatten_inner(typeof(nestedpartial))
@test flatten(Vector, nestedpartial) == [1.0, 2.0, 4.0]
@test flatten(Tuple, nestedpartial) === (1.0, 2.0, 4)
# It's not clear if this should actually work or not.
# I may just be that fields sharing a type both need to be Include() or Exclude()
# And mixing is disallowed, as dealing with the conversions will be difficult.
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flattenable(nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

Flatten.metaflatten_inner(typeof(foo))

@test metaflatten(partial, foobar) == (:foo, :foo)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo, :bar)
@test metaflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Tuple, (nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Vector, (nestedpartial, partial), foobar) == [:foo, :foo, :bar, :foo, :foo]
@test metaflatten(Vector, (nestedpartial, partial), fieldname_meta) == [:a, :b, :nb, :a, :b]
@test metaflatten(Vector, (nestedpartial, partial), fieldparenttype_meta) == DataType[Partial{Float64}, Partial{Float64}, NestedPartial{Partial{Float64},Int64}, Partial{Float64}, Partial{Float64}]
@test metaflatten(Vector, (nestedpartial, partial), fieldparent_meta) == Symbol[:Partial, :Partial, :NestedPartial, :Partial, :Partial]
@test metaflatten(Vector, (nestedpartial, partial), fieldtype_meta) == [Float64, Float64, Int64, Float64, Float64]

@flattenable @foobar struct Partial{T}
    a::T | :bar | Exclude()
    b::T | :bar | Exclude()
    c::T | :foo | Include()   
end

@flattenable @foobar struct NestedPartial{P,T}
    nb::T | :bar | Exclude() 
    nc::T | :foo | Include()    
end

# Test with changed fields
@test flatten(Vector, nestedpartial) == [3.0, 5.0]
@test flatten(Tuple, nestedpartial) == (3.0, 5.0)
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
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

@test metaflatten(foo, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include())
@test metaflatten(nest, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include())
@test metaflatten(partial, foobar) == (:foo,)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo)

@test metaflatten(foo, fieldname_meta) == (:a, :b, :c)
@test metaflatten(nest, fieldname_meta) == (:a, :b, :c, :nb, :nc)
@test metaflatten(nestedpartial, fieldname_meta) == (:c, :nc)

# In another module
module TestModule

using Flatten
import Flatten.flattenable

export TestStruct

@flattenable struct TestStruct{A,B}
    a::A | Include()
    b::B | Exclude()
end

TestStruct(; a = 8, b = 9.0) = TestStruct(a, b)

end

using TestModule

@test flatten(TestStruct(1, 2)) == (1,)
@test flatten(TestStruct()) == (8,)


##############################################################################
# Benchmarks

function flatten_naive_vector(obj)
    v = Vector{Float64}(length(fieldnames(obj)))
    for (i, field) in enumerate(fieldnames(obj))
        v[i] = getfield(obj, field)
    end
    v
end

function flatten_naive_tuple(obj)
    v = (map(field -> getfield(obj, field), fieldnames(obj))...)
end

function construct_vector_naive(T, data)
    T(data...)
end

@test flatten_naive_vector(foo) == flatten(Vector, foo)
@test flatten_naive_tuple(foo) == flatten(Tuple, foo)

foo = Foo(1.0, 2.0, 3.0)
data = flatten(Vector, foo)

print("flatten to vector: ")
@btime flatten(Vector, $foo)
print("flatten to vector naive: ")
@btime flatten_naive_vector($foo)
print("flatten to tuple: ")
@btime flatten(Tuple, $foo)
print("flatten to tuple naive: ")
@btime flatten_naive_tuple($foo)

print("construct vector: ")
@btime construct(Foo{Float64}, $data)
print("reconstruct vector: ")
@btime reconstruct($foo, $data)
print("reconstruc vector naive: ")
@btime construct_vector_naive(Foo{Float64}, $data)
