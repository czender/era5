# ERA5 model level 136 (~30 m) DATM forcing

Scripts used to build ELM DATM forcing from ERA5 model level 136 instead of 2 m/10 m fields.

1. `download_l136.py`: download t, u, v, q at model level 136 (6-hourly, 0.25 deg) from MARS via cdsapi, one GRIB file per year.
2. `convert_raw.sh`: split each yearly GRIB by variable and convert with `grib_to_netcdf` into `data_raw/{tbot,q,wind}/YYYY/`. Edit `SRC`/`DST` at the top for your paths.
3. `era2elm`: convert to monthly ELM forcing files, e.g.

   ls data_raw/tbot/2000/*.nc | era2elm --tpd_out=4 -c elmforc.ERA5.L136.0.25d -o drc_out

So far only temperature (t) for 2000 has been processed and checked.
