# ERA5 model level 136 (~30 m) DATM forcing

Scripts used to build ELM DATM forcing from ERA5 model level 136 instead of 2 m/10 m fields.

1. `era_dwn_l136.py`: download t, u, v, q at model level 136 (6-hourly, 0.25 deg) from MARS via cdsapi, one GRIB file per year.
2. `era_grb2nc.sh`: split each yearly GRIB by variable and convert with `grib_to_netcdf` into `data_raw/{tbot,q,wind}/YYYY/`. Edit `SRC`/`DST` at the top for your paths.
3. `era2elm`: convert to monthly ELM forcing files, e.g.

   ls data_raw/tbot/2000/*.nc | era2elm --tpd_out=4 -c elmforc.ERA5.L136.0.25d -o drc_out

So far only temperature (t) for 2000 has been processed and checked.

## Specific humidity (q) in ELM

Level 136 q for 2000 is in `qbot_30m/` (elmforc.ERA5.L136.0.25d.q.2000-MM.nc).
DATM reads q directly as specific humidity through the stream mapping `q shum`,
so no dew point is needed and no Fortran changes are required.

`elm_q_shum_test.sh` sets up a 5-day ELM test (IERA56HRELM, r05_r05, January 2000)
on Perlmutter. It now calls `l136_streams.sh` to switch all four streams (q, t, wind,
pressure) to L136; see the next section. Shared E3SM files are not modified.

Test result of the earlier q-only version: the run completed, the DATM log shows it opening the L136 q files,
and ELM QBOT ranges from about 9e-6 to 0.021 kg/kg (mean 0.0038).
## All four fields from L136 (q, t, wind, pressure)

`l136_streams.sh` points the ERA56HR DATM streams at the L136 files:
`q shum` (qbot_30m), `t tbot` (tbot_30m), `w wind` (wind_30m), and `p pbot` (pbot_30m).
It writes the case's own `user_datm.streams.txt.ERA56HR.{d2m,t2m,w10,sp}` files;
shared E3SM files are not modified.

### Where and when to run `l136_streams.sh`

Run it from inside the case directory (the one with `env_case.xml`) of a case that
uses ERA56HR forcing, e.g. compset `IERA56HRELM`, at this point in the setup:

    create_newcase ...                    # make the case
    cd $CASE
    ./case.setup
    ./xmlchange DATM_CLMNCEP_YR_START=2000,DATM_CLMNCEP_YR_END=2000,DATM_CLMNCEP_YR_ALIGN=2000
    /path/to/era5/l136_streams.sh 2000    # after case.setup and the year settings
    ./case.build                          # before the build
    ./case.submit

The year settings must come first because the default streams list one file per month
of the forcing years, and the script swaps those file names for the L136 ones. The year
given to the script must match `DATM_CLMNCEP_YR_START/END`. The script stops without
changing anything if any of the 48 L136 files for that year is missing, and it ends by
printing each stream's variable mapping, directory, and number of L136 files.
It can be rerun safely. `elm_q_shum_test.sh` runs this whole sequence and is the
reference example of how to use all four L136 variables.

Test: IERA56HRELM, r05_r05, 1 to 5 January 2000, instantaneous 6 hourly output.

Input versus ELM output (`cmp_all.py`):

| Field | Median relative difference | Max relative difference |
| --- | --- | --- |
| TBOT vs t | 0 | 1.2e-7 |
| PBOT vs p | 0 | 1.2e-7 |
| WIND vs w | 0 | 1.4e-7 |
| QBOT vs q | 0 | 0.41 (saturation capping) |

The history file is stamped at the end of each 30 minute step, while the forcing
is computed at its start, so output at time t matches the input interpolated to t - 30 min.

DATM caps shum at saturation computed from tbot. Fraction of 6 hourly land time
steps capped (`cap_map.py`):

| Latitude | q only from L136 | All four from L136 |
| --- | --- | --- |
| 60N to 90N | 56% | 28% |
| 30N to 60N | 22% | 7.2% |
| 0 to 30N | 1.4% | 0.2% |
| 30S to 0 | 0.8% | 0.2% |
| 60S to 30S | 0.4% | 0.2% |
| 90S to 60S | 12.5% | 7.6% |
| All land | 19.6% | 9.1% |

Taking temperature from the same level as q removes most of the capping. The rest
is mostly over the coldest land, likely because DATM uses ice saturation below 0 C.
