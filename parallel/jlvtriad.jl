using ArgParse
using Distributed
using Printf

Distributed.@everywhere using SharedArrays

GFlops(N)=N*2.0/1.0e9

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

function make_shared_arrays(N)
    (_a,_b,_c,_d)=make_arrays(N)
    a = SharedArray(_a)
    b = SharedArray(_b)
    c = SharedArray(_c)
    d = SharedArray(_d)
    return(a,b,c,d)
end


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
function vtriad_scalar(N,nrepeat)
    (a,b,c,d)=make_arrays(N)
    t=@elapsed begin
        @inbounds @fastmath for j=1:nrepeat
            for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end

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

Distributed.@everywhere function _kernel(a,b,c,d,n0,n1)
    @inbounds @fastmath for i=n0:n1
        d[i]=a[i]+b[i]*c[i]
    end
    return 0
end

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


##################################################################################
function vtriad_scalar_shared(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    t=@elapsed begin
        @inbounds @fastmath for j=1:nrepeat
            for i=1:N
                d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end


function vtriad_multiprocess_spawn(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    
    ntasks=Threads.nthreads()
    loop_begin,loop_end=partition(N,ntasks)
    
    t=@elapsed begin
        for j=1:nrepeat
            mapreduce(task->fetch(task),+,[Distributed.@spawn _kernel(a,b,c,d,loop_begin[i],loop_end[i]) for i=1:ntasks])
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end


function vtriad_multiprocess_distributed(N,nrepeat)
    (a,b,c,d)=make_shared_arrays(N)
    t_parallel=@elapsed begin
        for j=1:nrepeat
                Distributed.@sync Distributed.@distributed for i=1:N
                @inbounds @fastmath  d[i]=a[i]+b[i]*c[i]
            end
        end
    end
    GC.gc()
    return [N,GFlops(N*nrepeat)/t]
end



##################################################################################
function run_vtriad(vtriad;N0=1000,ppomag=4,nrun=41,flopcount=5.0e8)
    vsz=vsizes(N0=N0,ppomag=ppomag,nrun=nrun)
    result=zeros(2,length(vsz))
    for i=1:length(vsz)
        result[:,i].=vtriad(vsz[i],Int(ceil(flopcount/vsz[i])))
    end
    return result
end


function main(ARGS)
    
    settings = ArgParseSettings()
    add_arg_table(settings,
                  ["--scalar"],          Dict(:help => "scalar vtriad",:action => :store_true),
                  ["--scalar-shared"],          Dict(:help => "scalar vtriad with shared arrays",:action => :store_true),
                  ["--multithread-threads"],     Dict(:help => "Threads.@threads",:action => :store_true),
                  ["--multithread-spawn"],     Dict(:help => "Threads.@spawn",:action => :store_true),
                  ["--multiprocess-spawn"],     Dict(:help => "Distributed.@spawn with SharedArrays",:action => :store_true),
                  ["--multiprocess-distributed"],     Dict(:help => "Distributed.@distrubuted with SharedArrays",:action => :store_true),
                  )
    
    parsed_args=parse_args(ARGS, settings)
    
    # Approximate number of FLOPs per measurement 
    flopcount=5.0e8
    
    # Smallest array size 
    N0=1000
    
    # Data points per orders of magnitude (of array size)
    ppomag=8
    
    # Number of array size increases
    nrun=41
    

    if parsed_args["multiprocess-spawn"]
        @printf("# multiprocess-spawn nprocs=%d\n",Distributed.nprocs())
        result=run_vtriad(vtriad_multiprocess_spawn;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar"]
        @printf("# scalar\n")
        result=run_vtriad(vtriad_scalar;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["scalar-shared"]
        @printf("# scalar-shared\n")
        result=run_vtriad(vtriad_scalar_shared;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["multithread-spawn"]
        @printf("# multithread-spawn nthreads=%d\n",Threads.nthreads())
        result=run_vtriad(vtriad_multithread_spawn;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    elseif parsed_args["multithread-threads"]
        @printf("# multiprocess-threads nthreads=%d\n",Threads.nthreads())
        result=run_vtriad(vtriad_multithread_threads;N0=N0,ppomag=ppomag,nrun=nrun,flopcount=flopcount)
    else
        return
    end
    for i=1:size(result,2)
        @printf("% 10d %6.3f\n",result[1,i], result[2,i])
    end
end

main(ARGS)
