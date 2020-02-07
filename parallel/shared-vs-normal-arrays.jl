using PyPlot
using DelimitedFiles

CPU=Sys.cpu_info()[1].model

scalar=readdlm("jlvtriad-scalar.dat",comments=true)'
scalar_shared=readdlm("jlvtriad-scalar-shared.dat",comments=true)'
scalar_avx=readdlm("jlvtriad-scalar-avx.dat",comments=true)'
scalar_shared_avx=readdlm("jlvtriad-scalar-shared-avx.dat",comments=true)'

PyPlot.clf()
PyPlot.semilogx(scalar[1,:],scalar[2,:],"g--",label="Array")
PyPlot.semilogx(scalar_shared[1,:],scalar_shared[2,:],"r--",label="SharedArray")
PyPlot.semilogx(scalar_avx[1,:],scalar_avx[2,:],"g",label="Array + avx")
PyPlot.semilogx(scalar_shared_avx[1,:],scalar_shared_avx[2,:],"r",label="SharedArray+avx")
PyPlot.legend()
PyPlot.grid()
PyPlot.xlabel("Array Size")
PyPlot.ylabel("GFlops/s")
PyPlot.title("SharedArray vs Array (scalar): A[i]=B[i]+C[i]*D[i]\n $(CPU)")
PyPlot.savefig("shared-vs-normal-arrays.pdf")
PyPlot.savefig("shared-vs-normal-arrays.png")
