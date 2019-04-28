using .Unitful
export ulflatten, ulreconstruct, ulupdate!


# Unitless flatten

ulflatten(action::FlattenAction, x) = flatten(action, x)
ulflatten(::Use, x::Unitful.Quantity) = (x.val,) 
@generated ulflatten(::Recurse, t) = flatten_inner(t, :ulflatten)

ulflatten(::Type{V}, t) where V <: AbstractVector = V([ulflatten(t)...])
ulflatten(::Type{Tuple}, t) = ulflatten(t)

"Unitless flattening. Flattens a nested type to a Tuple or Vector"
ulflatten(t) = ulflatten(action(t), t)


# Unitless reconstruct

ulreconstruct(action::FlattenAction, x, data, n) = reconstruct(action, x, data, n) 
ulreconstruct(::Use, ::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated ulreconstruct(::Recurse, t, data, n) = reconstruct_inner(t, :ulreconstruct)

" Reconstruct an object from partial Tuple or Vector data and another object"
ulreconstruct(t, data) = ulreconstruct(action(t), t, data, 1)[1][1]


# Unitless update

ulupdate!(action::FlattenAction, x, data, n) = update!(action, x, data, n)
ulupdate!(::Use, ::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated ulupdate!(::Recurse, t::T, data, n) where T = update_inner(T, :ulupdate!)

" Update a mutable object with partial Tuple or Vector data"
ulupdate!(t, data) = begin
    ulupdate!(action(t), t, data, 1)
    t
end
