using SharedArrays
using BenchmarkTools

function vtriad(N,a,b,c,d)
    @inbounds @fastmath  for i=1:N
        d[i]=a[i]+b[i]*c[i]
    end
end

function runtest(N)
    a = rand(N)
    b = rand(N)
    c = rand(N)
    d = rand(N)
    
    @btime vtriad($N,$a,$b,$c,$d)
    
    sa = SharedArray(a)
    sb = SharedArray(b)
    sc = SharedArray(c)
    sd = SharedArray(d)

    @btime vtriad($N,$sa,$sb,$sc,$sd)
end

runtest(1000)

