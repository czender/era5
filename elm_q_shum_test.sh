#!/bin/bash
# Purpose: Short ELM test in which DATM reads ERA5 model level 136 specific humidity (q)
#          directly as shum, instead of computing humidity from 2 m dew point (d2m tdew)
# Only the case's own user_datm.streams file is changed; shared E3SM files are not touched
# Run on a Perlmutter login node WITHOUT E3SM-Unified loaded (it blocks create_newcase),
# after "module load python" (CIME needs Python >= 3.9)
#
# Usage: ./elm_q_shum_test.sh [case_dir]
# Example: ./elm_q_shum_test.sh ${SCRATCH}/cases/era5_q_test

set -e

# E3SM-Unified sets CIME_MODEL to a sentinel that blocks CIME; stop early with a clear message
if [ "${CIME_MODEL}" = "ENVIRONMENT_RUNNING_E3SM_UNIFIED_USE_ANOTHER_TERMINAL" ]; then
    echo "ERROR: E3SM-Unified is loaded. Log in again without it, then rerun." && exit 1
fi

E3SM_SRC=${E3SM_SRC:-${HOME}/E3SM}                     # E3SM source checkout
CASE=${1:-${SCRATCH}/cases/era5_q_test}                # Case directory
PROJECT=${PROJECT:-e3sm}                               # NERSC CPU account
D=/global/cfs/cdirs/e3sm/inputdata/atm/datm7/atm_forcing.datm7.ERA.6HRLY.0.25d.v5.c180614
QDIR=${QDIR:-qbot_new}                                 # Directory with L136 q files
YR=2000                                                # Only 2000 has been processed so far
STRM=datm.streams.txt.ERA56HR.d2m                      # Stream that normally supplies dew point

# Step 0: Make sure the q files exist before creating anything
for mm in 01 02 03 04 05 06 07 08 09 10 11 12; do
    [ -s ${D}/${QDIR}/elmforc.ERA5.L136.0.25d.q.${YR}-${mm}.nc ] || { echo "ERROR: missing ${D}/${QDIR}/elmforc.ERA5.L136.0.25d.q.${YR}-${mm}.nc"; exit 1; }
done

# Step 1: Create and set up the case (ERA5 6 hourly DATM + ELM SP, 0.5 degree land)
${E3SM_SRC}/cime/scripts/create_newcase --case ${CASE} \
    --compset IERA56HRELM --res r05_r05 --machine pm-cpu --project ${PROJECT}
cd ${CASE}
./case.setup

# Step 2: Run 5 days of January ${YR}, cycling forcing only within ${YR}
./xmlchange RUN_STARTDATE=${YR}-01-01,STOP_OPTION=ndays,STOP_N=5
./xmlchange DATM_CLMNCEP_YR_START=${YR},DATM_CLMNCEP_YR_END=${YR},DATM_CLMNCEP_YR_ALIGN=${YR}
./xmlchange JOB_WALLCLOCK_TIME=00:30:00

# Step 3: Copy the default dew point stream and point it at q
# Only <fieldInfo> is edited; <domainInfo> (grid) is left unchanged
./preview_namelists > /dev/null
cp CaseDocs/${STRM} user_${STRM}
chmod u+w user_${STRM}
sed -i '/<fieldInfo>/,/<\/fieldInfo>/s/\bd2m\([[:space:]]\+\)tdew\b/q\1shum/' user_${STRM}
sed -i "/<fieldInfo>/,/<\/fieldInfo>/s#/tdew[[:space:]]*\$#/${QDIR}#" user_${STRM}
sed -i "/<fieldInfo>/,/<\/fieldInfo>/s/elmforc\.ERA5\.c2018\.0\.25d\.d2m\.${YR}-/elmforc.ERA5.L136.0.25d.q.${YR}-/" user_${STRM}

# Step 4: ELM output for the sanity checks
#   h0: 6 hourly means; h1: 6 hourly instantaneous values (compare with q at 00/06/12/18 UTC);
#   h2: QBOT every time step (shows the linear interpolation between 6 hourly records)
cat >> user_nl_elm << EOT
hist_fincl1 = 'QBOT','TBOT','PBOT'
hist_fincl2 = 'QBOT','TBOT','PBOT'
hist_fincl3 = 'QBOT'
hist_avgflag_pertape = 'A','I','I'
hist_nhtfrq = -6,-6,1
hist_mfilt  = 20,20,240
EOT

# Step 5: Confirm DATM picked up the edited stream
./preview_namelists > /dev/null
grep -n "shum\|${QDIR}\|L136" CaseDocs/${STRM}

# Step 6: Build and submit
./case.build
./case.submit

# After the run: check that DATM opened the q files and look at QBOT
#   RUN=$(./xmlquery RUNDIR --value)
#   zgrep -i "${QDIR}" ${RUN}/atm.log.* | head -3
#   ls ${RUN}/*.elm.h[012].${YR}-01-01-00000.nc
#   h1 QBOT at 00/06/12/18 UTC should equal q (except where DATM caps q at saturation)
