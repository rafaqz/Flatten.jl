using .Unitful
export ulflatten, ulreconstruct, ulupdate!

"Unitless flattening. Flattens a nested type to a Tuple or Vector"
ulflatten(::Type{V}, t) where V <: AbstractVector = V([ulflatten(t)...])
ulflatten(::Type{Tuple}, t) = ulflatten(t)
ulflatten(x::Nothing) = ()
ulflatten(x::Number) = (x,) 
ulflatten(x::Unitful.Quantity) = (x.val,) 
@generated ulflatten(t) = flatten_inner(t, :ulflatten)


" Reconstruct an object from partial Tuple or Vector data and another object"
ulreconstruct(t, data) = ulreconstruct(t, data, 1)[1][1]
ulreconstruct(::Nothing, data, n) = (nothing,), n
ulreconstruct(::Number, data, n) = (data[n],), n + 1 
ulreconstruct(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated ulreconstruct(t, data, n) = reconstruct_inner(t, :ulreconstruct)

" Update a mutable object with partial Tuple or Vector data"
ulupdate!(t, data) = begin
    ulupdate!(t, data, 1)
    t
end
ulupdate!(::Nothing, data, n) = (nothing,), n
ulupdate!(::Number, data, n) = (data[n],), n + 1 
ulupdate!(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated ulupdate!(t::T, data, n) where T = update_inner(T, :ulupdate!)
