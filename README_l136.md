# ERA5 model level 136 (~30 m) DATM forcing

Scripts used to build ELM DATM forcing from ERA5 model level 136 instead of 2 m/10 m fields.

1. `era_dwn_l136.py`: download t, u, v, q at model level 136 (6-hourly, 0.25 deg) from MARS via cdsapi, one GRIB file per year.
2. `era_grb2nc.sh`: split each yearly GRIB by variable and convert with `grib_to_netcdf` into `data_raw/{tbot,q,wind}/YYYY/`. Edit `SRC`/`DST` at the top for your paths.
3. `era2elm`: convert to monthly ELM forcing files, e.g.

   ls data_raw/tbot/2000/*.nc | era2elm --tpd_out=4 -c elmforc.ERA5.L136.0.25d -o drc_out

So far only temperature (t) for 2000 has been processed and checked.

## Specific humidity (q) in ELM

Level 136 q for 2000 is in `qbot_new/` (elmforc.ERA5.L136.0.25d.q.2000-MM.nc).
DATM reads q directly as specific humidity through the stream mapping `q shum`,
so no dew point is needed and no Fortran changes are required.

`elm_q_shum_test.sh` sets up a 5-day ELM test (IERA56HRELM, r05_r05, January 2000)
on Perlmutter. It copies the default ERA56HR dew point stream into the case's own
`user_datm.streams.txt.ERA56HR.d2m` and changes `d2m tdew` to `q shum` and the
directory to `qbot_new`. Shared E3SM files are not modified.

Test result: the run completed, the DATM log shows it opening the L136 q files,
and ELM QBOT ranges from about 9e-6 to 0.021 kg/kg (mean 0.0038).