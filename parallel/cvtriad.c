#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>

/* 

Schönauer vector triad benchmark

See https://blogs.fau.de/hager/archives/tag/benchmarking
*/

    

void vtriad(int N, int nrepeat)
{
  /* Allocate memory on heap*/
  double *a=malloc(N*sizeof(double));
  double *b=malloc(N*sizeof(double));
  double *c=malloc(N*sizeof(double));
  double *d=malloc(N*sizeof(double));
  int i,j;
  
  // Initialization loop, not timed
#pragma omp parallel for  
  for (i=0;i<N;i++)
  {
    a[i]=i;
    b[i]=N-i;
    c[i]=i;
    d[i]=-i;
  }
  
  // Timing variables
  double t0,t_scalar, t_parallel, t_dparallel;
  
  // Run parallel version
  // Outer loop is for averaging results
  // Inner loop is what matters

  t0=omp_get_wtime();
  for (j=0; j<nrepeat;j++)
#pragma omp parallel for  
      for (i=0;i<N;i++)
      {
        d[i]=a[i]+b[i]*c[i];
      }
  t_parallel=omp_get_wtime()-t0;

  
  t0=omp_get_wtime();
  for (j=0; j<nrepeat;j++)
#pragma omp parallel for schedule(dynamic,N/(omp_get_max_threads())) 
      for (i=0;i<N;i++)
      {
        d[i]=a[i]+b[i]*c[i];
      }
  t_dparallel=omp_get_wtime()-t0;
  

  // Run scalar version
  t0=omp_get_wtime();
  for (j=0; j<nrepeat;j++)
    for (i=0;i<N;i++)
    {
      d[i]=a[i]+b[i]*c[i];
    }
  t_scalar=omp_get_wtime()-t0;

  double GFlops=N*nrepeat*2.0/1.0e9;

  printf("% 10d % 10.3f % 10.3f % 10.3f\n", N, GFlops/t_scalar,GFlops/t_parallel,GFlops/t_dparallel);
  
  /* Free heap memory*/
  free(a);
  free(b);
  free(c);
  free(d);
}



int* vsizes(int N0,int ppomag,int nrun)
{
  int *vsz;
  int N;
  int irun;
  vsz=calloc(nrun,sizeof(int));
  vsz[0]=N0;
  N=N0;
  N0*=10;
  for (irun=1;irun<nrun; irun++)
  {
    N=N*pow(10.0,1.0/(double)ppomag);
    if (irun%ppomag==0)
    {
      N=N0;
      N0*=10;
    }
    vsz[irun]=N;
  }
  return vsz;
}


int main(int argc, char *argv[])
{
  int irun,N,N0,ppdec,nrun;
  int *vsz;
  double flopcount;
  
  /* Approximate number of FLOPs per measurement */
  flopcount=5.0e8;

  /* Smallest array size */
  N0=1000;
  
  /* Data points per decade (of array size)*/
  ppdec=8;
  
  /* Number of array size increases*/
  nrun=41;
  
  /* Size vector */
  vsz=vsizes(N0,ppdec,nrun);

  /* Write immediately */
  setlinebuf(stdout);
  
  /* File header */
  printf("# nthreads=%d\n",omp_get_max_threads());
  printf("#        N   S_GFlops/s  P_GFlops/s  Pd_GFlops/s\n");
  
  for (irun=0;irun<nrun;irun++)
  {
    int N=vsz[irun];
    int nrepeat=(int)(flopcount/(double)N);
    vtriad(N,nrepeat);
  }
  free(vsz);
}
