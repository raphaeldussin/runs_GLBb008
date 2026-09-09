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
#mkmf_tag=c87e743

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
#pushd src/mkmf ; git checkout $mkmf_tag ; popd


# Option 1 (not working): included Makefile

#cd ice_ocean_SIS2

#module purge
#module load oneapi/2026.0.0
#module load cray-mpich/9.2.0
#module load hdf5/1.14.6 netcdf-c/4.10.0 netcdf-fortran/4.6.2 netcdf-cxx4/4.3.1

#CC=cc FC=ftn CXX=CC make

#exit 0


# Option 2: manual build
mkdir build
cat > build/env << EOFA
module purge
module load oneapi/2026.0.0
module load cray-mpich/9.2.0
module load hdf5/1.14.6 netcdf-c/4.10.0 netcdf-fortran/4.6.2 netcdf-cxx4/4.3.1
EOFA

cat > src/mkmf/templates/ncrc7-intel-oneapi.mk << 'EOFM'
# Template for the Intel Compilers on a Cray System
#
# Typical use with mkmf
# mkmf -t ncrc-cray.mk -c"-Duse_libMPI -Duse_netCDF" path_names /usr/local/include

############
# Commands Macros
############
FC = mpifort
CC = mpicc
LD = mpifort

#######################
# Build target macros
#
# Macros that modify compiler flags used in the build.  Target
# macrose are usually set on the call to make:
#
#    make REPRO=on NETCDF=3
#
# Most target macros are activated when their value is non-blank.
# Some have a single value that is checked.  Others will use the
# value of the macro in the compile command.

DEBUG =              # If non-blank, perform a debug build (Cannot be
                     # mixed with REPRO or TEST)

REPRO =              # If non-blank, erform a build that guarentees
                     # reprodicuibilty from run to run.  Cannot be used
                     # with DEBUG or TEST

TEST  =              # If non-blank, use the compiler options defined in
                     # the FFLAGS_TEST and CFLAGS_TEST macros.  Cannot be
                     # use with REPRO or DEBUG

VERBOSE =            # If non-blank, add additional verbosity compiler
                     # options

USE_LTO =            # Enable link-time optimization

OPENMP =             # If non-blank, compile with openmp enabled

NO_OVERRIDE_LIMITS = # If non-blank, do not use the -qoverride-limits
                     # compiler option.  Default behavior is to compile
                     # with -qoverride-limits.

NETCDF =             # If value is '3' and CPPDEFS contains
                     # '-Duse_netCDF', then the additional cpp macro
                     # '-Duse_LARGEFILE' is added to the CPPDEFS macro.

                     # A list of -I Include directories to be added to the
                     # the compile command.
INCLUDES := $(shell pkg-config --cflags yaml-0.1)

                     # The Intel Instruction Set Archetecture (ISA) compile
                     # option to use.
ISA =

COVERAGE =           # Add the code coverage compile options.

USE_R4 =             # If non-blank, use R4 for reals

# Need to use at least GNU Make version 3.81
need := 3.81
ok := $(filter $(need),$(firstword $(sort $(MAKE_VERSION) $(need))))
ifneq ($(need),$(ok))
$(error Need at least make version $(need).  Load module gmake/3.81)
endif

# REPRO, DEBUG and TEST need to be mutually exclusive of each other.
# Make sure the user hasn't supplied two at the same time
ifdef REPRO
ifneq ($(DEBUG),)
$(error Options REPRO and DEBUG cannot be used together)
else ifneq ($(TEST),)
$(error Options REPRO and TEST cannot be used together)
endif
else ifdef DEBUG
ifneq ($(TEST),)
$(error Options DEBUG and TEST cannot be used together)
endif
endif

ifdef USE_R4
REAL_PRECISION := -real-size 32
CPPDEFS += -DOVERLOAD_R4
else
REAL_PRECISION := -real-size 64
endif

# Required Preprocessor Macros:
CPPDEFS += -Duse_netCDF

# Additional Preprocessor Macros needed due to  Autotools and CMake
CPPDEFS += -DHAVE_SCHED_GETAFFINITY -DHAVE_GETTID

# Macro for Fortran preprocessor
FPPFLAGS := -fpp -Wp,-w $(INCLUDES)
# Fortran Compiler flags for the NetCDF library
FPPFLAGS += $(shell nf-config --fflags)

# Base set of Fortran compiler flags
FFLAGS := -g -fno-alias -auto -safe-cray-ptr -ftz -assume byterecl -i4 $(REAL_PRECISION) -nowarn -traceback

# Set the ISA (vectorization) as user defined or based on the target
ifdef ISA
ISA_OPT = $(ISA)
ISA_REPRO = $(ISA)
ISA_DEBUG = $(ISA)
else
ISA_OPT = -march=core-avx-i
ISA_REPRO = -march=core-avx-i
ISA_DEBUG = -march=core-avx-i
endif

# Flags based on perforance target (production (OPT), reproduction (REPRO), or debug (DEBUG)
FFLAGS_OPT = -O3 -debug minimal -fp-model source $(ISA_OPT)
FFLAGS_REPRO = -O2 -debug minimal -fp-model source $(ISA_REPRO)
FFLAGS_DEBUG = -O0 -check -check noarg_temp_created -check nopointer -check nouninit -warn -warn noerrors -fpe0 -ftrapuv $(ISA_DEBUG)

# Flags to add additional build options
FFLAGS_LTO = -flto
FFLAGS_OPENMP = -qopenmp
FFLAGS_OVERRIDE_LIMITS = -qoverride-limits
FFLAGS_VERBOSE = -v -V -what -warn all -qopt-report-phase=vec -qopt-report=2
FFLAGS_COVERAGE = -prof-gen=srcpos

# Macro for C preprocessor
CPPFLAGS := -D__IFC $(INCLUDES)
# C Compiler flags for the NetCDF library
CPPFLAGS += $(shell nc-config --cflags)

# Base set of C compiler flags
CFLAGS := -sox -traceback

# Flags based on perforance target (production (OPT), reproduction (REPRO), or debug (DEBUG)
CFLAGS_OPT = -O2 -debug minimal $(ISA_OPT)
CFLAGS_REPRO = -O2 -debug minimal $(ISA_REPRO)
CFLAGS_DEBUG = -O0 -g $(ISA_DEBUG)

# Flags to add additional build options
CFLAGS_LTO = -flto
CFLAGS_OPENMP = -qopenmp
CFLAGS_VERBOSE = -w3 -qopt-report-phase=vec -qopt-report=2
CFLAGS_COVERAGE = -prof-gen=srcpos

# Optional Testing compile flags.  Mutually exclusive from DEBUG, REPRO, and OPT
# *_TEST will match the production if no new option(s) is(are) to be tested.
FFLAGS_TEST := $(FFLAGS_OPT)
CFLAGS_TEST := $(CFLAGS_OPT)

# Linking flags
LDFLAGS :=
LDFLAGS_OPENMP := -qopenmp
LDFLAGS_VERBOSE := -Wl,-V,--verbose,-cref,-M
LDFLAGS_COVERAGE = -prof-gen=srcpos

# List of -L library directories to be added to the compile and linking commands
LIBS := $(shell pkg-config --libs yaml-0.1)
LIBS += -L$(shell nc-config --libdir)
LIBS += $(shell nf-config --flibs | sed -e "s/-lnetcdf //g")

# Get compile flags based on target macros.
ifdef REPRO
CFLAGS += $(CFLAGS_REPRO)
FFLAGS += $(FFLAGS_REPRO)
else ifdef DEBUG
CFLAGS += $(CFLAGS_DEBUG)
FFLAGS += $(FFLAGS_DEBUG)
else ifdef TEST
CFLAGS += $(CFLAGS_TEST)
FFLAGS += $(FFLAGS_TEST)
else
CFLAGS += $(CFLAGS_OPT)
FFLAGS += $(FFLAGS_OPT)
endif

ifdef USE_LTO
CFLAGS += $(CFLAGS_LTO)
FFLAGS += $(FFLAGS_LTO)
LDFLAGS += $(FFLAGS)
endif

ifdef OPENMP
CFLAGS += $(CFLAGS_OPENMP)
FFLAGS += $(FFLAGS_OPENMP)
LDFLAGS += $(LDFLAGS_OPENMP)
endif

ifdef NO_OVERRIDE_LIMITS
FFLAGS += $(FFLAGS_OVERRIDE_LIMITS)
endif

ifdef VERBOSE
CFLAGS += $(CFLAGS_VERBOSE)
FFLAGS += $(FFLAGS_VERBOSE)
LDFLAGS += $(LDFLAGS_VERBOSE)
endif

ifeq ($(NETCDF),3)
  # add the use_LARGEFILE cppdef
  CPPDEFS += -Duse_LARGEFILE
endif

ifdef COVERAGE
ifdef BUILDROOT
PROF_DIR=-prof-dir=$(BUILDROOT)
endif
CFLAGS += $(CFLAGS_COVERAGE) $(PROF_DIR)
FFLAGS += $(FFLAGS_COVERAGE) $(PROF_DIR)
LDFLAGS += $(LDFLAGS_COVERAGE) $(PROF_DIR)
endif

LDFLAGS += $(LIBS)

#---------------------------------------------------------------------------
# you should never need to change any lines below.

# see the MIPSPro F90 manual for more details on some of the file extensions
# discussed here.
# this makefile template recognizes fortran sourcefiles with extensions
# .f, .f90, .F, .F90. Given a sourcefile <file>.<ext>, where <ext> is one of
# the above, this provides a number of default actions:

# make <file>.opt       create an optimization report
# make <file>.o         create an object file
# make <file>.s         create an assembly listing
# make <file>.x         create an executable file, assuming standalone
#                       source
# make <file>.i         create a preprocessed file (for .F)
# make <file>.i90       create a preprocessed file (for .F90)

# The macro TMPFILES is provided to slate files like the above for removal.

RM = rm -f
TMPFILES = .*.m *.B *.L *.i *.i90 *.l *.s *.mod *.opt

.SUFFIXES: .F .F90 .H .L .T .f .f90 .h .i .i90 .l .o .s .opt .x

.f.L:
	$(FC) $(FFLAGS) -c -listing $*.f
.f.opt:
	$(FC) $(FFLAGS) -c -opt_report_level max -opt_report_phase all -opt_report_file $*.opt $*.f
.f.l:
	$(FC) $(FFLAGS) -c $(LIST) $*.f
.f.T:
	$(FC) $(FFLAGS) -c -cif $*.f
.f.o:
	$(FC) $(FFLAGS) -c $*.f
.f.s:
	$(FC) $(FFLAGS) -S $*.f
.f.x:
	$(FC) $(FFLAGS) -o $*.x $*.f *.o $(LDFLAGS)
.f90.L:
	$(FC) $(FFLAGS) -c -listing $*.f90
.f90.opt:
	$(FC) $(FFLAGS) -c -opt_report_level max -opt_report_phase all -opt_report_file $*.opt $*.f90
.f90.l:
	$(FC) $(FFLAGS) -c $(LIST) $*.f90
.f90.T:
	$(FC) $(FFLAGS) -c -cif $*.f90
.f90.o:
	$(FC) $(FFLAGS) -c $*.f90
.f90.s:
	$(FC) $(FFLAGS) -c -S $*.f90
.f90.x:
	$(FC) $(FFLAGS) -o $*.x $*.f90 *.o $(LDFLAGS)
.F.L:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -listing $*.F
.F.opt:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -opt_report_level max -opt_report_phase all -opt_report_file $*.opt $*.F
.F.l:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c $(LIST) $*.F
.F.T:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -cif $*.F
.F.f:
	$(FC) $(CPPDEFS) $(FPPFLAGS) -EP $*.F > $*.f
.F.i:
	$(FC) $(CPPDEFS) $(FPPFLAGS) -P $*.F
.F.o:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c $*.F
.F.s:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -S $*.F
.F.x:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -o $*.x $*.F *.o $(LDFLAGS)
.F90.L:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -listing $*.F90
.F90.opt:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -opt_report_level max -opt_report_phase all -opt_report_file $*.opt $*.F90
.F90.l:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c $(LIST) $*.F90
.F90.T:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -cif $*.F90
.F90.f90:
	$(FC) $(CPPDEFS) $(FPPFLAGS) -EP $*.F90 > $*.f90
.F90.i90:
	$(FC) $(CPPDEFS) $(FPPFLAGS) -P $*.F90
.F90.o:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c $*.F90
.F90.s:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -c -S $*.F90
.F90.x:
	$(FC) $(CPPDEFS) $(FPPFLAGS) $(FFLAGS) -o $*.x $*.F90 *.o $(LDFLAGS)
EOFM

# Compile FMS
template="ncrc7-intel-oneapi.mk"

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

