module LapackMKL

import ..MadNLP:
    @kwdef, Logger, @debug, @warn, @error,
    AbstractOptions, AbstractLinearSolver, set_options!, tril_to_full!,
    SymbolicException,FactorizationException,SolveException,InertiaException,
    introduce, factorize!, solve!, improve!, is_inertia, inertia, libmkl32

const INPUT_MATRIX_TYPE = :dense

@enum(Algorithms::Int, BUNCHKAUFMAN = 1, LU = 2)
@kwdef mutable struct Options <: AbstractOptions
    lapackmkl_algorithm::Algorithms = BUNCHKAUFMAN
end

mutable struct Solver <: AbstractLinearSolver
    dense::Matrix{Float64}
    fact::Matrix{Float64}
    work
    lwork
    info::Ref{Int32}
    etc::Dict{Symbol,Any}
    opt::Options
    logger::Logger
end

sytrf(uplo,n,a,lda,ipiv,work,lwork,info)=ccall(
    (:dsytrf,libmkl32),
    Cvoid,
    (Ref{UInt8},Ref{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint}),
    uplo,n,a,lda,ipiv,work,lwork,info)
sytrs(uplo,n,nrhs,a,lda,ipiv,b,ldb,info)=ccall(
    (:dsytrs,libmkl32),
    Cvoid,
    (Ref{Cchar},Ref{Cint},Ref{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint}),
    uplo,n,nrhs,a,lda,ipiv,b,ldb,info)
getrf(m,n,a,lda,ipiv,info)=ccall(
    (:dgetrf,libmkl32),
    Cvoid,
    (Ref{Cint},Ref{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint},Ptr{Cint}),
    m,n,a,lda,ipiv,info)
getrs(trans,n,nrhs,a,lda,ipiv,b,ldb,info)=ccall(
    (:dgetrs,libmkl32),
    Cvoid,
    (Ref{Cchar},Ref{Cint},Ref{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint},Ptr{Cdouble},Ref{Cint},Ptr{Cint}),
    trans,n,nrhs,a,lda,ipiv,b,ldb,info)

function Solver(dense::Matrix{Float64};
                option_dict::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                opt=Options(),logger=Logger(),
                kwargs...)

    set_options!(opt,option_dict,kwargs...)
    fact = copy(dense)

    etc = Dict{Symbol,Any}()
    work = Vector{Float64}(undef, 1)
    info=Int32(0)

    return Solver(dense,fact,work,-1,info,etc,opt,logger)
end

function factorize!(M::Solver)
    if M.opt.lapackmkl_algorithm == BUNCHKAUFMAN
        factorize_bunchkaufman!(M)
    elseif M.opt.lapackmkl_algorithm == LU
        factorize_lu!(M)
    else
        error(LOGGER,"Invalid lapackmkl_algorithm")
    end
end
function solve!(M::Solver,x)
    if M.opt.lapackmkl_algorithm == BUNCHKAUFMAN
        solve_bunchkaufman!(M,x)
    elseif M.opt.lapackmkl_algorithm == LU
        solve_lu!(M,x)
    else
        error(LOGGER,"Invalid lapackmkl_algorithm")
    end
end

function factorize_bunchkaufman!(M::Solver)
    haskey(M.etc,:ipiv) || (M.etc[:ipiv] = Vector{Int32}(undef,size(M.dense,1)))
    M.lwork = -1
    # pointer(M.fact)==pointer(M.dense) || M.fact.=M.dense
    M.fact .= M.dense
    sytrf('L',Int32(size(M.fact,1)),M.fact,Int32(size(M.fact,2)),M.etc[:ipiv],M.work,M.lwork,M.info)
    M.lwork = Int32(real(M.work[1]))
    length(M.work) < M.lwork && resize!(M.work,M.lwork)
    sytrf('L',Int32(size(M.fact,1)),M.fact,Int32(size(M.fact,2)),M.etc[:ipiv],M.work,M.lwork,M.info)
    return M
end
function solve_bunchkaufman!(M::Solver,x)
    sytrs('L',Int32(size(M.fact,1)),Int32(1),M.fact,Int32(size(M.fact,2)),M.etc[:ipiv],x,Int32(length(x)),M.info)
    return x
end

function factorize_lu!(M::Solver)
    haskey(M.etc,:ipiv) || (M.etc[:ipiv] = Vector{Int32}(undef,size(M.dense,1)))
    tril_to_full!(M.dense)
    # pointer(M.fact)==pointer(M.dense) || M.fact.=M.dense
    M.fact .= M.dense
    getrf(Int32(size(M.fact,1)),Int32(size(M.fact,2)),M.fact,Int32(size(M.fact,2)),M.etc[:ipiv],M.info)
    return M
end
function solve_lu!(M::Solver,x)
    getrs('N',Int32(size(M.fact,1)),Int32(1),M.fact,Int32(size(M.fact,2)),
          M.etc[:ipiv],x,Int32(length(x)),M.info)
    return x
end

is_inertia(M::Solver) = M.opt.lapackmkl_algorithm == BUNCHKAUFMAN
inertia(M::Solver) = inertia(M.fact,M.etc[:ipiv],M.info[])
function inertia(fact,ipiv,info)
    numneg = num_neg_ev(size(fact,1),fact,ipiv)
    numzero = info > 0 ? 1 : 0
    numpos = size(fact,1) - numneg - numzero
    return (numpos,numzero,numneg)
end

improve!(M::Solver) = false

introduce(M::Solver) = "Lapack-MKL ($(M.opt.lapackmkl_algorithm))"

function num_neg_ev(n,D,ipiv)
    numneg = 0
    t = 0
    for k=1:n
        d = D[k,k];
        if ipiv[k] < 0
            if t==0
                t=abs(D[k+1,k])
                d=(d/t)*D[k+1,k+1]-t
            else
                d=t
                t=0
            end
        end
        d<0 && (numneg += 1)
        if d==0
            numneg = -1
            break
        end
    end
    return numneg
end

end # module

# forgiving names
lapackmkl = LapackMKL
LAPACKMKL = LapackMKL
