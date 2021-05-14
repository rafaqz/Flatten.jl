var documenterSearchIndex = {"docs":
[{"location":"#Flatten.jl","page":"Flatten.jl","title":"Flatten.jl","text":"","category":"section"},{"location":"","page":"Flatten.jl","title":"Flatten.jl","text":"Modules = [Flatten]","category":"page"},{"location":"#Flatten.Flatten","page":"Flatten.jl","title":"Flatten.Flatten","text":"Flatten\n\n(Image: ) (Image: ) (Image: Build Status) (Image: codecov.io) (Image: Coverage Status)\n\nFlatten.jl converts data from arbitrary nested structs to tuples, using flatten(), and rebuilds them using reconstruct(), update!().  modify() combines flatten and reconstruct with a function application to each element of the intermediate tuple. \n\nThis facilitates building modular, composable structs that can be queries, modified and rebuilt based on the types of their fields, without knowing field locations.\n\nIt also allows access to solvers and optimisers that require flat lists of parameters.  Importantly, it's type-stable and very fast. It does not flatten the contents of Array or Dict (which is a container of Arrays), where the number of values are not known at compile time. \n\nFlatten is also flexible. The types to return and ignore can be specified, and individual fields can be ignored using field-level traits like flattenable from FieldMetadata.jl. Method overrides can also be defined for custom types.\n\nType queries\n\nFlatten allows a kind of querying to extract some types and ignore others, here using flatten:\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> struct Bar{X}\n           x::X\n       end\n\njulia> obj = Foo(1, :two, Foo(Bar(3), 4.0, 5.0f0));\n\njulia> use = Union{Int, Float32}; # Return Int and Float32 fields\n\njulia> ignore = Bar;              # Dont return Bar or iterate over Bar fields\n\njulia> flatten(obj, use, ignore)  # `flatten` all Int and Float32 except fields of Bar\n(1, 5.0f0)\n\njulia> modify(string, obj, Int)   # `modify`: convert all Int to String\nFoo{String,Symbol,Foo{Bar{String},Float64,Float32}}(\"1\", :two, Foo{Bar{String},Float64,Float32}(Bar{String}(\"3\"), 4.0, 5.0f0))\n\nThe default type used is Real. These rules also apply in reconstruct, update! and modify.\n\nField removal\n\nThere are often cases where you want to ignore certain fields that have the same type as the fields you want to extract. Flatten.jl also FieldMetadata.jl to provide @flattenable macro and methods, allowing you to choose fields to include and remove from flattening. The default is true for all fields.\n\nusing Flatten\nimport Flatten: flattenable\n\n@flattenable struct Bar{X,Y}\n    x::X | true\n    y::Y | false\nend\n\nflatten(Bar(1, 2))\n\n# output\n(1,)\n\nCustom @metadata methods from FieldMetadata can be used, if they return a Bool. You can also use custom functions that follow the following form, returning a boolean:\n\nf(::Type, ::Type{Var{:fieldname}}) = false\n\nMetatdata flattening\n\nFlatten also provides metaflatten() to flatten any FieldMetadata.jl metadata for the same fields flatten() returns. This can be useful for attaching information like descriptions or prior probability distributions to each field. Regular field data can also be collected with convenience versions of metaflatten: fieldnameflatten, parentflatten, fieldtypeflatten and parenttypeflatten functions provide lists of fieldnames and types that may be useful for building parameter display tables.\n\nThis package was started by Robin Deits (@rdeits), and its early development owes much to discussions and ideas from Jan Weidner (@jw3126) and Robin Deits. \"\"\"\n\nreconstruct and modify for StaticArrays\n\nSArray and other objects from StaticArrays.jl can not be constructed from their fields.  Dealing with this in the long term will require either a dependency on ConstructionBase.jl in StaticArrays.jl, or a glue package that provides the required constructorof methods, which for now you can define manually:\n\nusing StaticArrays, ConstructionBase, Flatten\n\nstruct SArrayConstructor{S,N,L} end\n(::SArrayConstructor{S,N,L})(data::NTuple{L,T}) where {S,T,N,L} = SArray{S,T,N,L}(data)\n\nConstructionBase.constructorof(sa::Type{<:SArray{S,<:Any,N,L}}) where {S,N,L} = \n    SArrayConstructor{S,N,L}()\n\n\n\n\n\n","category":"module"},{"location":"#Flatten.fieldnameflatten-Tuple{Any, Vararg{Any, N} where N}","page":"Flatten.jl","title":"Flatten.fieldnameflatten","text":"jldoctest     fieldnameflatten(obj, args...)\n\nFlatten the field names of an object. Args are passed to metaflatten.\n\nExamples\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> fieldnameflatten(Foo(1, 2, 3))\n(:a, :b, :c)\n\n\n\n\n\n","category":"method"},{"location":"#Flatten.fieldtypeflatten-Tuple{Any, Vararg{Any, N} where N}","page":"Flatten.jl","title":"Flatten.fieldtypeflatten","text":"fieldtypeflatten(obj, args...)\n\nFlatten the field types of an object. Args are passed to metaflatten.\n\nExamples\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> fieldtypeflatten(Foo(1.0, :two, \"Three\"), Union{Real,String})\n(Float64, String)\n\n\n\n\n\n","category":"method"},{"location":"#Flatten.flatten","page":"Flatten.jl","title":"Flatten.flatten","text":"flatten(obj, [flattentrait::Function], [use::Type], [ignore::Type])\n\nFlattening. Flattens a nested struct or tuple to a flat tuple. Query types and flatten trait arguments are optional, but you must pass use to pass ignore.\n\nArguments\n\nobj: The target type to be reconstructed\nflattentrait: A function returning a Bool, such as a FielMetadata method. With the form: f(::Type, ::Type{Val{:fieldname}}) = true\nuse: Type or Union of types to return in the tuple.\nignore: Types or Union of types  to ignore completly. These are not reurned or recursed over.\n\nExamples\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> foo = Foo(1, 2, 3)\nFoo{Int64,Int64,Int64}(1, 2, 3)\n\njulia> flatten(foo)\n(1, 2, 3)\n\njulia> nested = Foo(Foo(1, 2, 3), 4.0, 5.0)\nFoo{Foo{Int64,Int64,Int64},Float64,Float64}(Foo{Int64,Int64,Int64}(1, 2, 3), 4.0, 5.0)\n\njulia> flatten(nested)\n(1, 2, 3, 4.0, 5.0)\n\nTo convert the tuple to a vector, simply use [flatten(x)...], or\nusing static arrays to avoid allocations: `SVector(flatten(x))`.\n\nFields can be excluded from flattening with the flattenable(struct, field) method. These are easily defined using @flattenable from FieldMetadata.jl, or defining your own custom function with FieldMetadata, or manually with the form:\n\njulia> import Flatten: flattenable\n\njulia> @flattenable struct Partial{A,B,C}\n           a::A | true\n           b::B | true\n           c::C | false\n       end\n\njulia> nestedpartial = Partial(Partial(1.0, 2.0, 3.0), 4, 5)\nPartial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)\n\njulia> nestedpartial = Partial(Partial(1.0, 2.0, 3.0), 4, 5)\nPartial{Partial{Float64,Float64,Float64},Int64,Int64}(Partial{Float64,Float64,Float64}(1.0, 2.0, 3.0), 4, 5)\n\njulia> flatten(nestedpartial)\n(1.0, 2.0, 4)\n\n\n\n\n\n","category":"function"},{"location":"#Flatten.metaflatten","page":"Flatten.jl","title":"Flatten.metaflatten","text":"metaflatten(obj, func, [flattentrait::Function], [use::Type], [ignore::Type])\n\nMetadata flattening. Flattens data attached to a field using a passed in function Query types and flatten trait arguments are optional, but you must pass use to pass ignore.\n\nArguments\n\nobj: The target type to be reconstructed\nfunc: A function with the form: f(::Type, ::Type{Val{:fieldname}}) = metadata\nflattentrait: A function returning a Bool, such as a FielMetadata method. With the form: f(::Type, ::Type{Val{:fieldname}}) = true\nuse: Type or Union of types to return in the tuple.\nignore: Types or Union of types  to ignore completly. These are not reurned or recursed over.\n\nWe can flatten this @foobar metadata:\n\njulia> using Flatten, FieldMetadata\n\njulia> import Flatten: flattenable\n\njulia> @metadata foobar :foo;\n\njulia> @foobar struct Foo{A,B,C}\n           a::A | :bar\n           b::B | :foobar\n           c::C | :foo\n       end;\n\njulia> @foobar struct Bar{X,Y}\n           x::X | :foobar\n           y::Y | :bar\n       end;\n\njulia> metaflatten(Foo(1, 2, Bar(3, 4)), foobar)\n(:bar, :foobar, :foobar, :bar)\n\n\n\n\n\n","category":"function"},{"location":"#Flatten.modify-Tuple{Any, Any, Vararg{Any, N} where N}","page":"Flatten.jl","title":"Flatten.modify","text":"modify(func, obj, args...)\n\nModify field in a type with a function\n\n\n\n\n\n","category":"method"},{"location":"#Flatten.parentnameflatten-Tuple{Any, Vararg{Any, N} where N}","page":"Flatten.jl","title":"Flatten.parentnameflatten","text":"parentnameflatten(obj, args...)\n\nFlatten the name of the parent type of an object. Args are passed to metaflatten.\n\nExamples\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> struct Bar{X,Y}\n           x::X\n           y::Y\n       end\n\njulia> parentnameflatten(Foo(1, 2, Bar(3, 4)))\n(:Foo, :Foo, :Bar, :Bar)\n\n\n\n\n\n","category":"method"},{"location":"#Flatten.parenttypeflatten-Tuple{Any, Vararg{Any, N} where N}","page":"Flatten.jl","title":"Flatten.parenttypeflatten","text":"parenttypeflatten(obj, args...)\n\nFlatten the parent type of an object. Args are passed to metaflatten.\n\nExamples\n\njulia> using Flatten\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> struct Bar{X,Y}\n           x::X\n           y::Y\n       end\n\njulia> parenttypeflatten(Foo(1, 2, Bar(3, 4)))\n(Foo{Int64,Int64,Bar{Int64,Int64}}, Foo{Int64,Int64,Bar{Int64,Int64}}, Bar{Int64,Int64}, Bar{Int64,Int64})\n\n\n\n\n\n","category":"method"},{"location":"#Flatten.reconstruct","page":"Flatten.jl","title":"Flatten.reconstruct","text":"reconstruct(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])\n\nReconstruct an object from Tuple or Vector data and an existing object. Data should be at least as long as the queried fields in the obj. Query types and flatten trait arguments are optional, but you must pass use to pass ignore.\n\nArguments\n\nobj: The target type to be reconstructed\ndata: Replacement data - an AbstractArray, Tuple or type that defines getfield.\nflattentrait: A function returning a Bool, such as a FielMetadata method. With the form: f(::Type, ::Type{Val{:fieldname}}) = true\nuse: Type or Union of types to return in the tuple.\nignore: Types or Union of types  to ignore completly. These are not reurned or recursed over.\n\nExamples\n\njulia> struct Foo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> reconstruct(Foo(1, 2, 3), (1, :two, 3.0))\nFoo{Int64,Symbol,Float64}(1, :two, 3.0)\n\n\n\n\n\n","category":"function"},{"location":"#Flatten.update!","page":"Flatten.jl","title":"Flatten.update!","text":"update!(obj, data, [flattentrait::Function], [use::Type], [ignore::Type])\n\nUpdate a mutable object with a Tuple or Vector of data. Query types and flatten trait arguments are optional, but you must pass use to pass ignore.\n\nArguments\n\nobj: The target type to be reconstructed\ndata: Replacement data - an AbstractArray, Tuple or type that defines getfield.\nflattentrait: A function returning a Bool, such as a FielMetadat method. With the form: f(::Type, ::Type{Val{:fieldname}}) = true\nuse: Types to return in the tuple.\nignore: Types to ignore completly. These are not reurned or recursed over.\n\nExamples\n\njulia> using Flatten\n\njulia> mutable struct MutableFoo{A,B,C}\n           a::A\n           b::B\n           c::C\n       end\n\njulia> mufoo = MutableFoo(1, 2, 3)\nMutableFoo{Int64,Int64,Int64}(1, 2, 3)\n\njulia> update!(mufoo, (2, 4, 6))\nMutableFoo{Int64,Int64,Int64}(2, 4, 6)\n\njulia> mufoo = MutableFoo(1, 2, :three)\nMutableFoo{Int64,Int64,Symbol}(1, 2, :three)\n\njulia> update!(mufoo, (:foo,), Symbol)\nMutableFoo{Int64,Int64,Symbol}(1, 2, :foo)\n\n\n\n\n\n","category":"function"}]
}
