##############
# InnerLabel #
##############
immutable InnerLabel{B,K} <: Number
    b::StateLabel{B}
    k::StateLabel{K}
    function InnerLabel(b::StateLabel{B}, k::StateLabel{K})
        @assert nfactors(b) == nfactors(k)
        return new(b, k)
    end
end

InnerLabel{B,K}(b::StateLabel{B}, k::StateLabel{K}) = InnerLabel{B,K}(b,k)

blabel(i::InnerLabel) = i.b
klabel(i::InnerLabel) = i.k

Base.repr(i::InnerLabel) = brstr(blabel(i))*ktstr(klabel(i))[2:end]
Base.show(io::IO, i::InnerLabel) = print(io, repr(i))

Base.(:(==))(a::InnerLabel, b::InnerLabel) = blabel(a) == blabel(b) && klabel(a) == klabel(b)                                             
Base.(:(==))(::InnerLabel, ::Number) = false
Base.(:(==))(::Number, ::InnerLabel) = false

Base.copy(i::InnerLabel) = i
Base.hash(i::InnerLabel) = hash(hash(blabel(i)), hash(klabel(i)))

Base.conj(i::InnerLabel) = InnerLabel(klabel(i), blabel(i))

##############
# InnerExpr #
##############
# A InnerExpr is a type that wraps arthimetic expressions
# performed with InnerExprs. The allows storage and 
# delayed evaluation of expressions. For example, this 
# expression:
#   
#   (< a | b >^2 + < c | d >^2 - 3.13+im) / 2
#
# is representable as a InnerExpr.

immutable InnerExpr <: Number
    ex::Expr
end

InnerExpr(iex::InnerExpr) = InnerExpr(iex.ex)
InnerExpr{N<:Number}(n::N) = convert(InnerExpr, n)

Base.convert(::Type{InnerExpr}, iex::InnerExpr) = iex
Base.convert{N<:Number}(::Type{InnerExpr}, n::N) = InnerExpr(Expr(:call, +, n))

Base.(:(==))(a::InnerExpr, b::InnerExpr) = a.ex == b.ex
same_num(a::Number, b::Number) = a == b
same_num(a::InnerExpr, b::InnerExpr) = a == b
same_num(iex::InnerExpr, i::InnerLabel) = iex == InnerExpr(i)
same_num(i::InnerLabel, iex::InnerExpr) = iex == i
same_num(iex::InnerExpr, n::Number) = iex == InnerExpr(n)
same_num(n::Number, iex::InnerExpr) = iex == n

Base.hash(iex::InnerExpr) = hash(iex.ex)
Base.hash(iex::InnerExpr, h::Uint64) = hash(hash(iex), h)

Base.one(::InnerExpr) = InnerExpr(1)
Base.zero(::InnerExpr) = InnerExpr(0)

Base.promote_rule{N<:Number}(::Type{InnerExpr}, ::Type{N}) = InnerExpr

Base.length(iex::InnerExpr) = length(iex.ex.args)
Base.getindex(iex::InnerExpr, i) = iex.ex.args[i]

##############
# inner_eval #
##############
inner_eval(f, iex::InnerExpr) = eval(inner_reduce!(f, copy(iex.ex)))
inner_eval(f, c) = c

inner_reduce!(f, iex::InnerExpr) = inner_reduce!(f, copy(iex.ex))
inner_reduce!(f::Function, i::InnerLabel) = f(blabel(i), klabel(i))
inner_reduce!{P<:AbstractInner}(::Type{P}, i::InnerLabel) = P(blabel(i), klabel(i))
inner_reduce!(f, n) = n

function inner_reduce!(f, ex::Expr)
    for i=1:length(ex.args)
        ex.args[i] = inner_reduce!(f, ex.args[i])
    end
    return ex
end

######################
# Printing Functions #
######################
Base.show(io::IO, iex::InnerExpr) = print(io, repr(iex.ex)[2:end])

##################
# Exponentiation #
##################
Base.exp(iex::InnerExpr) = InnerExpr(:(exp($(iex))))
Base.exp2(iex::InnerExpr) = InnerExpr(:(exp2($(iex))))

Base.sqrt(iex::InnerExpr) = InnerExpr(:(sqrt($(iex))))

Base.log(iex::InnerExpr) = length(iex)==2 && iex[1]==:exp ? iex[2] : InnerExpr(:(log($(iex))))
Base.log(a::MathConst{:e}, b::InnerExpr) = InnerExpr(:(log($(a),$(b))))
Base.log(a::InnerExpr, b::InnerExpr) = InnerExpr(:(log($(a),$(b))))
Base.log(a::InnerExpr, b::Number) = InnerExpr(:(log($(a),$(b))))
Base.log(a::Number, b::InnerExpr) = InnerExpr(:(log($(a),$(b))))
Base.log2(iex::InnerExpr) = length(iex)==2 && iex[1]==:exp2 ? iex[2] : InnerExpr(:(log2($(iex))))

function iexpr_exp(a, b)
    if same_num(b, 1)
        return InnerExpr(a)
    elseif same_num(a, 0)
        return InnerExpr(0)
    elseif same_num(b, 0)
        return InnerExpr(1)
    else
        return InnerExpr(:($(a)^$(b)))
    end
end

Base.(:^)(a::InnerExpr, b::Integer) = iexpr_exp(a, b)
Base.(:^)(a::InnerExpr, b::Rational) = iexpr_exp(a, b)
Base.(:^)(a::InnerExpr, b::InnerExpr) = iexpr_exp(a, b)
Base.(:^)(a::InnerExpr, b::Number) = iexpr_exp(a, b)
Base.(:^)(a::MathConst{:e}, b::InnerExpr) = exp(b)
Base.(:^)(a::Number, b::InnerExpr) = iexpr_exp(a, b)

##################
# Multiplication #
##################
function iexpr_mul(a,b)
    if same_num(b, 1)
        return InnerExpr(a)
    elseif same_num(a, 1)
        return InnerExpr(b)
    elseif same_num(b, 0) || same_num(a, 0)
        return InnerExpr(0)
    else
        return InnerExpr(:($(a)*$(b)))
    end
end

Base.(:*)(a::InnerExpr, b::InnerExpr) =iexpr_mul(a,b) 
Base.(:*)(a::Bool, b::InnerExpr) = iexpr_mul(a,b)
Base.(:*)(a::InnerExpr, b::Bool) = iexpr_mul(a,b)
Base.(:*)(a::InnerExpr, b::Number) = iexpr_mul(a,b)
Base.(:*)(a::Number, b::InnerExpr) = iexpr_mul(a,b)

############
# Division #
############
function iexpr_div(a, b)
    if same_num(a, b)
        return InnerExpr(1)
    elseif same_num(a, 0)
        return InnerExpr(0)
    elseif same_num(b, 0)
        return InnerExpr(Inf)
    elseif same_num(b, 1)
        return InnerExpr(a)
    else
        return InnerExpr(:($(a)/$(b)))
    end
end

Base.(:/)(a::InnerExpr, b::InnerExpr) = iexpr_div(a, b)
Base.(:/)(a::InnerExpr, b::Complex) = iexpr_div(a, b)
Base.(:/)(a::InnerExpr, b::Number) = iexpr_div(a, b)
Base.(:/)(a::Number, b::InnerExpr) = iexpr_div(a, b)

############
# Addition #
############
function iexpr_add(a, b)
    if same_num(a, 0) 
        return InnerExpr(b)
    elseif same_num(b, 0)
        return InnerExpr(a)
    else
        return InnerExpr(:($(a)+$(b)))
    end
end

Base.(:+)(a::InnerExpr, b::InnerExpr) = iexpr_add(a, b)
Base.(:+)(a::InnerExpr, b::Number) = iexpr_add(a, b)
Base.(:+)(a::Number, b::InnerExpr) = iexpr_add(a, b)

###############
# Subtraction #
###############
Base.(:-)(iex::InnerExpr) = length(iex)==2 && iex[1]==:- ? InnerExpr(iex[2]) :  InnerExpr(:(-$(iex)))

function iexpr_subtract(a, b)
    if same_num(a, b)
        return InnerExpr(0)
    elseif same_num(a, 0)
        return InnerExpr(-b)
    elseif same_num(b, 0)
        return InnerExpr(a)
    else
        return InnerExpr(:($(a)-$(b)))
    end
end

Base.(:-)(a::InnerExpr, b::InnerExpr) = iexpr_subtract(a, b)
Base.(:-)(a::InnerExpr, b::Number) = iexpr_subtract(a, b)
Base.(:-)(a::Number, b::InnerExpr) = iexpr_subtract(a, b)

##################
# Absolute Value #
##################
Base.abs(iex::InnerExpr) = length(iex)==2 && iex[1]==:abs ? iex :  InnerExpr(:(abs($(iex))))
Base.abs2(iex::InnerExpr) = InnerExpr(:(abs2($iex)))

#####################
# Complex Conjugate #
#####################
Base.conj(iex::InnerExpr) = length(iex)==2 && iex[1]==:conj ? InnerExpr(iex[2]) :  InnerExpr(:(conj($(iex))))
Base.ctranspose(iex::InnerExpr) = conj(iex)

##########################
# Elementwise Operations #
##########################
for op=(:*,:-,:+,:/,:^)
    elop = symbol(string(:.) * string(op))
    @eval begin
        ($elop)(a::InnerExpr, b::InnerExpr) = ($op)(a,b)
        ($elop)(a::InnerExpr, b::Number) = ($op)(a,b)
        ($elop)(a::Number, b::InnerExpr) = ($op)(a,b)
    end
end

######################
# Printing Functions #
######################
function Base.repr(iex::InnerExpr)
    if iex[1]==+
        if length(iex)==2
            return repr(iex[2])
        else
            return repr(Expr(:call, iex.ex[2:end]...))[3:end-1]
        end
    else
        return repr(iex.ex)[2:end]
    end
end

Base.show(io::IO, iex::InnerExpr) = print(io, repr(iex))

###############
# Inner rules #
###############
macro definner(name)
    return quote 
        immutable $name <: AbstractInner end
    end
end

abstract ProvidedInner <: AbstractInner

immutable KronDelta <: ProvidedInner end
KronDelta(b, k) = b == k ? 1 : 0

immutable UndefInner <: ProvidedInner end
UndefInner(b, k) = InnerExpr(InnerLabel(b, k))

# by the time this is called, nfactors 
# checking has already been performed.
function inner{P<:AbstractInner}(::Type{P}, b::StateLabel, k::StateLabel)
    @inbounds result = P(b[1], k[1])
    @inbounds for i=2:nfactors(b)
        result *= P(b[i], k[i])
    end
    return result
end

inner(::Type{KronDelta}, b::StateLabel, k::StateLabel) = b == k ? 1 : 0
inner(::Type{UndefInner}, b::StateLabel, k::StateLabel) = InnerExpr(InnerLabel(b, k))

inner_rettype(::Type{KronDelta}) = Int
inner_rettype(::Type{UndefInner}) = InnerExpr

function inner_rettype{P<:ProvidedInner}(a::AbstractDirac{P}, b::AbstractDirac{P})
    return promote_type(eltype(a), eltype(b), inner_rettype(P))
end

inner_rettype(d::AbstractDirac) = inner_rettype(d,d)

function inner{P}(a::AbstractDirac{P}, b::AbstractDirac{P})
    @assert matching_nfactors(a,b)
    return execute_inner(a, b)
end

function act_on(a::AbstractDirac, b::AbstractDirac, i)
    @assert nfactors(a) == 1 "nfactors(a) must equal 1 when using act_on(a,b,i)"
    @assert nfactors(b) > 1 "nfactors(b) must greater than 1 when using act_on(a,b,i)"
    @assert 1 <= i <= nfactors(b) "i is constrained to 1 <= i <= nfactors(b) when using act_on(a,b,i)"
    return execute_act_on(a, b, i)
end

export InnerExpr,
    UndefInner,
    KronDelta,
    inner_eval,
    @definner