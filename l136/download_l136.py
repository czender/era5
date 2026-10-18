#!/usr/bin/env python3
"""Download ERA5 model-level 136 fields (~30 m above surface) from MARS via cdsapi.

Fields: t (130), u (131), v (132), q (133); analysis at 00/06/12/18 UTC,
regridded by MARS to a regular 0.25 x 0.25 degree grid. One GRIB file per year.

Requires a CDS account with MARS access and credentials in ~/.cdsapirc.

Usage:
    python download_l136.py 2000                  # one year
    python download_l136.py 2000 2002 2005        # selected years
    python download_l136.py 1976-2025 --out /path/to/DATM_data
"""
import argparse
import os
import sys

import cdsapi


def parse_years(tokens):
    years = []
    for tok in tokens:
        if "-" in tok:
            start, end = (int(x) for x in tok.split("-"))
            years.extend(range(start, end + 1))
        else:
            years.append(int(tok))
    return years


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("years", nargs="+", help="years or ranges, e.g. 2000 or 1976-2025")
    parser.add_argument("--out", default=".", help="output directory (default: current)")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    client = cdsapi.Client()

    for yr in parse_years(args.years):
        out = os.path.join(args.out, f"DATM_L136_{yr}.grib")
        if os.path.exists(out) and os.path.getsize(out) > 0:
            print(f"{yr}: {out} exists, skipping")
            continue
        tmp = out + ".part"  # write to a temporary name so interrupted downloads are never mistaken for complete files
        print(f"{yr}: requesting ...")
        client.retrieve("reanalysis-era5-complete", {
            "class": "ea",
            "expver": "1",
            "stream": "oper",
            "type": "an",
            "levtype": "ml",
            "levelist": "136",
            "param": "130/131/132/133",
            "date": f"{yr}-01-01/to/{yr}-12-31",
            "time": "00:00:00/06:00:00/12:00:00/18:00:00",
            "grid": "0.25/0.25",  # regrid spectral t/u/v and gridpoint q to a common lat/lon grid
        }, tmp)
        os.replace(tmp, out)
        print(f"{yr}: saved {out}")


if __name__ == "__main__":
    sys.exit(main())
