using PyPlot
using DelimitedFiles

CPU=Sys.cpu_info()[1].model

scalar=readdlm("jlvtriad-scalar.dat",comments=true)'
cvtriad=readdlm("cvtriad-omp4.dat",comments=true)'
threads=readdlm("jlvtriad-threads-4.dat",comments=true)'
spawn=readdlm("jlvtriad-spawn-4.dat",comments=true)'


PyPlot.clf()
PyPlot.semilogx(scalar[1,:],scalar[2,:],"r--",label="julia scalar")
PyPlot.semilogx(cvtriad[1,:],cvtriad[2,:],"g--",label="gcc scalar")
PyPlot.semilogx(cvtriad[1,:],cvtriad[3,:],"g",label="gcc #pragma omp")
PyPlot.semilogx(cvtriad[1,:],cvtriad[4,:],"g-.",label="gcc #pragma omp dynamic")
PyPlot.semilogx(threads[1,:],threads[2,:],"r",label="julia Threads.@threads")
PyPlot.semilogx(spawn[1,:],spawn[2,:],"b",label="julia Threads.@spawn")
PyPlot.legend()
PyPlot.grid()
PyPlot.xlabel("Array Size")
PyPlot.ylabel("GFlops/s")
PyPlot.title("Julia vs GCC Thread Performance: A[i]=B[i]+C[i]*D[i]\n $(CPU)")
PyPlot.savefig("gcc-vs-threads-vs-spawn.pdf")
PyPlot.savefig("gcc-vs-threads-vs-spawn.png")
