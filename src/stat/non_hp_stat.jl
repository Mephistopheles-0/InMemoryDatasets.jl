# _stat_add_sum(x::T, y::S) where T where S = convert(promote_type(S,T), x + y)
_stat_add_sum(x, y) = Base.add_sum(x, y)
_stat_add_sum(x::Bool, y::Bool) = x + y
_stat_add_sum(x, ::Missing) = x
_stat_add_sum(::Missing, x) = x
_stat_add_sum(::Missing, ::Missing) = missing
_stat_mul_prod(x, y) = Base.mul_prod(x, y)
_stat_mul_prod(x, ::Missing) = x
_stat_mul_prod(::Missing, x) = x
_stat_mul_prod(::Missing, ::Missing) = missing
_stat_min_fun(x, y) = min(x, y)
_stat_min_fun(x, ::Missing) = x
_stat_min_fun(::Missing, y) = y
_stat_min_fun(::Missing, ::Missing) = missing
_stat_max_fun(x, y) = max(x, y)
_stat_max_fun(x, ::Missing) = x
_stat_max_fun(::Missing, y) = y
_stat_max_fun(::Missing, ::Missing) = missing
_stat_realXcY(x, y) = Statistics.realXcY(x, y)
_stat_realXcY(x, ::Missing) = x
_stat_realXcY(::Missing, y) = y
_stat_realXcY(::Missing,::Missing) = missing
ISNAN(x::Any) = isnan(x)
ISNAN(::Missing) = false

_stat_bool(f) = x->f(x)::Bool

_stat_ismissing(x::Any)::Int = 0
_stat_ismissing(::Missing)::Int = 1
_stat_notmissing(x::Any)::Int = 1
_stat_notmissing(::Missing)::Int = 0
const INTEGERS = Union{Signed, Unsigned, Int8, Int16, Int32, Int64}
const FLOATS = Union{Float16, Float32, Float64}


"""
rescale(x,minx,maxx,minval,maxval) rescales x to run from minval and maxval, given x originaly runs from minx to maxx.
"""
function rescale(x,minx,maxx,minval,maxval)
    -(-maxx*minval+minx*maxval)/(maxx-minx)+(-minval+maxval)*x/(maxx-minx)
end
rescale(::Missing,minx,maxx,minval,maxval) = missing
rescale(x::Vector,minx,maxx,minval,maxval) = rescale.(x,minx,maxx,minval,maxval)
rescale(x,minx,maxx) = rescale(x,minx,maxx,0.0,1.0)

"""
stdze(x) standardizes an array. It return missing for missing data points.
"""
function stdze(x)
    all(ismissing,x) && return x
    meandata = mean(x)
    vardata = var(x)
    (x .- meandata) ./ sqrt(vardata)
end

function stat_maximum(f, x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T
    all(ismissing, view(x, lo:hi)) && return missing
    _dmiss(x) = ismissing(f(x)) ? typemin(nonmissingtype(T)) : f(x)
    Base.mapreduce_impl(_dmiss, max, x, lo, hi)
end
stat_maximum(x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T = stat_maximum(identity, x; lo = lo, hi = hi)

function _arg_minmax_barrier(x, minmaxval, f)
    @inbounds for i in 1:length(x)
        isequal(f(x[i]), minmaxval) && return i
    end
end

#TODO why this allocate?
function stat_argmax(f, x::AbstractArray{T,1}) where T
    isempty(x) && throw(ArgumentError("input vector cannot be empty"))
    maxval = stat_maximum(f, x)
    _arg_minmax_barrier(x, maxval, f)
end
stat_argmax(x::AbstractArray{T,1}) where T = stat_argmax(identity, x)

function stat_minimum(f, x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T
    all(ismissing, view(x, lo:hi)) && return missing
    @inline _dmiss(x) = ismissing(f(x)) ? typemax(nonmissingtype(T)) : f(x)
    Base.mapreduce_impl(_dmiss, min, x, lo, hi)
end
stat_minimum(x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T = stat_minimum(identity, x; lo = lo, hi = hi)

#TODO why this allocate?
function stat_argmin(f, x::AbstractArray{T,1}) where T
    isempty(x) && throw(ArgumentError("input vector cannot be empty"))
    minval = stat_minimum(f, x)
    _arg_minmax_barrier(x, minval, f)
end
stat_argmin(x::AbstractArray{T,1}) where T = stat_argmin(identity, x)


function stat_sum(f, x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T <: Union{Missing, INTEGERS, FLOATS}
    all(ismissing, view(x, lo:hi)) && return f(first(x))
    _dmiss(y) = ifelse(ismissing(f(y)),  zero(T), f(y))
    Base.mapreduce_impl(_dmiss, _stat_add_sum, x, lo, hi)
end
stat_sum(x::AbstractArray{T,1}; lo = 1, hi = length(x)) where T <: Union{Missing, INTEGERS, FLOATS} = stat_sum(identity, x; lo = lo, hi = hi)

# function stat_wsum(f, x::AbstractArray{Union{T,Missing},1}, w) where T
#     all(ismissing, x) && return missing
#     _dmiss(y) = ismissing(y[1])||ismissing(y[2]) ? zero(T) : (f(y[1])*y[2])
#     mapreduce(_dmiss, _stat_add_sum, zip(x,w))
# end
# stat_wsum(x::AbstractArray{Union{T,Missing},1}, w) where T  = stat_wsum(identity, x, w)
function stat_wsum(f, x::AbstractVector{T}, w::AbstractVector) where T
    all(ismissing, x) && return missing
    _dmiss(y) = ismissing(y[1])||ismissing(y[2]) ? missing : (f(y[1])*y[2])
    mapreduce(_dmiss, _stat_add_sum, zip(x,w))
end
stat_wsum(x::AbstractVector{T}, w::AbstractVector) where T  = stat_wsum(identity, x, w)
function stat_mean(f, x::AbstractArray{T,1})::Union{Float64, Missing} where T <: Union{Missing, INTEGERS, FLOATS}
    length(x) == 1 && return f(first(x))
    _op(y1,y2) = (_stat_add_sum(y1[1], y2[1]), _stat_add_sum(y1[2], y2[2]))
    _dmiss(y) = (ismissing(f(y)) ? zero(T) : f(y), _stat_notmissing(f(y)))
    sval, n = mapreduce(_dmiss, _op, x)
    n == 0 ? missing : sval/n
end

stat_mean(x::AbstractArray{T,1}) where T = stat_mean(identity, x)

function stat_wmean(f, x::AbstractVector{T}, w::AbstractArray{S,1}) where T where S
    all(ismissing, x) && return missing
    _dmiss(y)::T = ismissing(y[1])||ismissing(y[2]) ? zero(T) : (f(y[1])*y[2])::T
    _dmiss2(y)::S = ismissing(y[1])||ismissing(y[2]) ? zero(S) : y[2]
    _op(y1,y2)::Tuple{T,S} = _stat_add_sum.(y1, y2)
    _f(y)::Tuple{T,S} = (_dmiss(y), _dmiss2(y))
    sval, n = mapreduce(_f, _op, zip(x,w))::Tuple{T,S}
    n == 0 ? missing : sval / n
end
stat_wmean(x::AbstractVector{T}, w::AbstractArray{S,1}) where T where S = stat_wmean(identity, x, w)


function stat_var(f, x::AbstractArray{T,1}, dof=true)::Union{Float64, Missing} where T <: Union{Missing, INTEGERS, FLOATS}
    all(ismissing, x) && return missing
    any(ISNAN, x) && return convert(eltype(x), NaN)
    meanval = stat_mean(f, x)
    n = mapreduce(!ismissing, +, x)

    ss = 0.0
    for i in 1:length(x)
        ss = _stat_add_sum(ss, abs2(f(x[i]) - meanval))
    end

    if n == 0
        return missing
    elseif n == 1 && dof
        return missing
    else
        return ss / (n - Int(dof))
    end
end

stat_var(x::AbstractArray{T,1}, dof=true) where T = stat_var(identity, x, dof)

function stat_std(f , x::AbstractArray{T,1}, dof=true)::Union{Float64, Missing} where T <: Union{Missing, INTEGERS, FLOATS}
    sqrt(stat_var(f, x,dof))
end
stat_std(x::AbstractArray{T,1}, dof=true) where T = stat_std(identity, x, dof)

function stat_median(v::AbstractArray{T,1}) where T
    isempty(v) && throw(ArgumentError("median of an empty array is undefined, $(repr(v))"))
    all(ismissing, v) && return missing
    (nonmissingtype(eltype(v))<:AbstractFloat || nonmissingtype(eltype(v))>:AbstractFloat) && any(ISNAN, v) && return convert(eltype(v), NaN)
    nmis::Int = mapreduce(ismissing, +, v)
    n = length(v) - nmis
    mid = div(1+n,2)
    if isodd(n)
        return middle(partialsort(v,mid))
    else
        m = partialsort(v, mid:mid+1)
        return middle(m[1], m[2])
    end
end

function stat_median!(v::AbstractArray{T,1}) where T
    isempty(v) && throw(ArgumentError("median of an empty array is undefined, $(repr(v))"))
    all(ismissing, v) && return missing
    (nonmissingtype(eltype(v))<:AbstractFloat || nonmissingtype(eltype(v))>:AbstractFloat) && any(ISNAN, v) && return convert(eltype(v), NaN)
    nmis::Int = mapreduce(ismissing, +, v)
    n = length(v) - nmis
    mid = div(1+n,2)
    if isodd(n)
        return middle(partialsort!(v,mid))
    else
        m = partialsort!(v, mid:mid+1)
        return middle(m[1], m[2])
    end
end

# finding k largest in an array with missing values
swap!(x,i,j)=x[i],x[j]=x[j],x[i]

function insert_fixed_sorted!(x, item, ord)
    if ord((x[end]), (item))
        return
    else
        x[end] = item
    end
    i = length(x) - 1
    while i > 0
        if ord((x[i+1]),(x[i]))
            swap!(x,i, i+1)
            i -= 1
        else
            break
        end
    end
end

function k_largest(x::AbstractVector{T}, k::Int) where T
    k < 1 && throw(ArgumentError("k must be greater than 1"))
    k == 1 && return [maximum(identity, x)]
    if k>length(x)
        k = length(x)
    end
    res = Vector{T}(undef,k)
    fill!(res, typemin(T))
    for i in 1:length(x)
        insert_fixed_sorted!(res, x[i], (y1,y2)-> y1 > y2)
    end
    res
end
function k_largest(x::AbstractVector{Union{T,Missing}}, k::Int) where T
    k < 1 && throw(ArgumentError("k must be greater than 1"))
    k == 1 && return [maximum(identity, x)]
    all(ismissing, x) && return [missing]
    res = Vector{T}(undef,k)
    fill!(res, typemin(T))
    cnt = 0
    for i in 1:length(x)
        if !ismissing(x[i])
            insert_fixed_sorted!(res, x[i], (y1,y2)-> y1 > y2)
            cnt += 1
        end
    end
    if cnt < k
        res[1:cnt]
    else
        res
    end
end

function k_smallest(x::AbstractVector{T}, k::Int) where T
    k < 1 && throw(ArgumentError("k must be greater than 1"))
    k == 1 && return [minimum(identity, x)]
    if k>length(x)
        k = length(x)
    end
    res = Vector{T}(undef,k)
    fill!(res, typemax(T))
    for i in 1:length(x)
        insert_fixed_sorted!(res, x[i], (y1,y2)-> y1 < y2)
    end
    res
end
function k_smallest(x::AbstractVector{Union{T,Missing}}, k::Int) where T
    k < 1 && throw(ArgumentError("k must be greater than 1"))
    k == 1 && return [minimum(identity, x)]
    all(ismissing, x) && return [missing]
    res = Vector{T}(undef,k)
    fill!(res, typemax(T))
    cnt = 0
    for i in 1:length(x)
        if !ismissing(x[i])
            insert_fixed_sorted!(res, x[i], (y1,y2)-> y1 < y2)
            cnt += 1
        end
    end
    if cnt < k
        res[1:cnt]
    else
        res
    end
end


"""
    topk(x, k; rev = false)

return upto `k` largest nonmissing elements of `x`. When `rev = true` it returns upto `k` smallest nonmissing elements of `x`. When all elements are missing, the function returns `missing`
"""
function topk(x::AbstractVector, k::Int; rev = false)
    if rev
        k_smallest(x, k)
    else
        k_largest(x, k)
    end
end
