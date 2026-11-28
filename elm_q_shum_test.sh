#!/bin/bash
# Purpose: Short ELM test in which DATM reads all four ERA5 model level 136 (~30 m) fields:
#          specific humidity (q -> shum), temperature (t -> tbot), wind speed (w -> wind),
#          and pressure (p -> pbot), instead of the default 2 m / 10 m / surface fields
# The streams are switched by l136_streams.sh (in this repository), which is the
# recommended way to point any ERA56HR case at the L136 variables
# Only the case's own user_datm.streams files are changed; shared E3SM files are not touched
# Run on a Perlmutter login node WITHOUT E3SM-Unified loaded (it blocks create_newcase),
# after "module load python" (CIME needs Python >= 3.9)
#
# Usage: ./elm_q_shum_test.sh [case_dir]
# Example: ./elm_q_shum_test.sh ${SCRATCH}/cases/era5_l136_test

set -e

# E3SM-Unified sets CIME_MODEL to a sentinel that blocks CIME; stop early with a clear message
if [ "${CIME_MODEL}" = "ENVIRONMENT_RUNNING_E3SM_UNIFIED_USE_ANOTHER_TERMINAL" ]; then
    echo "ERROR: E3SM-Unified is loaded. Log in again without it, then rerun." && exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # This repository (holds l136_streams.sh)
E3SM_SRC=${E3SM_SRC:-${HOME}/E3SM}                     # E3SM source checkout
CASE=${1:-${SCRATCH}/cases/era5_l136_test}             # Case directory
PROJECT=${PROJECT:-e3sm}                               # NERSC CPU account
D=/global/cfs/cdirs/e3sm/inputdata/atm/datm7/atm_forcing.datm7.ERA.6HRLY.0.25d.v5.c180614
YR=2000                                                # Only 2000 has been processed so far

# Step 0: Make sure the stream script and all L136 files exist before creating anything
[ -x ${SCRIPT_DIR}/l136_streams.sh ] || { echo "ERROR: ${SCRIPT_DIR}/l136_streams.sh not found or not executable"; exit 1; }
for pair in qbot_30m:q tbot_30m:t wind_30m:w pbot_30m:p; do
    drc=${pair%%:*}; file_tag=${pair##*:}
    for mm in 01 02 03 04 05 06 07 08 09 10 11 12; do
        f=${D}/${drc}/elmforc.ERA5.L136.0.25d.${file_tag}.${YR}-${mm}.nc
        [ -s ${f} ] || { echo "ERROR: missing ${f}"; exit 1; }
    done
done

# Step 1: Create and set up the case (ERA5 6 hourly DATM + ELM SP, 0.5 degree land)
${E3SM_SRC}/cime/scripts/create_newcase --case ${CASE} \
    --compset IERA56HRELM --res r05_r05 --machine pm-cpu --project ${PROJECT}
cd ${CASE}
./case.setup

# Step 2: Run 5 days of January ${YR}, cycling forcing only within ${YR}
# The forcing years must be set before Step 3, because the default streams list files by year
./xmlchange RUN_STARTDATE=${YR}-01-01,STOP_OPTION=ndays,STOP_N=5
./xmlchange DATM_CLMNCEP_YR_START=${YR},DATM_CLMNCEP_YR_END=${YR},DATM_CLMNCEP_YR_ALIGN=${YR}
./xmlchange JOB_WALLCLOCK_TIME=00:30:00

# Step 3: Point the humidity, temperature, wind, and pressure streams at the L136 files
# (after case.setup and the year settings, before case.build). l136_streams.sh writes
# user_datm.streams.txt.ERA56HR.{d2m,t2m,w10,sp} and prints a check of each stream
${SCRIPT_DIR}/l136_streams.sh ${YR}

# Step 4: ELM output for the sanity checks
#   h0: 6 hourly means; h1: 6 hourly instantaneous values (compare with the L136 inputs);
#   h2: QBOT every time step (shows the linear interpolation between 6 hourly records)
cat >> user_nl_elm << EOT
hist_fincl1 = 'QBOT','TBOT','PBOT','WIND'
hist_fincl2 = 'QBOT','TBOT','PBOT','WIND'
hist_fincl3 = 'QBOT'
hist_avgflag_pertape = 'A','I','I'
hist_nhtfrq = -6,-6,1
hist_mfilt  = 20,20,240
EOT

# Step 5: Build and submit
./case.build
./case.submit

# After the run: check that DATM opened the L136 files and compare inputs with ELM output
#   RUN=$(./xmlquery RUNDIR --value)
#   zgrep -i "L136" ${RUN}/atm.log.* | head -8
#   ls ${RUN}/*.elm.h[012].${YR}-01-01-00000.nc
#   python ${SCRIPT_DIR}/cmp_all.py ${RUN} ${D}     (TBOT, PBOT, WIND match; QBOT differs only where capped)
