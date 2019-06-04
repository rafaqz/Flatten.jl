using Flatten, BenchmarkTools, FieldMetadata, Test
import Flatten: flattenable

struct Foo{A,B,C}
    a::A
    b::B
    c::C
end

struct Nest{F,B,C}
    nb::B
    nf::F
    nc::C
end

mutable struct MuFoo{A,B,C}
    a::A
    b::B
    c::C
end

mutable struct MuNest{F,B,C}
    nf::F
    nb::B
    nc::C
end

foo = Foo(1.0, 2.0, 3.0)
nest = Nest(Foo(1,2,3), 4.0, 5.0f0)
nesttuple = Nest((foo, nest), 9, 10)

# Flatten to specific types
@test flatten(nest, Int) == (1, 2, 3)
@test flatten(nest, AbstractFloat) == (4.0, 5.0f0)
@test flatten(nest, Number, Float32) == (1, 2, 3, 4.0)

@test flatten(Foo(1, 2, "3"), String, Nothing) === ("3",)

# Test flattening

@test flatten(Foo(1,2,3)) == (1,2,3)
@test flatten(((1,2,3), (4,5))) == (1,2,3,4,5)
@test flatten(Nest(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten((Nest(Foo(1,2,3),4,5), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Nest(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)
@test flatten((Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)

# Test reconstruction
@test typeof(reconstruct(foo, flatten(foo))) == typeof(foo)
@test typeof(reconstruct(nest, flatten(nest))) == typeof(nest)

@test flatten(reconstruct(foo, flatten(foo))) == flatten(foo)
@test flatten(reconstruct(nest, flatten(nest))) == flatten(nest)
@test flatten(reconstruct((nest, nest), flatten((nest, nest)))) == flatten((nest, nest))
@test flatten(reconstruct(nesttuple, flatten(nesttuple))) == flatten(nesttuple)

@test flatten(reconstruct(foo, flatten(foo, Real)), Real) == flatten(foo, Real)
foo2 = Foo(1, "two", :three)
@test flatten(reconstruct(foo2, flatten(foo2, String, Real), String, Real), String, Real) == flatten(foo2, String, Real)

# Test updating mutable structs
mufoo = MuFoo(1.0, 2.0, 3.0)

munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(mufoo, flatten(mufoo) .* 7)) == (7.0, 14.0, 21.0)
@test flatten(update!(munest, flatten(munest) .* 7)) == (7, 14, 21, 28.0, 35.0)

munesttuple = MuNest((MuFoo(1.0, 2.0, 3.0), MuNest(MuFoo(1,2,3), 4.0, 5.0)), 9, 10)
@test flatten(update!(munesttuple, flatten(munesttuple) .* 7)) == (7.0, 14.0, 21.0, 7, 14, 21, 28.0, 35.0, 63, 70)

# Test retyping
@test typeof(reconstruct(foo, round.(Int, flatten(foo))).a) == Int
@test flatten(reconstruct(nesttuple, round.(Int, flatten(nesttuple)))) == round.(Int, flatten(nesttuple))


# Partial fields with @flattenable

@metadata foobar :nobar

@flattenable @foobar struct Partial{A,B,C}
    " Field a"
    a::A | :foo | true
    " Field b"
    b::B | :foo | true
    " Field c"
    c::C | :foo | false
end

@flattenable @foobar struct NestedPartial{P,B,C}
    " Field np"
    np::P | :bar | true
    " Field nb"
    nb::B | :bar | true
    " Field nc"
    nc::C | :bar | false
end

partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5) 
@test flatten(nestedpartial) === (1.0, 2.0, 4)

@test flatten(reconstruct(nestedpartial, flatten(nestedpartial))) == flatten(nestedpartial)

# Partial fields with custom field traits

@metadata flattenable2 true

@reflattenable2 struct Partial
    a::A | false
    b::B | false
    c::C | true
end

@reflattenable2 struct NestedPartial
    np::P | false
    nb::B | true
    nc::C | false
end

@test flatten(nestedpartial, flattenable2) === (4,)
@test flatten(reconstruct(nestedpartial, flatten(nestedpartial, flattenable2), flattenable2), flattenable2) == flatten(nestedpartial, flattenable2)


# Tag flattening
@test metaflatten(partial, foobar) == (:foo, :foo)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo, :bar)
@test metaflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test metaflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test fieldtypeflatten((nestedpartial, partial)) == (Float64, Float64, Int, Float64, Float64)
@test parenttypeflatten(nestedpartial) == 
    (Partial{Float64,Float64,Float64}, Partial{Float64,Float64,Float64}, 
     NestedPartial{Partial{Float64,Float64,Float64},Int,Int})
@test parentflatten(nestedpartial) == (:Partial, :Partial, :NestedPartial)


# Updating metadata updates flattened fields
@reflattenable @refoobar struct Partial
    a | :bar | false
    b | :bar | false
    c | :foo | true
end

@reflattenable @refoobar struct NestedPartial
    nf | true
    nb | :bar | false 
    nc | :foo | true
end

@reflattenable mutable struct MuFoo
    a | false
    b | true
    c | false
end

@reflattenable mutable struct MuNest
    nf | true
    nb | true
    nc | false
end

@test flatten(nestedpartial) == (3.0, 5.0)
@test flatten(reconstruct(nestedpartial, flatten(nestedpartial))) == flatten(nestedpartial)
@inferred flatten(reconstruct(nestedpartial, flatten(nestedpartial)))


@test metaflatten(foo, flattenable) == (true, true, true)
@test metaflatten(nest, flattenable) == (true, true, true, true, true)
@test metaflatten(partial, foobar) == (:foo,)
@test metaflatten(nestedpartial, foobar) == (:foo, :foo)

@test fieldnameflatten(foo) == (:a, :b, :c)
@test fieldnameflatten(nest) == (:a, :b, :c, :nf, :nc)
@test fieldnameflatten(nestedpartial) == (:c, :nc)

# Updating mutables
mufoo = MuFoo(1.0, 2.0, 3.0)
munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(mufoo, flatten(mufoo) .* 7)) == (14.0,)
@test flatten(update!(munest, flatten(munest) .* 7)) == (14, 28.0)

# Test non-parametric types
mutable struct AnyPoint
    x
    y
end
anypoint = AnyPoint(1,2)
@test flatten(anypoint) == (1,2)
@test flatten(reconstruct(anypoint, (1,2))) == (1,2)


# With void
nestvoid = Nest(Foo(1,2,3), nothing, nothing)
munestvoid = MuNest(MuFoo(1,2,3), nothing, nothing)
@test flatten(nestvoid) == (1,2,3)
@test flatten((Nest(Foo(1,2,3), nothing, nothing), Nest(Foo(nothing, nothing, nothing), 9, 10))) == (1,2,3,9,10)
@test flatten(reconstruct(nestvoid, flatten(nestvoid))) == flatten(nestvoid) 
@test flatten(update!(munestvoid, flatten(munestvoid))) == flatten(munestvoid) 


# Test unit stripping functions

# ufoo = Foo(1.0u"m", 2.0u"g", 3.0)
# unest = Nest(Foo(1u"m",2u"g",3), 4.0, 5.0u"kPa")
# unesttuple = Nest((ufoo, unest), 9, 10u"mol*L^-1")

# @test ulflatten(ufoo) === (1.0,2.0,3.0)
# @test ulflatten(unest) === (1,2,3,4.0,5.0)

# @test ulflatten(ulreconstruct(ufoo, ulflatten(ufoo))) === ulflatten(ufoo)

# umufoo = MuFoo(1.0u"g", 2.0u"kPa", 3.0)
# @test ulflatten(ulupdate!(umufoo, ulflatten(umufoo) .* 7)) == (14.0,)
# umunest = MuNest(MuFoo(1u"s",2u"kg",3), 4.0, 5.0u"K")
# @test ulflatten(ulupdate!(umunest, ulflatten(umunest) .* 7)) == (14, 28.0)

# # With void
# unestvoid = Nest(Foo(1u"g",2,3), nothing, nothing)
# umunestvoid = MuNest(MuFoo(1u"g",2,3), nothing, nothing)
# @test ulflatten(unestvoid) == (1,2,3)
# @test ulflatten((Nest(Foo(1u"g",2,3), nothing, nothing), Nest(Foo(nothing, nothing, nothing), 9, 10))) == (1,2,3,9,10)
# @test ulflatten(ulreconstruct(unestvoid, ulflatten(unestvoid))) == ulflatten(unestvoid) 
# @test ulflatten(ulupdate!(umunestvoid, ulflatten(umunestvoid))) == ulflatten(umunestvoid) 



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

@test flatten_naive_vector(foo) == [flatten(foo)...]
@test flatten_naive_tuple(foo) == flatten(foo)

foo = Foo(1.0, 2.0, 3.0)
datavector = [flatten(foo)...]
datatuple = flatten(foo)

print("flatten to vector: ")
@btime [flatten($foo)...]
print("flatten to vector naive: ")
@btime flatten_naive_vector($foo)
print("flatten to tuple: ")
@btime flatten($foo)
print("flatten to tuple naive: ")
@btime flatten_naive_tuple($foo)
print("reconstruct vector: ")
@btime reconstruct($foo, $datavector)
print("reconstruct vector naive: ")
@btime construct_vector_naive(Foo{Float64,Float64,Float64}, $datavector)
