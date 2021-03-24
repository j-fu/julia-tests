### Possibly adjust these
CC=gcc	
FAST=-Ofast
OMP=-fopenmp

#################################
.SUFFIXES: .c

.c:
	$(CC)  $(OMP) $(FAST) -o $@  $< -lm

all: gcc-vs-threads-vs-spawn.pdf
#shared-vs-normal-arrays.pdf 
clean:
	-rm *.dat *.pdf cvtriad


#######################################
# Compile C code
cvtriad: cvtriad.c	

#######################################
# Create data files
cvtriad-omp4.dat: cvtriad
	OMP_NUM_THREADS=4 cvtriad >  $@

jlvtriad-scalar.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar  >  $@

jlvtriad-scalar-avx.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar-avx  >  $@

jlvtriad-threads-4.dat: jlvtriad.jl
	JULIA_NUM_THREADS=4 julia --project jlvtriad.jl --multithread-threads  >  $@

jlvtriad-spawn-4.dat: jlvtriad.jl
	JULIA_NUM_THREADS=4 julia --project jlvtriad.jl --multithread-spawn  >  $@

jlvtriad-scalar-shared.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar-shared  >  $@

jlvtriad-scalar-shared-avx.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar-shared-avx  >  $@

jlvtriad-multiprocess.dat: jlvtriad.jl
	julia -p 4 --project jlvtriad.jl --multiprocess_spawn  >  $@

#######################################
# Create pdfs
shared-vs-normal-arrays.pdf: jlvtriad-scalar.dat jlvtriad-scalar-shared.dat shared-vs-normal-arrays.jl jlvtriad-scalar-avx.dat jlvtriad-scalar-shared-avx.dat 
	julia --project shared-vs-normal-arrays.jl

gcc-vs-threads-vs-spawn.pdf: jlvtriad-scalar.dat cvtriad-omp4.dat jlvtriad-threads-4.dat  jlvtriad-spawn-4.dat gcc-vs-threads-vs-spawn.jl
	julia --project gcc-vs-threads-vs-spawn.jl

