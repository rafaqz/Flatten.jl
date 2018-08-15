using Flatten, BenchmarkTools, MetaFields, Unitful, Base.Test
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
@test flatten(Tuple, Nest(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten(Tuple, (Nest(Foo(1,2,3),4,5), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Tuple, Nest(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)

@test flatten(Vector, reconstruct(foo, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, reconstruct(foo, flatten(Tuple, foo))) == flatten(Tuple, foo)

mufoo = MuFoo(1.0, 2.0, 3.0)
@test flatten(Vector, update!(mufoo, flatten(Vector, mufoo) .* 7)) == [7.0, 14.0, 21.0]
mufoo = MuFoo(1.0, 2.0, 3.0)
@test flatten(Tuple, update!(mufoo, flatten(Tuple, mufoo) .* 7)) == (7.0, 14.0, 21.0)
munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(munest, flatten(munest) .* 7)) == (7.0, 14.0, 21.0, 28.0, 35.0)

# Test nested types and tuples
@test flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test typeof(flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10)))) == Array{Float64, 1}
@test flatten(Tuple, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test flatten(Tuple, reconstruct(nest, flatten(Tuple, nest))) == flatten(Tuple, nest)
@test flatten(Vector, reconstruct(nest, flatten(Vector, nest))) == flatten(Vector, nest)
@test flatten(Tuple, reconstruct((nest, nest), flatten(Tuple, (nest, nest)))) == flatten(Tuple, (nest, nest))
@test flatten(Tuple, reconstruct(nesttuple, flatten(Tuple, nesttuple))) == flatten(Tuple, nesttuple)

@test typeof(reconstruct(foo, flatten(Tuple, foo))) <: Foo
@test typeof(reconstruct(nest, flatten(Tuple, nest))) <: Nest


# Partial fields with @flattenable

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

partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5) 
Flatten.flatten_inner(typeof(nestedpartial))
@test flatten(Vector, nestedpartial) == [1.0, 2.0, 4.0]
@test flatten(Tuple, nestedpartial) === (1.0, 2.0, 4)
# It's not clear if this should actually work or not.
# It may just be that fields sharing a type both need to be Include() or Exclude()
# and mixing is disallowed for Vector.
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flattenable(nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)


# Metaflattening
@test metaflatten(partial, foobar) == (:foo, :foo)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo, :bar)
@test metaflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Tuple, (nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten(Vector, (nestedpartial, partial), foobar) == [:foo, :foo, :bar, :foo, :foo]
@test metaflatten(Vector, (nestedpartial, partial), fieldname_meta) == [:a, :b, :nb, :a, :b]
@test metaflatten(Vector, (nestedpartial, partial), fieldparenttype_meta) == DataType[Partial{Float64}, Partial{Float64}, NestedPartial{Partial{Float64},Int64}, Partial{Float64}, Partial{Float64}]
@test metaflatten(Vector, (nestedpartial, partial), fieldparent_meta) == Symbol[:Partial, :Partial, :NestedPartial, :Partial, :Partial]
@test metaflatten(Vector, (nestedpartial, partial), fieldtype_meta) == [Float64, Float64, Int64, Float64, Float64]


# Updating metafields updates flattened fields
@flattenable @foobar struct Partial{T}
    a::T | :bar | Exclude()
    b::T | :bar | Exclude()
    c::T | :foo | Include()   
end

@flattenable @foobar struct NestedPartial{P,T}
    nb::T | :bar | Exclude() 
    nc::T | :foo | Include()    
end

@test flatten(Vector, nestedpartial) == [3.0, 5.0]
@test flatten(Tuple, nestedpartial) == (3.0, 5.0)
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)
@inferred flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial)))

@test metaflatten(foo, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include())
@test metaflatten(nest, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include())
@test metaflatten(partial, foobar) == (:foo,)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo)

@test metaflatten(foo, fieldname_meta) == (:a, :b, :c)
@test metaflatten(nest, fieldname_meta) == (:a, :b, :c, :nb, :nc)
@test metaflatten(nestedpartial, fieldname_meta) == (:c, :nc)


# Test non-parametric types
type AnyPoint
    x
    y
end
anypoint = AnyPoint(1,2)
@test flatten(Tuple, anypoint) == (1,2)
@test flatten(Tuple, reconstruct(anypoint, (1,2))) == (1,2)

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


# With units
partialunits = Partial(1.0u"s", 2.0u"s", 3.0u"s")
nestedunits = NestedPartial(Partial(1.0u"km", 2.0u"km", 3.0u"km"), 4.0u"g", 5.0u"g") 
@test flatten(Vector, partialunits) == [3.0]
@test flatten(Vector, reconstruct(partialunits, flatten(Vector, partialunits))) == flatten(Vector, partialunits)
@test flatten(Tuple, reconstruct(partialunits, flatten(Tuple, partialunits))) == flatten(Tuple, partialunits)
@test flatten(Vector, reconstruct(nestedunits, flatten(Vector, nestedunits))) == flatten(Vector, nestedunits)
@test flatten(Tuple, reconstruct(nestedunits, flatten(Tuple, nestedunits))) == flatten(Tuple, nestedunits)
@inferred flatten(Tuple, reconstruct(nestedunits, flatten(Tuple, nestedunits))) == flatten(Tuple, nestedunits)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

# With void
nestvoid = Nest(Foo(1,2,3), nothing, nothing)
@test flatten(Tuple, nestvoid) == (1,2,3)
@test flatten(Tuple, (Nest(Foo(1,2,3), nothing, nothing), Nest(Foo(nothing, nothing, nothing), 9, 10))) == (1,2,3,9,10)
@test flatten(Tuple, reconstruct(nestvoid, flatten(Tuple, nestvoid))) == flatten(Tuple, nestvoid) 

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
