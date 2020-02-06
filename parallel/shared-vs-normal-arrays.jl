using PyPlot
using DelimitedFiles

CPU=ENV["CPU"]

scalar=readdlm("jlvtriad-scalar.dat",comments=true)'
scalar_shared=readdlm("jlvtriad-scalar-shared.dat",comments=true)'

PyPlot.clf()
PyPlot.semilogx(scalar[1,:],scalar[2,:],label="Array")
PyPlot.semilogx(scalar_shared[1,:],scalar_shared[2,:],label="SharedArray")
PyPlot.legend()
PyPlot.grid()
PyPlot.xlabel("Array Size")
PyPlot.ylabel("GFlops/s")
PyPlot.title("SharedArray vs Array (scalar): A[i]=B[i]+C[i]*D[i]\n $(CPU)")
PyPlot.savefig("shared-vs-normal-arrays.pdf")
PyPlot.savefig("shared-vs-normal-arrays.png")
