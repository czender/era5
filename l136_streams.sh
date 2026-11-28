#!/bin/bash
# Purpose: Point the ERA56HR DATM streams for humidity, temperature, wind, and pressure
#          at ERA5 model level 136 (~30 m) files in the *_30m directories
# Only the case's own user_datm.streams.txt.ERA56HR.* files are written; shared E3SM files are not touched
#
# Where and when to run:
#   Run from inside an E3SM case directory (the directory that contains env_case.xml),
#   for a case that uses the ERA56HR DATM forcing (e.g. compset IERA56HRELM).
#   Run it AFTER ./case.setup and after DATM_CLMNCEP_YR_START/END are set with xmlchange
#   (the default stream files list one file per month of those years), and BEFORE ./case.build.
#   It is safe to run again; each run starts from the default stream in CaseDocs.
#   elm_q_shum_test.sh shows the full sequence.
#
# Usage: /path/to/era5/l136_streams.sh [year]       (year defaults to 2000)
# Example: cd ${SCRATCH}/cases/era5_l136_test && ~/era5/l136_streams.sh 2000
set -e
YR=${1:-2000}
D=/global/cfs/cdirs/e3sm/inputdata/atm/datm7/atm_forcing.datm7.ERA.6HRLY.0.25d.v5.c180614
[ -f env_case.xml ] || { echo "ERROR: run this inside a case directory"; exit 1; }

# One line per DATM stream to change. Each line has nine words: the stream name and then
# eight fields that say what to replace (old_*) and what to replace it with (new_*):
#   stream        Suffix of the stream file datm.streams.txt.ERA56HR.<stream>
#   old_var       Variable name inside the default (2 m / 10 m / surface) forcing files
#   new_var       Variable name inside the L136 forcing files
#   old_datm      DATM field the default variable is read into (tdew = dew point, etc.)
#   new_datm      DATM field the L136 variable is read into (shum = specific humidity, etc.)
#   old_drc       Directory, under ${D}, that holds the default files
#   new_drc       Directory, under ${D}, that holds the L136 files
#   old_file_tag  File tag of the default files
#   new_file_tag  File tag of the L136 files
# A file tag is the part of a forcing file name that names the variable, between the
# resolution and the date: elmforc.ERA5.c2018.0.25d.<file_tag>.YYYY-MM.nc for the default
# files and elmforc.ERA5.L136.0.25d.<file_tag>.YYYY-MM.nc for the L136 files.
# Example: the d2m line changes the mapping "d2m tdew" to "q shum", the directory
# tdew to qbot_30m, and the files elmforc.ERA5.c2018.0.25d.d2m.YYYY-MM.nc to
# elmforc.ERA5.L136.0.25d.q.YYYY-MM.nc
#
# stream old_var new_var old_datm new_datm old_drc new_drc old_file_tag new_file_tag
swaps="d2m d2m q tdew shum tdew qbot_30m d2m q
t2m t2m t tbot tbot tbot tbot_30m t2m t
w10 w10 w wind wind wind wind_30m w10 w
sp sp p pbot pbot pbot pbot_30m sp p"

# Make sure every input file exists before changing anything
missing=0
while read stream old_var new_var old_datm new_datm old_drc new_drc old_file_tag new_file_tag; do
    for mm in 01 02 03 04 05 06 07 08 09 10 11 12; do
        f=${D}/${new_drc}/elmforc.ERA5.L136.0.25d.${new_file_tag}.${YR}-${mm}.nc
        [ -s ${f} ] || { echo "ERROR: missing ${f}"; missing=1; }
    done
done <<< "${swaps}"
[ ${missing} -eq 0 ] || exit 1

./preview_namelists > /dev/null
while read stream old_var new_var old_datm new_datm old_drc new_drc old_file_tag new_file_tag; do
    S=datm.streams.txt.ERA56HR.${stream}
    [ -f CaseDocs/${S} ] || { echo "ERROR: CaseDocs/${S} not found"; exit 1; }
    cp CaseDocs/${S} user_${S}
    chmod u+w user_${S}
    # Each sed edits only the lines between <fieldInfo> and </fieldInfo>;
    # <domainInfo> (grid) is left unchanged
    # (1) Variable mapping: "old_var old_datm" becomes "new_var new_datm" (spacing kept via \1)
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s/\b${old_var}\([[:space:]]\+\)${old_datm}\b/${new_var}\1${new_datm}/" user_${S}
    # (2) Directory: the trailing /old_drc in <filePath> becomes /new_drc
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s#/${old_drc}[[:space:]]*\$#/${new_drc}#" user_${S}
    # (3) File names: all 12 monthly files of ${YR} switch from the default to the L136 file tag
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s/elmforc\.ERA5\.c2018\.0\.25d\.${old_file_tag}\.${YR}-/elmforc.ERA5.L136.0.25d.${new_file_tag}.${YR}-/" user_${S}
done <<< "${swaps}"

./preview_namelists > /dev/null
echo "Check: each stream should show the L136 variable, the _30m directory, and 12 L136 files"
for stream in d2m t2m w10 sp; do
    S=CaseDocs/datm.streams.txt.ERA56HR.${stream}
    fld=$(sed -n '/<fieldInfo>/,/<\/fieldInfo>/p' ${S})
    map=$(echo "${fld}" | sed -n '/<variableNames>/,/<\/variableNames>/p' | grep -v variableNames | xargs)
    drc=$(echo "${fld}" | sed -n '/<filePath>/,/<\/filePath>/p' | grep -v filePath | xargs)
    printf "  %-4s  map: %-10s  dir: %-10s  L136 files: %s\n" ${stream} "${map}" "$(basename ${drc})" "$(echo "${fld}" | grep -c 'L136')"
done
