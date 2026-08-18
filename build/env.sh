#!/bin/bash
# USAGE: source env.sh

# -- Manually set inputs --
path_to_ufs_weather_model="/work/noaa/marine/rdussin/RTOFS_GLO/sorc/ufs_model.fd/"
RT_COMPILER="intel"

source ${path_to_ufs_weather_model}/tests/detect_machine.sh
#echo "Machine: ${MACHINE_ID}"
# --

# Check for ufs-weather-model (src) https://github.com/ufs-community/ufs-weather-model
# We will use a few scripts to ease our life!
if [ ! -d ${path_to_ufs_weather_model} ]; then
  echo "Need a clone of ufs-weather-model, it was not found. Fix it and try again!"
fi

source ${path_to_ufs_weather_model}/tests/detect_machine.sh
# Display the machine using the format detect_machine.sh used:
echo "Machine: ${MACHINE_ID}"
#

echo "Purge all modules"
source ${path_to_ufs_weather_model}/tests/module-setup.sh

# Following is based on tests/compile.sh
echo "Load needed modules"
module use "${path_to_ufs_weather_model}/modulefiles"
modulefile="ufs_${MACHINE_ID}.${RT_COMPILER}"
module load "${modulefile}"
module list
