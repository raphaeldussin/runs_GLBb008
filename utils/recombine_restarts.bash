#!/bin/bash -l
#
#SBATCH --mail-user=Raphael.Dussin@noaa.gov
#SBATCH --mail-type=END,FAIL
# -- Request that this job run on orion
#SBATCH --partition=orion
#
#SBATCH --ntasks=1
#
# -- Specify a maximum wallclock of 8 hours
#SBATCH --time=8:00:00
#
# -- Specify under which account a job should run
#SBATCH --account=marine-cpu
#
# -- Set the name of the job, or Slurm will default to the name of the script
#SBATCH --job-name=recombine_restart
#
# -- Tell the batch system to set the working directory to the current working directory
#SBATCH --chdir=.

ulimit -s unlimited

# this should run inside restarts_raw

PATH_NCTOOLS=~/tools/FRE-NCtools/bin
PATH_COMBINED_RESTARTS=$(pwd)/../restarts_by_year

mkdir -p $PATH_COMBINED_RESTARTS

for restart in $( ls | grep restarts ) ; do
  restart_year=$( cat $restart/coupler.res | grep "Current model time" | awk '{ print $1 }' )
  restart_month=$( cat $restart/coupler.res | grep "Current model time" | awk '{ print $2 }' )
  if [ $restart_month == 1 ] ; then
    echo $restart_year $restart_month
    pushd $restart
    for file in $( ls ${year}*.nc.0000 ) ; do
      f=$( echo $file | sed -e "s;\.0000;;" )
      echo running $PATH_NCTOOLS/mppnccombine $f
      $PATH_NCTOOLS/mppnccombine -n4 $f
    done
    echo building tar file restart_${restart_year}.tar
    tar -cvf restart_${restart_year}.tar *.nc
    echo moving file to $PATH_COMBINED_RESTARTS
    mv restart_${restart_year}.tar $PATH_COMBINED_RESTARTS
  popd

  fi
done
