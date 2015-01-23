using Polyopt
using Polyopt.Poly, Polyopt.chordal_embedding, Polyopt.moment
using Polyopt.Symbols, Polyopt.indexmap, Polyopt.vectorize
using Base.Test

approxzero{T<:Number}(p::Polyopt.Poly{T}, threshold=1e-6) = (norm(p.c, Inf) < threshold)


function sparsity{S}(obj::Poly{S})

    v=monomials(obj.deg >> 1, variables(obj.syms))
    l=length(v)
    M=v*v'

    A = zeros(l,l)
    for j=1:l
        for i=1:l
            for k=1:obj.m
                if M[i,j].alpha[1,:] == obj.alpha[k,:]
                    A[i,j] = 1
                    break
                end
            end
        end
    end

    sparse(A)
end

function moment_new(order::Int, syms::Symbols, I::Array{Int})
    v = monomials(order, variables(syms))[I]
    v*v'
end

function momentprob_chordal_new{S}(order::Int, cliques::Array{Array{Int,1},1}, obj::Poly{S})

    v = monomials(2*order, variables(obj.syms))
    l = length(v)
    imap = indexmap(v)

    obj.deg <= 2*order || error("obj has degree higher than 2*order")

    p = vectorize(obj, l, imap)
    mom = Array(Any, length(cliques))

    for k=1:length(cliques)
        println("Moment-matrix for clique $(cliques[k]):\n", moment_new(order, obj.syms, cliques[k]))
        mom[k] = vectorize(moment_new(order, obj.syms, cliques[k]), l, imap)
    end

    MomentProb(order, v,  p, mom, [])
end

# The regular chordal embedding always includes the diagonal of A.
# This version filters out the 1x1 cliques corresponding to such diagonal terms if they are not used.
# It also filters out cliques that does not contain the entire diagonal
function chordal_embedding_new{Tv<:Number,Ti<:Int}(A::SparseMatrixCSC{Tv,Ti})
    cliques = chordal_embedding(A)
    c = Array{Int,1}[]
    for ci=cliques
        Ai = A[ci,ci]
        if minimum(diag(Ai)) > 0
        #if length(ci) > 1 && minimum(diag(Ai)) > 0 && (length(ci) > 1 || norm(A[:,ci]) > 0.0
            push!(c, ci)
        end
    end
    c
end

x, z = variables(["x", "z"])
#f = 2*x^4 + 2*x^3*z - x^2*z^2 + 5*z^4

f = z^2*x^10+2*z^3*x^9+z^4*x^8+2*z^2*x^8+2*z^3*x^7+z^2*x^6

prob = momentprob(f.deg >> 1, f)
X, t, y, solsta = solve_mosek(prob)

v = monomials(f.deg >> 1,[x,z])
@test approxzero( f - t -dot(v,X[1]*v) )

println("f: ", f)

println("full moment-matrix:\n", v*v')
A = sparsity(f)
println("Sparsity of used monominals:\n", full(A))

cliques = chordal_embedding_new(A)
println("cliques for sparsity:", cliques)

prob2 = momentprob_chordal_new(f.deg >> 1, cliques, f)

X2, t2, y2, solsta2 = solve_mosek(prob2)

