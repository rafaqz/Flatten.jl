using Flatten, BenchmarkTools, FieldMetadata, Test
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

mutable struct MuFoo{T}
    a::T
    b::T
    c::T
end

mutable struct MuNest{T1, T2}
    nf::MuFoo{T1}
    nb::T2
    nc::T2
end


foo = Foo(1.0, 2.0, 3.0)
nest = Nest(Foo(1,2,3), 4.0, 5.0)
nesttuple = NestTuple((foo, nest), 9, 10)

@test flatten(Vector, Foo(1,2,3)) == Int[1,2,3]
@test typeof(flatten(Vector, Foo(1,2,3))) == Array{Int, 1}
@test flatten(Tuple, Foo(1,2,3)) == (1,2,3)
@test flatten(Tuple, ((1,2,3), (4,5))) == (1,2,3,4,5)
@test flatten(Tuple, Nest(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten((Nest(Foo(1,2,3),4,5), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Nest(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)

@test flatten(Vector, reconstruct(foo, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, reconstruct(foo, flatten(Tuple, foo))) == flatten(Tuple, foo)

mufoo = MuFoo(1.0, 2.0, 3.0)
@test flatten(Tuple, update!(mufoo, flatten(Tuple, mufoo) .* 7)) == (7.0, 14.0, 21.0)
munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(munest, flatten(munest) .* 7)) == (7, 14, 21, 28.0, 35.0)
Flatten.update_inner(typeof(munest))

# Test nested types and tuples
@test flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test flatten(Tuple, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test flatten(Tuple, reconstruct(nest, flatten(Tuple, nest))) == flatten(Tuple, nest)
@test flatten(reconstruct((nest, nest), flatten((nest, nest)))) == flatten((nest, nest))
@test flatten(reconstruct(nesttuple, flatten(nesttuple))) == flatten(nesttuple)

@test typeof(reconstruct(foo, flatten(Tuple, foo))) <: Foo
@test typeof(reconstruct(nest, flatten(Tuple, nest))) <: Nest

# Test retyping

@test typeof(retype(foo, round.(Int, flatten(foo))).a) == Int

# Partial fields with @flattenable

@metadata foobar :nobar

@flattenable @foobar struct Partial{T}
    " Field a"
    a::T | :foo | true
    " Field b"
    b::T | :foo | true
    " Field c"
    c::T | :foo | false
end

@flattenable @foobar struct NestedPartial{P,T}
    " Field np"
    np::P | :bar | true
    " Field nb"
    nb::T | :bar | true
    " Field nc"
    nc::T | :bar | false
end

partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5) 
Flatten.flatten_inner(typeof(nestedpartial))
@test flatten(Vector, nestedpartial) == [1.0, 2.0, 4.0]
@test flatten(Tuple, nestedpartial) === (1.0, 2.0, 4)

# It's not clear if this should actually work or not.
# It may just be that fields sharing a type both need to be true or false
# and mixing is disallowed for Vector.
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flattenable(nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

# Tag flattening
@test metaflatten(partial, foobar) == (:foo, :foo)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo, :bar)
@test metaflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Tuple, (nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Vector, (nestedpartial, partial), foobar) == [:foo, :foo, :bar, :foo, :foo]
@test fieldtypeflatten((nestedpartial, partial)) == (Float64, Float64, Int, Float64, Float64)
@test fieldnameflatten(Vector, (nestedpartial, partial)) == [:a, :b, :nb, :a, :b]
@test parenttypeflatten(nestedpartial) == (Partial{Float64}, Partial{Float64}, NestedPartial{Partial{Float64},Int})
@test parenttypeflatten(Vector, (nestedpartial, partial)) == DataType[Partial{Float64}, Partial{Float64}, NestedPartial{Partial{Float64},Int}, Partial{Float64}, Partial{Float64}]
@test parentflatten(nestedpartial) == (:Partial, :Partial, :NestedPartial)
@test parentflatten(Vector, (nestedpartial, partial)) == Symbol[:Partial, :Partial, :NestedPartial, :Partial, :Partial]


# Updating metadata updates flattened fields
@reflattenable @refoobar struct Partial{T}
    a::T | :bar | false
    b::T | :bar | false
    c::T | :foo | true
end

@reflattenable @refoobar struct NestedPartial{P,T}
    nb::T | :bar | false 
    nc::T | :foo | true
end

@reflattenable mutable struct MuFoo{T}
    a::T | false
    b::T | true
    c::T | false
end

@reflattenable mutable struct MuNest{T1, T2}
    nf::MuFoo{T1} | true
    nb::T2        | true
    nc::T2        | false
end

@test flatten(Vector, nestedpartial) == [3.0, 5.0]
@test flatten(Tuple, nestedpartial) == (3.0, 5.0)
@test flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)
@inferred flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial)))

@test metaflatten(foo, flattenable) == (true, true, true)
@test metaflatten(nest, flattenable) == (true, true, true, true, true)
@test metaflatten(partial, foobar) == (:foo,)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo)

@test fieldnameflatten(foo) == (:a, :b, :c)
@test fieldnameflatten(nest) == (:a, :b, :c, :nb, :nc)
@test fieldnameflatten(nestedpartial) == (:c, :nc)

mufoo = MuFoo(1.0, 2.0, 3.0)
munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(mufoo, flatten(Tuple, mufoo) .* 7)) == (14.0,)
@test flatten(update!(munest, flatten(munest) .* 7)) == (14, 28.0)

# Test non-parametric types
mutable struct AnyPoint
    x
    y
end
anypoint = AnyPoint(1,2)
@test flatten(Tuple, anypoint) == (1,2)
@test flatten(Tuple, reconstruct(anypoint, (1,2))) == (1,2)


# With void
nestvoid = Nest(Foo(1,2,3), nothing, nothing)
@test flatten(Tuple, nestvoid) == (1,2,3)
@test flatten(Tuple, (Nest(Foo(1,2,3), nothing, nothing), Nest(Foo(nothing, nothing, nothing), 9, 10))) == (1,2,3,9,10)
@test flatten(Tuple, reconstruct(nestvoid, flatten(Tuple, nestvoid))) == flatten(Tuple, nestvoid) 

##############################################################################
# Benchmarks

function flatten_naive_vector(obj)
    v = Vector(undef, length(fieldnames(typeof(obj))))
    for (i, field) in enumerate(fieldnames(typeof(obj)))
        v[i] = getfield(obj, field)
    end
    v
end

function flatten_naive_tuple(obj)
    v = (map(field -> getfield(obj, field), fieldnames(typeof(obj)))...,)
end

function construct_vector_naive(T, data)
    T(data...)
end

@test flatten_naive_vector(foo) == flatten(Vector, foo)
@test flatten_naive_tuple(foo) == flatten(Tuple, foo)

foo = Foo(1.0, 2.0, 3.0)
datavector = flatten(Vector, foo)
datatuple = flatten(Tuple, foo)

print("flatten to vector: ")
@btime flatten(Vector, $foo)
print("flatten to vector naive: ")
@btime flatten_naive_vector($foo)
print("flatten to tuple: ")
@btime flatten(Tuple, $foo)
print("flatten to tuple naive: ")
@btime flatten_naive_tuple($foo)
print("reconstruct vector: ")
@btime reconstruct($foo, $datavector)
print("reconstruct vector naive: ")
@btime construct_vector_naive(Foo{Float64}, $datavector)
