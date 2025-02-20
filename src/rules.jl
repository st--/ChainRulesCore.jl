"""
    frule([::RuleConfig,] (Δf, Δx...), f, x...)

Expressing the output of `f(x...)` as `Ω`, return the tuple:

    (Ω, ΔΩ)

The second return value is the differential w.r.t. the output.

If no method matching `frule((Δf, Δx...), f, x...)` has been defined, then return `nothing`.

Examples:

unary input, unary output scalar function:

```jldoctest frule
julia> dself = NoTangent();

julia> x = rand()
0.8236475079774124

julia> sinx, Δsinx = frule((dself, 1), sin, x)
(0.7336293678134624, 0.6795498147167869)

julia> sinx == sin(x)
true

julia> Δsinx == cos(x)
true
```

Unary input, binary output scalar function:

```jldoctest frule
julia> sincosx, Δsincosx = frule((dself, 1), sincos, x);

julia> sincosx == sincos(x)
true

julia> Δsincosx[1] == cos(x)
true

julia> Δsincosx[2] == -sin(x)
true
```

Note that techically speaking julia does not have multiple output functions, just functions
that return a single output that is iterable, like a `Tuple`.
So this is actually a [`Tangent`](@ref):
```jldoctest frule
julia> Δsincosx
Tangent{Tuple{Float64, Float64}}(0.6795498147167869, -0.7336293678134624)
```

The optional [`RuleConfig`](@ref) option allows specifying frules only for AD systems that
support given features. If not needed, then it can be omitted and the `frule` without it
will be hit as a fallback. This is the case for most rules.

See also: [`rrule`](@ref), [`@scalar_rule`](@ref), [`RuleConfig`](@ref)
"""
frule(ȧrgs, f, ::Vararg{Any}) = nothing

# if no config is present then fallback to config-less rules
frule(::RuleConfig, args...) = frule(args...)

# Manual fallback for keyword arguments. Usually this would be generated by
#
#   frule(::Any, ::Vararg{Any}; kwargs...) = nothing
#
# However - the fallback method is so hot that we want to avoid any extra code
# that would be required to have the automatically generated method package up
# the keyword arguments (which the optimizer will throw away, but the compiler
# still has to manually analyze). Manually declare this method with an
# explicitly empty body to save the compiler that work.
const frule_kwfunc = Core.kwftype(typeof(frule)).instance
(::typeof(frule_kwfunc))(::Any, ::typeof(frule), ȧrgs, f, ::Vararg{Any}) = nothing
function (::typeof(frule_kwfunc))(kws::Any, ::typeof(frule), ::RuleConfig, args...)
    return frule_kwfunc(kws, frule, args...)
end

"""
    rrule([::RuleConfig,] f, x...)

Expressing `x` as the tuple `(x₁, x₂, ...)` and the output tuple of `f(x...)`
as `Ω`, return the tuple:

    (Ω, (Ω̄₁, Ω̄₂, ...) -> (s̄elf, x̄₁, x̄₂, ...))

Where the second return value is the the propagation rule or pullback.
It takes in differentials corresponding to the outputs (`x̄₁, x̄₂, ...`),
and `s̄elf`, the internal values of the function itself (for closures)

If no method matching `rrule(f, xs...)` has been defined, then return `nothing`.

Examples:

unary input, unary output scalar function:

```jldoctest
julia> x = rand();

julia> sinx, sin_pullback = rrule(sin, x);

julia> sinx == sin(x)
true

julia> sin_pullback(1) == (NoTangent(), cos(x))
true
```

binary input, unary output scalar function:

```jldoctest
julia> x, y = rand(2);

julia> hypotxy, hypot_pullback = rrule(hypot, x, y);

julia> hypotxy == hypot(x, y)
true

julia> hypot_pullback(1) == (NoTangent(), (x / hypot(x, y)), (y / hypot(x, y)))
true
```

The optional [`RuleConfig`](@ref) option allows specifying rrules only for AD systems that
support given features. If not needed, then it can be omitted and the `rrule` without it
will be hit as a fallback. This is the case for most rules.

See also: [`frule`](@ref), [`@scalar_rule`](@ref), [`RuleConfig`](@ref)
"""
rrule(::Any, ::Vararg{Any}) = nothing

# if no config is present then fallback to config-less rules
rrule(::RuleConfig, args...) = rrule(args...)

# Manual fallback for keyword arguments. See above
const rrule_kwfunc = Core.kwftype(typeof(rrule)).instance
(::typeof(rrule_kwfunc))(::Any, ::typeof(rrule), ::Any, ::Vararg{Any}) = nothing
function (::typeof(rrule_kwfunc))(kws::Any, ::typeof(rrule), ::RuleConfig, args...)
    return rrule_kwfunc(kws, rrule, args...)
end

##############################################################
### Opt out functionality

const NO_RRULE_DOC = """
    no_rrule

This is an piece of infastructure supporting opting out of [`rrule`](@ref).
It follows the signature for `rrule` exactly.
A collection of type-tuples is stored in its method-table.
If something has this defined, it means that it must having a must also have a `rrule`, 
defined that returns `nothing`.

!!! warning "do not overload no_rrule directly
    It is fine and intended to query the method table of `no_rrule`.
    It is not safe to add to that directly, as corresponding changes also need to be made to
    `rrule`.
    The [`@opt_out`](@ref) macro does both these things, and so should almost always be used
    rather than defining a method of `no_rrule` directly.

### Mechanics
note: when the text below says methods `==` it actually means:
`parameters(m.sig)[2:end]` (i.e. the signature type tuple) rather than the method object `m` itself.

To decide if should opt-out using this mechanism.
 - find the most specific method of `rrule` and `no_rule` e.g with `Base.which`
  - if the method of `no_rrule` `==` the method of `rrule`, then should opt-out

To just ignore the fact that rules can be opted-out from, and that some rules thus return
`nothing`, then filter the list of methods of `rrule` to remove those that are `==` to ones
that occur in the method table of `no_rrule`.

Note also when doing this you must still also handle falling back from rule with config, to
rule without config.

On the other-hand if your AD can work with `rrule`s that return `nothing`, then it is
simpler to just use that mechanism for opting out; and you don't need to worry about this
at all.

For more information see the [documentation on opting out of rules](@ref opt_out)
"""

"""
$NO_RRULE_DOC

See also [`ChainRulesCore.no_frule`](@ref).
"""
function no_rrule end
no_rrule(::Any, ::Vararg{Any}) = nothing

"""
$(replace(NO_RRULE_DOC, "rrule"=>"frule"))

See also [`ChainRulesCore.no_rrule`](@ref).
"""
function no_frule end
no_frule(ȧrgs, f, ::Vararg{Any}) = nothing
