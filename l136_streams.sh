#!/bin/bash
# Purpose: Point the ERA56HR DATM streams for humidity, temperature, wind, and pressure
#          at ERA5 model level 136 (~30 m) files in the *_30m directories
# Run inside a case directory (after case.setup); writes user_datm.streams.txt.ERA56HR.* files
# Usage: ~/l136_streams.sh [year]
set -e
YR=${1:-2000}
D=/global/cfs/cdirs/e3sm/inputdata/atm/datm7/atm_forcing.datm7.ERA.6HRLY.0.25d.v5.c180614
[ -f env_case.xml ] || { echo "ERROR: run this inside a case directory"; exit 1; }

# stream old_var new_var old_datm new_datm old_dir new_dir old_file_tag new_file_tag
swaps="d2m d2m q tdew shum tdew qbot_30m d2m q
t2m t2m t tbot tbot tbot tbot_30m t2m t
w10 w10 w wind wind wind wind_30m w10 w
sp sp p pbot pbot pbot pbot_30m sp p"

# Make sure every input file exists before changing anything
missing=0
while read strm ov nv odn ndn od nd ot nt; do
    for mm in 01 02 03 04 05 06 07 08 09 10 11 12; do
        f=${D}/${nd}/elmforc.ERA5.L136.0.25d.${nt}.${YR}-${mm}.nc
        [ -s ${f} ] || { echo "ERROR: missing ${f}"; missing=1; }
    done
done <<< "${swaps}"
[ ${missing} -eq 0 ] || exit 1

./preview_namelists > /dev/null
while read strm ov nv odn ndn od nd ot nt; do
    S=datm.streams.txt.ERA56HR.${strm}
    [ -f CaseDocs/${S} ] || { echo "ERROR: CaseDocs/${S} not found"; exit 1; }
    cp CaseDocs/${S} user_${S}
    chmod u+w user_${S}
    # Only <fieldInfo> is edited; <domainInfo> (grid) is left unchanged
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s/\b${ov}\([[:space:]]\+\)${odn}\b/${nv}\1${ndn}/" user_${S}
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s#/${od}[[:space:]]*\$#/${nd}#" user_${S}
    sed -i "/<fieldInfo>/,/<\/fieldInfo>/s/elmforc\.ERA5\.c2018\.0\.25d\.${ot}\.${YR}-/elmforc.ERA5.L136.0.25d.${nt}.${YR}-/" user_${S}
done <<< "${swaps}"

./preview_namelists > /dev/null
echo "Check: each stream should show the L136 variable, the _30m directory, and 12 L136 files"
for strm in d2m t2m w10 sp; do
    S=CaseDocs/datm.streams.txt.ERA56HR.${strm}
    fld=$(sed -n '/<fieldInfo>/,/<\/fieldInfo>/p' ${S})
    map=$(echo "${fld}" | sed -n '/<variableNames>/,/<\/variableNames>/p' | grep -v variableNames | xargs)
    dir=$(echo "${fld}" | sed -n '/<filePath>/,/<\/filePath>/p' | grep -v filePath | xargs)
    printf "  %-4s  map: %-10s  dir: %-10s  L136 files: %s\n" ${strm} "${map}" "$(basename ${dir})" "$(echo "${fld}" | grep -c 'L136')"
done
