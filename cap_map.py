import sys, glob, warnings, numpy as np, xarray as xr
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
warnings.filterwarnings('ignore', category=FutureWarning)
run, qf = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else 'qbot_capping_jan2000.png'
def opn(f):
    try:
        return xr.open_dataset(f, decode_times=xr.coders.CFDatetimeCoder(use_cftime=True))
    except AttributeError:
        return xr.open_dataset(f, use_cftime=True)
h1 = opn(sorted(glob.glob(run + '/*.elm.h1.2000-01-01-00000.nc'))[0])
qd = opn(qf)
t0 = qd['time'].values[0]
q  = qd['q'].isel(time=slice(0, 24))
q  = q.assign_coords(lon=(((q.lon + 180) % 360) - 180)).sortby('lon').sortby('lat')
q  = q.sel(lat=h1.lat, lon=h1.lon, method='nearest', tolerance=1e-3).values
def q_at(hrs):
    k = int(np.floor(hrs / 6.0)); w = (hrs - 6.0 * k) / 6.0
    return q[k] if w == 0 else (1 - w) * q[k] + w * q[k + 1]
ncap = None; nland = None; dsum = None
for it in range(1, h1.sizes['time']):                     # skip step 0; output at t holds forcing for t - 30 min
    t = h1.time.values[it]
    hrs = (t - t0).total_seconds() / 3600.0 - 0.5
    Q = h1['QBOT'].isel(time=it).values
    qi = q_at(hrs)
    land = np.isfinite(Q) & (Q < 1e30)
    cap = land & (Q < 0.99 * qi)                          # QBOT more than 1% below input q: capped at saturation
    d = np.where(cap, (qi - Q) / qi, 0.0)
    ncap = cap.astype(int) if ncap is None else ncap + cap
    nland = land.astype(int) if nland is None else nland + land
    dsum = d if dsum is None else dsum + d
frac = np.where(nland > 0, ncap / np.maximum(nland, 1), np.nan)
mean_cut = np.where(ncap > 0, dsum / np.maximum(ncap, 1), np.nan)
lat = h1.lat.values; lon = h1.lon.values
L = nland > 0
print(f"land points: {L.sum()}   ever capped: {(ncap > 0).sum()}   mean fraction of times capped: {np.nanmean(frac[L]):.3f}")
for lo, hi in [(-90, -60), (-60, -30), (-30, 0), (0, 30), (30, 60), (60, 90)]:
    m = L & (lat[:, None] >= lo) & (lat[:, None] < hi)
    if m.sum():
        print(f"  lat {lo:4d} to {hi:3d}: land pts {m.sum():6d}   frac of times capped {np.nanmean(frac[m]):.3f}   "
              f"median cut when capped {np.nanmedian(mean_cut[m & (ncap > 0)]) if (m & (ncap > 0)).any() else float('nan'):.3f}")
fig, ax = plt.subplots(2, 1, figsize=(11, 9), constrained_layout=True)
p0 = ax[0].pcolormesh(lon, lat, frac, cmap='viridis', vmin=0, vmax=1, shading='auto')
ax[0].set_title('Fraction of 6 hourly times where DATM capped L136 q at saturation (1 to 5 Jan 2000)')
fig.colorbar(p0, ax=ax[0], label='fraction of times capped')
p1 = ax[1].pcolormesh(lon, lat, 100 * mean_cut, cmap='magma_r', vmin=0, vmax=30, shading='auto')
ax[1].set_title('Mean reduction of q when capped (%)')
fig.colorbar(p1, ax=ax[1], label='(q - QBOT) / q, %')
for a in ax:
    a.set_xlabel('longitude'); a.set_ylabel('latitude'); a.set_aspect('equal')
fig.savefig(out, dpi=130)
print("saved", out)
