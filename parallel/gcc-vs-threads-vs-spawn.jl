using PyPlot
using DelimitedFiles
using Hwloc
using Printf






GiB=2^30
MiB=2^20
kiB=2^10


topology=Hwloc.topology_load()
nsockets=collectobjects(topology,:Package) |> length
ncores=collectobjects(topology,:Core) |> length
L3Cache=first(collectobjects(topology,:L3Cache)).attr.size÷MiB
L2Cache=first(collectobjects(topology,:L2Cache)).attr.size÷kiB
L1Cache=first(collectobjects(topology,:L1Cache)).attr.size÷kiB
RAM=Sys.total_memory()÷GiB

CPU="$(nsockets) socket(s) $(ncores) cores $(first(Sys.cpu_info()).model)"
mem="RAM=$(RAM)GiB Cache: L3=$(L3Cache)MiB  L2=$(L2Cache)kiB  L1=$(L1Cache)kiB"


scalar=readdlm("jlvtriad-scalar.dat",comments=true)'
cvtriad=readdlm("cvtriad-omp4.dat",comments=true)'
threads=readdlm("jlvtriad-threads-4.dat",comments=true)'
spawn=readdlm("jlvtriad-spawn-4.dat",comments=true)'


PyPlot.rc("font", size=8)
PyPlot.clf()
PyPlot.semilogx(scalar[1,:],scalar[2,:],"r--",label="julia scalar")
PyPlot.semilogx(cvtriad[1,:],cvtriad[2,:],"g--",label="gcc scalar")
PyPlot.semilogx(cvtriad[1,:],cvtriad[3,:],"g",label="4 threads gcc omp")
PyPlot.semilogx(cvtriad[1,:],cvtriad[4,:],"g-.",label="4 threads gcc omp dynamic")
PyPlot.semilogx(threads[1,:],threads[2,:],"r",label="4 threads julia Threads.@threads")
PyPlot.semilogx(spawn[1,:],spawn[2,:],"b",label="4 threads julia Threads.@spawn")
PyPlot.legend()
PyPlot.grid()
PyPlot.ylim(0,20)
PyPlot.xlabel("Array Size")
PyPlot.ylabel("GFlops/s")
PyPlot.title("Julia vs GCC Thread Performance: A[i]=B[i]+C[i]*D[i]\n$(CPU)\n$(mem)")
PyPlot.savefig("gcc-vs-threads-vs-spawn.pdf")
PyPlot.savefig("gcc-vs-threads-vs-spawn.png")
