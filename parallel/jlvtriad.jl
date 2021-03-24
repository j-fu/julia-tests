description="""
Schoenauer vector triade benchmark    
See e.g. https://blogs.fau.de/hager/archives/tag/benchmarking

Run multithreaded test e.g. with
JULIA_NUM_THREADS=4 julia --multithread-threads

Run multiporcess test e.g. with
julia -p 4 --multiprocess-distributed

"""

using ArgParse
using Distributed

using Printf

Distributed.@everywhere using SharedArrays
Distributed.@everywhere using LoopVectorization
################################################################
# Helper methods

# GFlops for vector triad
GFlops(N)=N*2.0/1.0e9

# Partition the range 1:N for a number of tasks
function partition(N,ntasks)
    loop_begin=zeros(Int64,ntasks)
    loop_end=zeros(Int64,ntasks)
    for itask=1:ntasks
        ltask=Int(floor(N/ntasks))
        loop_begin[itask]=(itask-1)*ltask+1
        if itask==ntasks # adjust last task length
            ltask=N-(ltask*(ntasks-1))
        end
        loop_end[itask]=loop_begin[itask]+ltask-1
    end
    return (loop_begin,loop_end)
end

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

# Create an array of vector lengths of size nrun
# starting with N0 and increasing in geometrica progression.
# ppomag denotes the number of 
# elements per order of magnitude.
# Try to keep full powers of 10 at once.
function vsizes(;N0=1000,ppomag=8,nrun=41)
    vsz=[N0]
    N=N0
    N0*=10
    for irun=1:nrun-1
        N=N*10^(1.0/ppomag)
        if (irun%ppomag==0)
            N=N0
            N0*=10
        end
        push!(vsz,Int(ceil(N)))
    end
    return vsz
end


##################################################################################
# Tests

# Scalar operation
# In all cases, the triad is run nrepeat times, in order
# to use the same measurement method as in the C code.
function vtriad_scalar(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
            @inbounds @fastmath  for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end

# Same with avx
function vtriad_scalar_avx(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
            @avx for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end

# fork-join style operation using  Threads.@threads 
function vtriad_multithread_threads(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
             Threads.@threads for i=1:N
                 @inbounds @fastmath  d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end





# Kernel for spawn bases operation
Distributed.@everywhere function _kernel_avx(a,b,c,d,n0,n1)
    @avx for i=n0:n1
        d[i]=a[i]+b[i]*c[i]
    end
    return 0
end

function _kernel(a,b,c,d,n0,n1)
    @inbounds @fastmath  for i=n0:n1
        d[i]=a[i]+b[i]*c[i]
    end
    return 0
end



# Operation using  Threads.@spawn
function vtriad_multithread_spawn(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    ntasks=Threads.nthreads()
    loop_begin,loop_end=partition(N,ntasks)
    t=@elapsed begin
        for j=1:nrepeat
            mapreduce(task->fetch(task),+,[Threads.@spawn _kernel(a,b,c,d,loop_begin[i],loop_end[i]) for i=1:ntasks])
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end


function threadcall_fetch(f,args...)
    t=Threads.@spawn f(args...)
    fetch(t)
end

# Operation using  Threads.@spawn (slower than multithead_spawn...)
function vtriad_multithread_spawn_asyncmap(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    ntasks=Threads.nthreads()
    loop_begin,loop_end=partition(N,ntasks)
    function spwn(a,b,c,d,n0,n1)
        t=Threads.@spawn _kernel(a,b,c,d,n0,n1)
        fetch(t)
    end
    t=@elapsed begin
        for j=1:nrepeat
            res=asyncmap(i->threadcall_fetch(_kernel,a,b,c,d,loop_begin[i],loop_end[i]),1:ntasks)
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end



# Run scalar benchmark using SharedArrays
function vtriad_scalar_shared(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
            @inbounds @fastmath  for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end

# Run scalar benchmark using SharedArrays
function vtriad_scalar_shared_avx(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
            @avx for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end


# Multiprocessing using Distributed.@spawn and SharedArrays
function vtriad_multiprocess_spawn(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    
    ntasks=Distributed.nprocs()
    loop_begin,loop_end=partition(N,ntasks)
    
    t=@elapsed begin
        for j=1:nrepeat
            mapreduce(task->fetch(task),+,[Distributed.@spawn _kernel_avx(a,b,c,d,loop_begin[i],loop_end[i]) for i=1:ntasks])
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end



# Multiprocessing using Distributed.@distributed and SharedArrays
function vtriad_multiprocess_distributed(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    t=@elapsed begin
        for j=1:nrepeat
            Distributed.@sync Distributed.@distributed for i=1:N
                @avx  d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end



##################################################################################
# Test driver

function run_vtriad(vtriad;N0=1000,ppomag=4,nrun=41,flopcount=5.0e8)
    # Create vector sizes
    vsz=vsizes(N0=N0,ppomag=ppomag,nrun=nrun)

    # Create result array
    result=zeros(2,length(vsz))

    # Run test with increasing sizes, adapting nrepeat as to keep the
    # number of operations constant and time a large enough batch
    for i=1:length(vsz)
        result[:,i].=vtriad(vsz[i],Int(ceil(flopcount/vsz[i])))
    end
    return result
end


function main(ARGS)
    
    settings = ArgParseSettings()
    settings.preformatted_description=true
    settings.description=description
    @add_arg_table settings begin

        "--nrun"   help= "number of runs"
        default=41
        
        "--flopcount"  help= "number of flops per run"
        default=5.0e8
        
        "--N0"  help= "smallest array size"
        default=1000
        
        "--ppomag"  help= "points per order of magnitude"
        default=8

        "--scalar" help= "scalar vtriad"
        action=:store_true

        "--scalar-avx" help= "scalar vtriad+avx"
        action=:store_true

        "--scalar-shared" help= "scalar vtriad with shared arrays"
        action=:store_true

        "--scalar-shared-avx" help= "scalar vtriad with shared arrays+avx"
        action=:store_true
        
        "--multithread-threads" help= "Threads.@threads"
        action=:store_true
        
        "--multithread-spawn"  help= "Threads.@spawn"
        action=:store_true
        
        "--multiprocess-spawn"  help= "Distributed.@spawn with SharedArrays"
        action=:store_true
        
        "--multiprocess-distributed" help= "Distributed.@distrubuted with SharedArrays"
        action=:store_true

    end
    parsed_args=parse_args(ARGS, settings)
    
    flopcount=parsed_args["flopcount"]
    ppomag=parsed_args["ppomag"]
    N0=parsed_args["N0"]
    nrun=parsed_args["nrun"]
    
    # Run test
    if parsed_args["multiprocess-spawn"]
        @printf("# multiprocess-spawn nprocs=%d\n",Distributed.nprocs())
        result=run_vtriad(vtriad_multiprocess_spawn;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["multiprocess-distributed"]
        @printf("# multiprocess-distributed nprocs=%d\n",Distributed.nprocs())
        result=run_vtriad(vtriad_multiprocess_distributed;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar"]
        @printf("# scalar\n")
        result=run_vtriad(vtriad_scalar;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar-avx"]
        @printf("# scalar-avx\n")
        result=run_vtriad(vtriad_scalar_avx;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar-shared"]
        @printf("# scalar-shared\n")
        result=run_vtriad(vtriad_scalar_shared;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar-shared-avx"]
        @printf("# scalar-shared-avx\n")
        result=run_vtriad(vtriad_scalar_shared_avx;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["multithread-spawn"]
        @printf("# multithread-spawn nthreads=%d\n",Threads.nthreads())
        result=run_vtriad(vtriad_multithread_spawn;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["multithread-threads"]
        @printf("# multithread-threads nthreads=%d\n",Threads.nthreads())
        result=run_vtriad(vtriad_multithread_threads;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    else
        return
    end

    # Print result
    @printf("# Array size  GFlops/s\n")
    for i=1:size(result,2)
        @printf("% 10d %6.3f\n",result[1,i], result[2,i])
    end
end

main(ARGS)

