#!/bin/bash

# first checkout MOM6-examples
git clone --recursive git@github.com:NOAA-GFDL/MOM6-examples.git

cd MOM6-examples

# pick the git tags I want
atmos_null_tag=2025.02
coupler_tag=2025.02
FMS2_tag=2025.02.01
icebergs_tag=ce76de33ce
ice_param_tag=2024.02
land_null_tag=2025.02
MOM6_tag=865753ac2dd9
SIS2_tag=c287b24d5d2b6
mkmf_tag=c87e743

pushd src ; rm FMS ; ln -sf FMS2 FMS ; popd
pushd src/atmos_null ; git checkout $atmos_null_tag ; popd
pushd src/coupler ; git checkout $coupler_tag ; popd
pushd src/FMS2 ; git checkout $FMS2_tag ; popd
pushd src/icebergs ; git checkout $icebergs_tag ; popd
pushd src/ice_param ; git checkout $ice_param_tag ; popd
pushd src/land_null ; git checkout $land_null_tag ; popd
pushd src/MOM6 ; git checkout $MOM6_tag ; popd
pushd src/MOM6/pkg/CVMix-src ; git checkout c38ddb7 ; popd
pushd src/SIS2 ; git checkout $SIS2_tag ; popd
pushd src/mkmf ; git checkout $mkmf_tag ; popd


# Option 1 (not working): included Makefile

#cd ice_ocean_SIS2

#module purge
#module load PrgEnv-intel/8.6.0
#module load cray-hdf5 cray-netcdf
#MPIFC=mpiifx MPICC=mpiicx CC=icx FC=ifx make


# Option 2: manual build
mkdir build
cat > build/env << EOFA
module purge
module load PrgEnv-intel/8.6.0
module load cray-hdf5 cray-netcdf
EOFA

# Compile FMS
template="ncrc5-intel-oneapi.mk"

sed -i '/LDFLAGS/s/ *-fuse-ld=lld *//g' src/mkmf/templates/${template}

cwd=$(pwd)

if [ -d ${cwd}/build/intel/shared/repro ] ; then /bin/rm -rf ${cwd}/build/intel/shared/repro ; fi
mkdir -p ${cwd}/build/intel/shared/repro

(cd ${cwd}/build/intel/shared/repro/; rm -f path_names; \
../../../../src/mkmf/bin/list_paths -l ../../../../src/FMS2; \
../../../../src/mkmf/bin/mkmf -t ../../../../src/mkmf/templates/${template} -p libfms.a -c "-Duse_libMPI -Duse_netCDF -Duse_yaml" path_names)

(cd ${cwd}/build/intel/shared/repro/; source ${cwd}/build/env ; make NETCDF=4 REPRO=1 libfms.a -j)

# check if the libfms.a was built
if [ -f ${cwd}/build/intel/shared/repro/libfms.a ]; then
    echo " "
    echo "Done."
else
    echo "Error in building libfms.a"
    exit 1
fi

# Compile MOM6/SIS2
if [ -d ${cwd}/build/intel/ice_ocean_SIS2/repro ] ; then /bin/rm -rf ${cwd}/build/intel/ice_ocean_SIS2/repro ; fi
mkdir -p ${cwd}/build/intel/ice_ocean_SIS2/repro

(cd build/intel/ice_ocean_SIS2/repro/; rm -f path_names; \
../../../../src/mkmf/bin/list_paths -l ./ ../../../../src/MOM6/config_src/{infra/FMS2,memory/dynamic_symmetric,drivers/FMS_cap,external} ../../../../src/MOM6/src/{*,*/*}/ ../../../../src/{atmos_null,land_null,ice_param,icebergs/src,SIS2,coupler/{shared,full},FMS/include}/)

(cd build/intel/ice_ocean_SIS2/repro/; \
../../../../src/mkmf/bin/mkmf -t ../../../../src/mkmf/templates/${template} -o '-I../../shared/repro' -p MOM6 -l '-L../../shared/repro -lfms' -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_ -DUSE_FMS2_IO' path_names )

(cd build/intel/ice_ocean_SIS2/repro/; source ${cwd}/build/env ; make NETCDF=4 REPRO=1 MOM6 -j)

  # check if the MOM6-SIS2 was built
if [ -f ${cwd}/build/intel/ice_ocean_SIS2/repro/MOM6 ]; then
    echo " "
    echo "Done."
else
    echo "Error in building ocean-sis2: MOM6"
    exit 1
fi

