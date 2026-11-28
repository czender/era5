import sys, glob, warnings, numpy as np, xarray as xr
warnings.filterwarnings('ignore', category=FutureWarning)
run, D = sys.argv[1], sys.argv[2]
def opn(f):
    try:
        return xr.open_dataset(f, decode_times=xr.coders.CFDatetimeCoder(use_cftime=True))
    except AttributeError:
        return xr.open_dataset(f, use_cftime=True)
h1 = opn(sorted(glob.glob(run + '/*.elm.h1.2000-01-01-00000.nc'))[0])
pairs = [('TBOT', 'tbot_30m', 't'), ('PBOT', 'pbot_30m', 'p'), ('WIND', 'wind_30m', 'w'), ('QBOT', 'qbot_30m', 'q')]
for elm_var, d, v in pairs:
    if elm_var not in h1:
        print(f"{elm_var}: not in h1 output, skipped"); continue
    f = f"{D}/{d}/elmforc.ERA5.L136.0.25d.{v}.2000-01.nc"
    ds = opn(f); t0 = ds['time'].values[0]
    x = ds[v].isel(time=slice(0, 24))
    x = x.assign_coords(lon=(((x.lon + 180) % 360) - 180)).sortby('lon').sortby('lat')
    x = x.sel(lat=h1.lat, lon=h1.lon, method='nearest', tolerance=1e-3).values
    worst = 0.0; meds = []
    for it in range(1, h1.sizes['time']):
        hrs = (h1.time.values[it] - t0).total_seconds() / 3600.0 - 0.5   # output at t holds forcing for t - 30 min
        k = int(np.floor(hrs / 6.0)); w = (hrs - 6.0 * k) / 6.0
        xi = (1 - w) * x[k] + w * x[k + 1]
        E = h1[elm_var].isel(time=it).values
        m = np.isfinite(E) & (E < 1e30) & (np.abs(xi) > 1e-3 if v == 'w' else True)
        rel = np.abs(E[m] - xi[m]) / np.maximum(np.abs(xi[m]), 1e-12)
        meds.append(np.median(rel)); worst = max(worst, rel.max())
    print(f"{elm_var} vs {v}: median rel diff = {np.median(meds):.1e}   max rel diff = {worst:.1e}")
