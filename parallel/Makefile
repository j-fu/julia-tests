.SUFFIXES: .c

CC=gcc	
FAST=-Ofast
OMP=-fopenmp

.c:
	$(CC)  $(OMP) $(FAST) -o $@  $< -lm

cvtriad: cvtriad.c	

cvtriad-omp4.dat: cvtriad
	OMP_NUM_THREADS=4 cvtriad >  $@

jlvtriad-scalar.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar  >  $@

jlvtriad-scalar-shared.dat: jlvtriad.jl
	julia --project jlvtriad.jl --scalar-shared  >  $@


shared-vs-normal-arrays.pdf: jlvtriad-scalar.dat jlvtriad-scalar-shared.dat shared-vs-normal-arrays.jl
	julia --project shared-vs-normal-arrays.jl

