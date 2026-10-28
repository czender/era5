#!/bin/bash
SRC=/Volumes/SAMSUNG-ExF/DATM_data
DST=/Volumes/SAMSUNG-ExF/data_raw
TMP=/Volumes/SAMSUNG-ExF/tmp_split
LOG=$DST/conversion_log.txt
mkdir -p $TMP

for f in $SRC/DATM_L136_*.grib; do
  yr=$(basename $f .grib | sed 's/DATM_L136_//')
  # Only process files named DATM_L136_YYYY.grib
  [[ $yr =~ ^[0-9]{4}$ ]] || { echo "skip $f"; continue; }
  [ -s "$f" ] || { echo "$yr EMPTY grib" | tee -a $LOG; continue; }

  if (( (yr%4==0 && yr%100!=0) || yr%400==0 )); then exp=1464; else exp=1460; fi
  mkdir -p $DST/tbot/$yr $DST/q/$yr $DST/wind/$yr

  for pair in "t:tbot:temperature" "q:q:specific_humidity" "u/v:wind:wind"; do
    sn=${pair%%:*}; rest=${pair#*:}; dir=${rest%%:*}; name=${rest#*:}
    out=$DST/$dir/$yr/ERA5_${yr}_L136_${name}.nc
    if [ ! -s "$out" ]; then
      echo "converting $yr $dir ..."
      grib_copy -w shortName=$sn $f $TMP/tmp.grib
      grib_to_netcdf -o $out $TMP/tmp.grib
      rm -f $TMP/tmp.grib
    fi
    nt=$(ncdump -h $out | grep -m1 "time =" | tr -dc '0-9')
    [ "$nt" = "$exp" ] && s=OK || s="CHECK (got $nt, expected $exp)"
    echo "$yr $dir $s" | tee -a $LOG
  done
done
echo "ALL DONE"
