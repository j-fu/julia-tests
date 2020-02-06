# Julia tests

## Parallelization test
See subdirectory `parallel` .

### Rationale 
Iterative methods for PDEs use vector operations: basic vector algebra, scalar products, sparse matrix - vector multiplication.
For large problems, these are characterized by a high ratio of memory access vs floating point operation. Here we use the
"Schönauer Vector Triad" in order to compare performance for various implementations, and compare Julia to C:
````
for i=1:N
   d[i]=a[i]+b[i]*c[i]
end
````

The use of this benchmark has been inspired by the  [benchmarking site of Georg Hager](https://blogs.fau.de/hager/archives/tag/benchmarking)

This benchmark of course reveals the various memory access issues of modern processors. In addition it can reveal implementation issues for parallel methods.
