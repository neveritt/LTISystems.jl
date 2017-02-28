immutable StateSpace{T,S,M1,M2,M3,M4} <: LtiSystem{T,S}
  A::M1
  B::M2
  C::M3
  D::M4
  nx::Int
  nu::Int
  ny::Int
  Ts::Float64

  # Continuous-time, single-input-single-output state-space model
  @compat function (::Type{StateSpace}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix}(A::M1, B::M2, C::M3, D::Real)
    d = fill(D,1,1)
    nx, nu, ny = _sscheck(A, B, C, d)
    new{Val{:siso},Val{:cont},M1,M2,M3,typeof(d)}(A, B, C, d, nx, nu, ny, zero(Float64))
  end

  # Discrete-time, single-input-single-output state-space model
  @compat function (::Type{StateSpace}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix}(A::M1, B::M2, C::M3, D::Real, Ts::Real)
    d = fill(D,1,1)
    nx, nu, ny = _sscheck(A, B, C, d, Ts)
    new{Val{:siso},Val{:disc},M1,M2,M3,typeof(d)}(A, B, C, d, nx, nu, ny,
      convert(Float64, Ts))
  end

  # Continuous-time, multi-input-multi-output state-space model
  @compat function (::Type{StateSpace}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix,M4<:AbstractMatrix}(A::M1, B::M2, C::M3, D::M4)
    nx, nu, ny = _sscheck(A, B, C, D)
    new{Val{:mimo},Val{:cont},M1,M2,M3,M4}(A, B, C, D, nx, nu, ny, zero(Float64))
  end
  @compat function (::Type{StateSpace{Val{:siso}}}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix,M4<:AbstractMatrix}(A::M1, B::M2, C::M3, D::M4)
    @assert size(D) == (1,1) "StateSpace: The system should be SISO"
    StateSpace(A, B, C, D[1])
  end

  # Discrete-time, multi-input-multi-output state-space model
  @compat function (::Type{StateSpace}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix,M4<:AbstractMatrix}(A::M1, B::M2, C::M3, D::M4, Ts::Real)
    nx, nu, ny = _sscheck(A, B, C, D, Ts)
    new{Val{:mimo},Val{:disc},M1,M2,M3,M4}(A, B, C, D, nx, nu, ny,
      convert(Float64, Ts))
  end
  @compat function (::Type{StateSpace{Val{:siso}}}){M1<:AbstractMatrix,M2<:AbstractMatrix,
    M3<:AbstractMatrix,M4<:AbstractMatrix}(A::M1, B::M2, C::M3, D::M4, Ts::Real)
    @assert size(D) == (1,1) "StateSpace: The system should be SISO"
    StateSpace(A, B, C, D[1], Ts)
  end
end

# Enforce state-space type invariance
function _sscheck(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix,
  D::AbstractMatrix, Ts::Real = zero(Float64))
  na, ma  = size(A)
  nb, mb  = size(B)
  nc, mc  = size(C)
  nd, md  = size(D)

  @assert na == ma                    "StateSpace: A must be square"
  @assert eltype(A) <: Real           "StateSpace: A must be a matrix of real numbers"
  @assert na == nb                    "StateSpace: A and B must have the same number of rows"
  @assert eltype(B) <: Real           "StateSpace: B must be a matrix of real numbers"
  @assert ma == mc                    "StateSpace: A and C must have the same number of columns"
  @assert eltype(C) <: Real           "StateSpace: C must be a matrix of real numbers"
  @assert nc == nd && nc ≥ 1          "StateSpace: C and D must have the same number (≥1) of rows"
  @assert mb == md && mb ≥ 1          "StateSpace: B and D must have the same number (≥1) of columns"
  @assert eltype(D) <: Real           "StateSpace: D must be a matrix of real numbers"
  @assert Ts ≥ zero(Ts) && !isinf(Ts) "StateSpace: Ts must be non-negative real number"

  nx = na
  nu = mb
  ny = nc

  return nx, nu, ny
end

# Outer constructors
# SISO
ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix, D::Real = zero(Float64)) =
  StateSpace(A, B, C, D)

ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix, D::Real, Ts::Real)    =
  StateSpace(A, B, C, D, Ts)

ss(D::Real)           = StateSpace(zeros(0,0), zeros(0,1), zeros(1,0), D)
ss(D::Real, Ts::Real) = StateSpace(zeros(0,0), zeros(0,1), zeros(1,0), D, Ts)

# MIMO
ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix, D::AbstractMatrix)    =
  StateSpace(A, B, C, D)

function ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix,
  D::AbstractVector)
  @assert isempty(D) "ss(A,B,C,D): D can only be an empty vector"
  d = spzeros(Float64, size(C,1), size(B,2))
  StateSpace(A, B, C, d)
end

ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix, D::AbstractMatrix,
  Ts::Real) = StateSpace(A, B, C, D, Ts)

function ss(A::AbstractMatrix, B::AbstractMatrix, C::AbstractMatrix,
  D::AbstractVector, Ts::Real)
  @assert isempty(D) "ss(A,B,C,D): D can only be an empty vector"
  d = spzeros(Float64, size(C,1), size(B,2))
  StateSpace(A, B, C, d, Ts)
end

ss(D::AbstractMatrix)           = StateSpace(zeros(0,0), zeros(0, size(D,2)),
  zeros(size(D,1), 0), D)
ss(D::AbstractMatrix, Ts::Real) = StateSpace(zeros(0,0), zeros(0, size(D,2)),
  zeros(size(D,1), 0), D, Ts)

# Catch-all for convenience when dealing with scalars, vectors, etc.
function _reshape(A::Union{Real,VecOrMat}, B::Union{Real,VecOrMat},
  C::Union{Real,VecOrMat})
  a = isa(A, Real) ? fill(A,1,1) : reshape(A, size(A,1,2)...)
  b = isa(B, Real) ? fill(B,1,1) : reshape(B, size(B,1,2)...)
  c = isa(C, Real) ? fill(C,1,1) : reshape(C, size(C,1,2)...)
  return a, b, c
end
ss(A::Union{Real,VecOrMat}, B::Union{Real,VecOrMat}, C::Union{Real,VecOrMat})
  = ss(_reshape(A, B, C)...)
ss(A::Union{Real,VecOrMat}, B::Union{Real,VecOrMat}, C::Union{Real,VecOrMat}, D)
  = ss(_reshape(A, B, C)..., D)
ss(A::Union{Real,VecOrMat}, B::Union{Real,VecOrMat}, C::Union{Real,VecOrMat}, D,
  Ts::Real) = ss(_reshape(A, B, C)..., D, Ts)

# Interfaces
samplingtime(s::StateSpace) = s.Ts

numstates(s::StateSpace)    = s.nx
numinputs(s::StateSpace)    = s.nu
numoutputs(s::StateSpace)   = s.ny

# Iteration interface
start(s::StateSpace{Val{:mimo}})        = start(s.D)
next(s::StateSpace{Val{:mimo}}, state)  = (s[state], state+1)
done(s::StateSpace{Val{:mimo}}, state)  = done(s.D, state)

eltype{S,M1}(::Type{StateSpace{Val{:mimo},Val{S},M1}}) =
  StateSpace{Val{:siso},Val{S},M1}

length(s::StateSpace{Val{:mimo}}) = length(s.D)
size(s::StateSpace, d)            = size(s.D, d)

# Indexing of MIMO systems
function getindex(s::StateSpace{Val{:mimo},Val{:cont}}, row::Int, col::Int)
  (1 ≤ row ≤ s.ny && 1 ≤ col ≤ s.nu) || throw(BoundsError(s.D, (row,col)))
  StateSpace(s.A, view(s.B, :, col:col), view(s.C, row:row, :), s.D[row, col])
end

function getindex(s::StateSpace{Val{:mimo},Val{:disc}}, row::Int, col::Int)
  (1 ≤ row ≤ s.ny && 1 ≤ col ≤ s.nu) || throw(BoundsError(s.D, (row,col)))
  StateSpace(s.A, view(s.B, :, col:col), view(s.C, row:row, :), s.D[row, col], s.Ts)
end

function getindex(s::StateSpace{Val{:mimo}}, idx::Int)
  (1 ≤ idx ≤ length(s.D)) || throw(BoundsError(s.D, idx))
  col, row  = divrem(idx-1, s.ny)
  col       += 1
  row       += 1
  s[row, col]
end

function getindex(s::StateSpace{Val{:mimo},Val{:cont}}, rows::AbstractVector{Int},
  cols::AbstractVector)
  1 ≤ minimum(rows) ≤ maximum(rows) ≤ s.ny || throw(BoundsError(s.D, rows))
  1 ≤ minimum(cols) ≤ maximum(cols) ≤ s.nu || throw(BoundsError(s.D, cols))

  StateSpace(s.A, view(s.B, :, cols), view(s.C, rows, :), view(s.D, rows, cols))
end

function getindex(s::StateSpace{Val{:mimo},Val{:disc}}, rows::AbstractVector{Int},
  cols::AbstractVector)
  1 ≤ minimum(rows) ≤ maximum(rows) ≤ s.ny || throw(BoundsError(s.D, rows))
  1 ≤ minimum(cols) ≤ maximum(cols) ≤ s.nu || throw(BoundsError(s.D, cols))

  StateSpace(s.A, view(s.B, :, cols), view(s.C, rows, :), view(s.D, rows, cols), s.Ts)
end

function getindex(s::StateSpace{Val{:mimo}}, indices::AbstractVector{Int})
  1 ≤ minimum(indices) ≤ maximum(indices) ≤ length(s.D) || throw(BoundsError(s.D, indices))

  temp  = map(x->divrem(x-1, s.ny), indices)
  cols  = map(x->x[1]+1, temp)
  rows  = map(x->x[2]+1, temp)

  s[rows, cols]
end

getindex(s::StateSpace{Val{:mimo}}, rows, ::Colon)    = s[rows, 1:s.nu]
getindex(s::StateSpace{Val{:mimo}}, ::Colon, cols)    = s[1:s.ny, cols]
getindex(s::StateSpace{Val{:mimo}}, ::Colon)          = s[1:end]
getindex(s::StateSpace{Val{:mimo}}, ::Colon, ::Colon) = s[1:s.ny,1:s.nu]
endof(s::StateSpace{Val{:mimo}})                      = endof(s.D)

# Conversion and promotion
promote_rule{T<:Real,S}(::Type{T}, ::Type{StateSpace{Val{:siso},Val{S}}}) =
  StateSpace{Val{:siso},Val{S}}
promote_rule{T<:AbstractMatrix,Val{S}}(::Type{T}, ::Type{StateSpace{Val{:mimo},Val{S}}}) =
  StateSpace{Val{:mimo},Val{S}}

convert(::Type{StateSpace{Val{:siso},Val{:cont}}}, g::Real) = ss(g)
convert(::Type{StateSpace{Val{:siso},Val{:disc}}}, g::Real) = ss(g, zero(Float64))
convert(::Type{StateSpace{Val{:mimo},Val{:cont}}}, g::AbstractMatrix) = ss(g)
convert(::Type{StateSpace{Val{:mimo},Val{:disc}}}, g::AbstractMatrix) = ss(g, zero(Float64))

# Multiplicative and additive identities (meaningful only for SISO)
one(::Type{StateSpace{Val{:siso},Val{:cont}}})  = ss(one(Float64))
one(::Type{StateSpace{Val{:siso},Val{:disc}}})  = ss(one(Float64), zero(Float64))
zero(::Type{StateSpace{Val{:siso},Val{:cont}}}) = ss(zero(Float64))
zero(::Type{StateSpace{Val{:siso},Val{:disc}}}) = ss(zero(Float64), zero(Float64))

one(s::StateSpace{Val{:siso},Val{:cont}})   = StateSpace(similar(s.A,0,0),
  similar(s.B,0,1), similar(s.C,1,0), one(eltype(s.D)))
one(s::StateSpace{Val{:siso},Val{:disc}})   = StateSpace(similar(s.A,0,0),
  similar(s.B,0,1), similar(s.C,1,0), one(eltype(s.D)), s.Ts)
zero(s::StateSpace{Val{:siso},Val{:cont}})  = StateSpace(similar(s.A,0,0),
  similar(s.B,0,1), similar(s.C,1,0), zero(eltype(s.D)))
zero(s::StateSpace{Val{:siso},Val{:disc}})  = StateSpace(similar(s.A,0,0),
  similar(s.B,0,1), similar(s.C,1,0), zero(eltype(s.D)), s.Ts)

# Inverse of a state-space model
function _ssinv(s::StateSpace)
  if s.ny ≠ s.nu
    warn("inv(sys): s.ny ≠ s.nu")
    throw(DomainError())
  end

  try
    Dinv = inv(s.D);
    Ainv = s.A - s.B*Dinv*s.C;
    Binv = s.B*Dinv
    Cinv = -Dinv*s.C
    return Ainv, Binv, Cinv, Dinv
  catch err
    warn("inv(sys): sys is not invertible")
    throw(DomainError())
  end
end

function inv(s::StateSpace{Val{:siso},Val{:cont}})
  Ainv, Binv, Cinv, Dinv = _ssinv(s)
  StateSpace(Ainv, Binv, Cinv, Dinv[1])
end

function inv(s::StateSpace{Val{:siso},Val{:disc}})
  Ainv, Binv, Cinv, Dinv = _ssinv(s)
  StateSpace(Ainv, Binv, Cinv, Dinv[1], s.Ts)
end

function inv(s::StateSpace{Val{:mimo},Val{:cont}})
  Ainv, Binv, Cinv, Dinv = _ssinv(s)
  StateSpace(Ainv, Binv, Cinv, Dinv)
end

function inv(s::StateSpace{Val{:mimo},Val{:disc}})
  Ainv, Binv, Cinv, Dinv = _ssinv(s)
  StateSpace(Ainv, Binv, Cinv, Dinv, s.Ts)
end

# Invariant zeros of a state-space model
function zeros(s::StateSpace)
  Ar, Br, Cr, Dr, mr, nr, pr        = reduce(s.A, s.B, s.C, s.D)
  if nr == 0
    return Complex{Float64}[]
  end
  Arc, Brc, Crc, Drc, mrc, nrc, prc = reduce(Ar.', Cr.', Br.', Dr.')
  if nrc == 0
    return Complex{Float64}[]
  end

  svdobj  = svdfact([Crc Drc], thin = false)
  W       = flipdim(svdobj.Vt', 2)
  Af      = [Arc Brc]*W[:, 1:nrc]

  if mrc == 0
    zerovalues = eigfact(Af).values
    return zerovalues
  else
    Bf    = W[1:nrc,1:nrc]
    zerovalues = eigfact(Af, Bf).values
    return zerovalues
  end
end

# Transmission zeros of a state-space model
tzeros(s::StateSpace) = zeros(minreal(s))

# Poles of a state-space model
function poles(s::StateSpace)
  Aₘ, _, _, _ = minreal(s.A, s.B, s.C, s.D)
  return eigfact(Aₘ).values
end

# Negative of a state-space model
-(s::StateSpace{Val{:siso},Val{:cont}}) = StateSpace(s.A, s.B, -s.C, -s.D[1])
-(s::StateSpace{Val{:siso},Val{:disc}}) = StateSpace(s.A, s.B, -s.C, -s.D[1], s.Ts)
-(s::StateSpace{Val{:mimo},Val{:cont}}) = StateSpace(s.A, s.B, -s.C, -s.D)
-(s::StateSpace{Val{:mimo},Val{:disc}}) = StateSpace(s.A, s.B, -s.C, -s.D, s.Ts)

# Addition
function _ssparallel{T1,T2,S}(s1::StateSpace{Val{T1},Val{S}},
  s2::StateSpace{Val{T2},Val{S}})
  if s1.Ts ≉ s2.Ts && s1.Ts ≠ zero(s1.Ts) && s2.Ts ≠ zero(s2.Ts)
    warn("parallel(s1,s2): Sampling time mismatch")
    throw(DomainError())
  end

  if size(s1) ≠ size(s2)
    warn("parallel(s1,s2): size(s1) ≠ size(s2)")
    throw(DomainError())
  end

  T = promote_type(eltype(s1.A), eltype(s2.A))
  a = vcat(hcat(s1.A, zeros(T, s1.nx, s2.nx)),
        hcat(zeros(T, s2.nx, s1.nx), s2.A))
  b = vcat(s1.B, s2.B)
  c = hcat(s1.C, s2.C)
  d = s1.D + s2.D

  return a, b, c, d, max(s1.Ts, s2.Ts)
end

function +(s1::StateSpace{Val{:siso},Val{:cont}},
  s2::StateSpace{Val{:siso},Val{:cont}})
  a, b, c, d, _ = _ssparallel(s1, s2)
  StateSpace(a, b, c, d[1])
end

function +(s1::StateSpace{Val{:siso},Val{:disc}},
  s2::StateSpace{Val{:siso},Val{:disc}})
  a, b, c, d, Ts = _ssparallel(s1, s2)
  StateSpace(a, b, c, d[1], Ts)
end

function +{T1,T2}(s1::StateSpace{Val{T1},Val{:cont}},
  s2::StateSpace{Val{T2},Val{:cont}})
  a, b, c, d, _ = _ssparallel(s1, s2)
  StateSpace(a, b, c, d)
end

function +{T1,T2}(s1::StateSpace{Val{T1},Val{:disc}},
  s2::StateSpace{Val{T2},Val{:disc}})
  a, b, c, d, Ts = _ssparallel(s1, s2)
  StateSpace(a, b, c, d, Ts)
end

.+(s1::StateSpace{Val{:siso}}, s2::StateSpace{Val{:siso}}) = +(s1, s2)

+{T}(s::StateSpace{Val{T},Val{:cont}}, g) = +(s, ss(g))
+{T}(s::StateSpace{Val{T},Val{:disc}}, g) = +(s, ss(g, zero(Float64)))
+{T}(g, s::StateSpace{Val{T},Val{:cont}}) = +(ss(g), s)
+{T}(g, s::StateSpace{Val{T},Val{:disc}}) = +(ss(g, zero(Float64)), s)

.+(s::StateSpace{Val{:siso}}, g::Real)    = +(s, g)
.+(g::Real, s::StateSpace{Val{:siso}})    = +(g, s)

# Subtraction
-(s1::StateSpace, s2::StateSpace) = +(s1, -s2)

.-(s1::StateSpace{Val{:siso}}, s2::StateSpace{Val{:siso}}) = -(s1, s2)

-{T}(s::StateSpace{Val{T},Val{:cont}}, g) = -(s, ss(g))
-{T}(s::StateSpace{Val{T},Val{:disc}}, g) = -(s, ss(g, zero(Float64)))
-{T}(g, s::StateSpace{Val{T},Val{:cont}}) = -(ss(g), s)
-{T}(g, s::StateSpace{Val{T},Val{:disc}}) = -(ss(g, zero(Float64)), s)

.-(s::StateSpace{Val{:siso}}, g::Real)    = -(s, g)
.-(g::Real, s::StateSpace{Val{:siso}})    = -(g, s)

# Multiplication
function _ssseries{T1,T2,S}(s1::StateSpace{Val{T1},S}, s2::StateSpace{Val{T2},S})
  # Remark: s1*s2 implies u -> s2 -> s1 -> y

  if s1.Ts ≉ s2.Ts && s1.Ts ≠ zero(s1.Ts) && s2.Ts == zero(s2.Ts)
    warn("series(s1,s2): Sampling time mismatch")
    throw(DomainError())
  end

  if s1.nu ≠ s2.ny
    warn("series(s1,s2): s1.nu ≠ s2.ny")
    throw(DomainError())
  end

  T = promote_type(eltype(s1.A), eltype(s1.B), eltype(s2.A), eltype(s2.C))

  a = vcat(hcat(s1.A, s1.B*s2.C),
        hcat(zeros(T, s2.nx, s1.nx), s2.A))
  b = vcat(s1.B*s2.D, s2.B)
  c = hcat(s1.C, s1.D*s2.C)
  d = s1.D * s2.D

  return a, b, c, d, max(s1.Ts, s2.Ts)
end

function *(s1::StateSpace{Val{:siso},Val{:cont}},
  s2::StateSpace{Val{:siso},Val{:cont}})
  a, b, c, d, _ = _ssseries(s1, s2)
  StateSpace(a, b, c, d[1])
end

function *(s1::StateSpace{Val{:siso},Val{:disc}},
  s2::StateSpace{Val{:siso},Val{:disc}})
  a, b, c, d, Ts = _ssseries(s1, s2)
  StateSpace(a, b, c, d[1], Ts)
end

function *{T1,T2}(s1::StateSpace{Val{T1},Val{:cont}},
  s2::StateSpace{Val{T2},Val{:cont}})
  a, b, c, d, _ = _ssseries(s1, s2)
  StateSpace(a, b, c, d)
end

function *{T1,T2}(s1::StateSpace{Val{T1},Val{:disc}},
  s2::StateSpace{Val{T2},Val{:disc}})
  a, b, c, d, Ts = _ssseries(s1, s2)
  StateSpace(a, b, c, d, Ts)
end

.*(s1::StateSpace{Val{:siso}}, s2::StateSpace{Val{:siso}}) = *(s1, s2)

*{T}(s::StateSpace{Val{T},Val{:cont}}, g) = *(s, ss(g))
*{T}(s::StateSpace{Val{T},Val{:disc}}, g) = *(s, ss(g, zero(Float64)))
*{T}(g, s::StateSpace{Val{T},Val{:cont}}) = *(ss(g), s)
*{T}(g, s::StateSpace{Val{T},Val{:disc}}) = *(ss(g, zero(Float64)), s)

.*(s::StateSpace{Val{:siso}}, g::Real)    = *(s, g)
.*(g::Real, s::StateSpace{Val{:siso}})    = *(g, s)

# Division
/(s1::StateSpace, s2::StateSpace)         = *(s1, inv(s2))

./(s1::StateSpace{Val{:siso}}, s2::StateSpace{Val{:siso}}) = /(s1, s2)

/{T}(s::StateSpace{Val{T},Val{:cont}}, g) = /(s, ss(g))
/{T}(s::StateSpace{Val{T},Val{:disc}}, g) = /(s, ss(g, zero(Float64)))
/{T}(g, s::StateSpace{Val{T},Val{:cont}}) = /(ss(g), s)
/{T}(g, s::StateSpace{Val{T},Val{:disc}}) = /(ss(g, zero(Float64)), s)

./(s::StateSpace{Val{:siso}}, g::Real)    = /(s, g)
./(g::Real, s::StateSpace{Val{:siso}})    = /(g, s)
