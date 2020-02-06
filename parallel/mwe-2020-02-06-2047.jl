# GFlops for vector triad
GFlops(N)=N*2.0/1.0e9

# Create arrays for test
function make_arrays(N)
    a = Array{Float64,1}(undef,N)
    b = Array{Float64,1}(undef,N)
    c = Array{Float64,1}(undef,N)
    d = Array{Float64,1}(undef,N)
    
    Threads.@threads for i=1:N
        a[i]=i
        b[i]=N-i
        c[i]=i
        d[i]=-i
    end
    return(a,b,c,d)
end

# Create shared arrays for test
function make_shared_arrays(N)
    (_a,_b,_c,_d)=make_arrays(N)
    a = SharedArray(_a)
    b = SharedArray(_b)
    c = SharedArray(_c)
    d = SharedArray(_d)
    return(a,b,c,d)
end
