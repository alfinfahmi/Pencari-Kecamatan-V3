#!/usr/bin/env python3
"""
Generator tabel "format Ephemeris Hisab Rukyat" dari data JPL DE421.

Sumber posisi: JPL DE421 (integrasi numerik NASA/JPL, berlaku 1900-2050),
dibaca lewat Skyfield (`pip install skyfield skyfield-data`). Ini BUKAN data
buku Ephemeris Kemenag -- hanya disusun dgn KOLOM & SATUAN yg sama, supaya
prosedur hisab Ephemeris (interpolasi jam-jaman, ijtimak dari FIB terkecil,
iterasi ghurub, koreksi parallax/SD/refraksi/dip) bisa dijalankan apa adanya.

Untuk tiap ijtimak (konjungsi bujur ekliptika geosentrik) dlm rentang tahun,
ditulis data per jam (UT/GMT, jam 0-23) utk 2 hari Masehi UTC: hari ijtimak
(D) dan esoknya (D+1). Cukup utk: jam FIB terkecil (+1 jam utk kecepatan) dan
ghurub di Indonesia pada hari ijtimak lokal (WIB/WITA/WIT -> ghurub ~9-12 UT).

Kolom (satuan buku Ephemeris, disimpan desimal):
  tanggal, jam,
  Matahari: elm (Ecliptic Longitude, deg), elb (Ecliptic Latitude, deg),
            ars (Apparent Right Ascension, deg), dks (Apparent Declination, deg),
            r   (True Geocentric Distance, AU), sds (Semi Diameter, deg),
            eps (True Obliquity, deg), eot (Equation of Time, jam)
  Bulan:    alb (Apparent Longitude, deg), alt (Apparent Latitude, deg),
            arm (Apparent Right Ascension, deg), dkm (Apparent Declination, deg),
            hp  (Horizontal Parallax, deg), sdm (Semi Diameter, deg),
            abl (Angle Bright Limb, deg), fib (Fraction Illumination, 0-1)

Satu file per tahun Masehi dari tanggal ijtimak: <out>/<tahun>.csv
Pemakaian: python3 generate_ephemeris.py 2020 2050 ../../assets/data/ephemeris
"""
import math, os, sys, warnings
warnings.filterwarnings("ignore")
from skyfield.api import Loader
from skyfield import almanac
from skyfield.framelib import ecliptic_frame
from skyfield.nutationlib import iau2000b_radians
from skyfield_data import get_skyfield_data_path

load = Loader(get_skyfield_data_path(), expire=False)
ts = load.timescale(builtin=True)
eph = load("de421.bsp")
earth, sun, moon = eph["earth"], eph["sun"], eph["moon"]

R_BUMI_KM = 6378.14          # jari-jari ekuator bumi (Meeus)
AU_KM = 149597870.7

KOLOM = ["tanggal", "jam", "elm", "elb", "ars", "dks", "r", "sds", "eps", "eot",
         "alb", "alt", "arm", "dkm", "hp", "sdm", "abl", "fib"]

def baris(t):
    e = earth.at(t)
    s_app = e.observe(sun).apparent()
    m_app = e.observe(moon).apparent()
    # Bujur/lintang ekliptika SEJATI tanggal itu (termasuk nutasi & aberasi)
    s_lat, s_lon, _ = s_app.frame_latlon(ecliptic_frame)
    m_lat, m_lon, m_dist = m_app.frame_latlon(ecliptic_frame)
    s_ra, s_dec, _ = s_app.radec(epoch="date")
    m_ra, m_dec, _ = m_app.radec(epoch="date")
    r_au = (sun.at(t) - earth.at(t)).distance().au          # jarak geometris
    dm_km = m_dist.km
    # Obliquity sejati = rata2 (IAU 2006) + nutasi deps
    T = (t.tt - 2451545.0) / 36525.0
    eps0 = (84381.406 - 46.836769*T - 0.0001831*T**2 + 0.00200340*T**3) / 3600.0
    dpsi, deps = iau2000b_radians(t)
    eps = eps0 + math.degrees(deps)
    # Equation of Time = waktu matahari hakiki - waktu rata2 (jam)
    ut_jam = (t.ut1 - 0.5) % 1.0 * 24.0
    eot = (t.gast - s_ra.hours + 12.0 - ut_jam) % 24.0
    if eot > 12: eot -= 24.0
    hp = math.degrees(math.asin(R_BUMI_KM / dm_km))
    sdm = 358473400.0 / dm_km / 3600.0                       # Meeus Bab 55
    sds = 959.63 / r_au / 3600.0
    a0, d0 = math.radians(s_ra._degrees), s_dec.radians
    a, d = math.radians(m_ra._degrees), m_dec.radians
    abl = math.degrees(math.atan2(math.cos(d0)*math.sin(a0-a),
          math.sin(d0)*math.cos(d) - math.cos(d0)*math.sin(d)*math.cos(a0-a))) % 360.0
    # FIB: sudut fase dari elongasi geosentrik (Meeus 48.2-48.3)
    psi = math.acos(math.cos(m_lat.radians)*math.cos(m_lon.radians - s_lon.radians))
    R = r_au * AU_KM
    i = math.atan2(R*math.sin(psi), dm_km - R*math.cos(psi))
    fib = (1 + math.cos(i)) / 2
    return [s_lon.degrees, s_lat.degrees, s_ra._degrees, s_dec.degrees, r_au, sds, eps, eot,
            m_lon.degrees, m_lat.degrees, m_ra._degrees, m_dec.degrees, hp, sdm, abl, fib]

FMT = ["%.6f","%.6f","%.6f","%.6f","%.7f","%.6f","%.6f","%.7f",
       "%.6f","%.6f","%.6f","%.6f","%.6f","%.6f","%.4f","%.6f"]

def main(th_awal, th_akhir, out):
    os.makedirs(out, exist_ok=True)
    t0, t1 = ts.utc(th_awal, 1, 1), ts.utc(th_akhir + 1, 1, 1)
    waktu, fase = almanac.find_discrete(t0, t1, almanac.moon_phases(eph))
    per_tahun = {}
    for tw, f in zip(waktu, fase):
        if f != 0: continue
        y, mo, d, *_ = tw.utc
        per_tahun.setdefault(y, []).append((y, mo, d))
    for y, daftar in per_tahun.items():
        with open(os.path.join(out, f"{y}.csv"), "w") as fh:
            fh.write("# Format Ephemeris Hisab Rukyat, data JPL DE421 (Skyfield). Jam = UT/GMT.\n")
            fh.write(",".join(KOLOM) + "\n")
            for (yy, mo, d) in daftar:
                for hari in (0, 1):
                    for jam in range(24):
                        t = ts.utc(yy, mo, d + hari, jam)
                        yd, md, dd = t.utc[:3]
                        nilai = baris(t)
                        fh.write(f"{yd:04d}-{md:02d}-{dd:02d},{jam}," +
                                 ",".join(f % v for f, v in zip(FMT, nilai)) + "\n")
        print(y, len(daftar), "ijtimak")

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
