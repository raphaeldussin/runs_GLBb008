#!/bin/bash -l
#
#SBATCH --mail-user=Raphael.Dussin@noaa.gov
#SBATCH --mail-type=END,FAIL
# -- Request that this job run on orion
#SBATCH --partition=orion
#
# -- Request 2119 cores
#SBATCH --ntasks=1
#
# -- Specify a maximum wallclock of 4 hours
#SBATCH --time=8:00:00
#
# -- Specify under which account a job should run
#SBATCH --account=marine-cpu
#
# -- Set the name of the job, or Slurm will default to the name of the script
#SBATCH --job-name=recombine
#
# -- Tell the batch system to set the working directory to the current working directory
#SBATCH --chdir=.

ulimit -s unlimited

for year in $( seq 2025 2025 ) ; do

for file in $( ls ${year}*.nc.0000 ) ; do
    f=$( echo $file | sed -e "s;\.0000;;" )
    echo running ~/tools/FRE-NCtools/bin/mppnccombine $f
    ~/tools/FRE-NCtools/bin/mppnccombine -n4 $f
done

done
