#!/usr/bin/env python3
"""
Implementasi RUJUKAN (Python) prosedur hisab awal bulan metode Ephemeris
Hisab Rukyat -- dipakai utk memvalidasi port Dart (lib/services/
hisab_ephemeris_service.dart) & membangkitkan angka uji unit test.
Langkah & rumus sama persis dgn versi Dart (lihat komentar di sana).
"""
import csv, math, sys
from datetime import datetime, timedelta, date

sind=lambda x: math.sin(math.radians(x)); cosd=lambda x: math.cos(math.radians(x))
tand=lambda x: math.tan(math.radians(x))
asind=lambda x: math.degrees(math.asin(max(-1,min(1,x))))
acosd=lambda x: math.degrees(math.acos(max(-1,min(1,x))))
atan2d=lambda y,x: math.degrees(math.atan2(y,x))
REFRAKSI_UFUK = 34.5/60      # 34'30"
SUDUT_KOLOM_SUDUT = {"elm","ars","alb","arm","abl"}   # kolom 0-360 (perlu unwrap)

class Data:
    def __init__(self, paths):
        self.b = {}
        for p in paths:
            with open(p) as fh:
                rows = [r for r in fh if not r.startswith("#")]
            for r in csv.DictReader(rows):
                k = (r["tanggal"], int(r["jam"]))
                self.b[k] = {c: float(v) for c, v in r.items() if c not in ("tanggal","jam")}
    def jam(self, dt):  # baris pd jam bulat UTC
        return self.b[(dt.strftime("%Y-%m-%d"), dt.hour)]
    def interp(self, utc, kolom):
        """Interpolasi Ephemeris: A - (A-B)*C/I  (linier antar jam)."""
        a_dt = utc.replace(minute=0, second=0, microsecond=0)
        c = (utc - a_dt).total_seconds()/3600
        A = self.jam(a_dt)[kolom]; B = self.jam(a_dt+timedelta(hours=1))[kolom]
        if kolom in SUDUT_KOLOM_SUDUT and abs(B-A) > 180: B += 360 if B < A else -360
        v = A - (A-B)*c
        return v % 360 if kolom in SUDUT_KOLOM_SUDUT else v

def ijtimak_utc(d, perkiraan_utc):
    """FIB terkecil -> jam X; ijtimak = X + (ELM-ALB)/(SB-SM)."""
    kandidat = []
    t = (perkiraan_utc - timedelta(hours=30)).replace(minute=0, second=0, microsecond=0)
    for i in range(61):
        tt = t + timedelta(hours=i)
        try: kandidat.append((d.jam(tt)["fib"], tt))
        except KeyError: pass
    _, X = min(kandidat)
    r0, r1 = d.jam(X), d.jam(X+timedelta(hours=1))
    elm, alb = r0["elm"], r0["alb"]
    sb = (r1["alb"]-r0["alb"]) % 360; sm = (r1["elm"]-r0["elm"]) % 360
    selisih = (elm - alb + 180) % 360 - 180
    return X + timedelta(hours=selisih/(sb-sm))

def hitung(d, ijtimak, lat, lng, elev, zona):
    lokal = ijtimak + timedelta(hours=zona)
    hari = datetime(lokal.year, lokal.month, lokal.day)
    dip = 1.76/60*math.sqrt(max(elev,0))
    # --- Ghurub matahari (iterasi) ---
    ghurub = 18.0                          # tebakan awal jam lokal
    for _ in range(5):
        g_utc = hari + timedelta(hours=ghurub - zona)
        dks = d.interp(g_utc,"dks"); e = d.interp(g_utc,"eot"); sds = d.interp(g_utc,"sds")
        h0 = -(sds + REFRAKSI_UFUK + dip)
        t0 = acosd(-tand(lat)*tand(dks) + sind(h0)/cosd(lat)/cosd(dks))
        baru = 12 - e + t0/15 + (zona*15 - lng)/15
        if abs(baru-ghurub) < 1e-7: ghurub = baru; break
        ghurub = baru
    g_utc = hari + timedelta(hours=ghurub - zona)
    ars=d.interp(g_utc,"ars"); dks=d.interp(g_utc,"dks")
    arm=d.interp(g_utc,"arm"); dkm=d.interp(g_utc,"dkm")
    hp=d.interp(g_utc,"hp"); sdm=d.interp(g_utc,"sdm")
    elm=d.interp(g_utc,"elm"); alb=d.interp(g_utc,"alb")
    tb = (ars - arm + t0 + 540) % 360 - 180
    h = asind(sind(lat)*sind(dkm) + cosd(lat)*cosd(dkm)*cosd(tb))   # hakiki (geosentrik)
    h1 = h - hp*cosd(h)                                             # - parallax
    x = h1 + sdm
    ref = 0.0167/tand(x + 7.31/(x+4.4))                             # Bennett
    mari = x + ref + dip                                            # piringan atas, teramati
    def az_bu(t, dek):  # derajat dari Barat, + Utara / - Selatan
        az_s = atan2d(sind(t), cosd(t)*sind(lat) - tand(dek)*cosd(lat))
        r = (az_s - 90) % 360
        return r - 360 if r > 180 else r
    azs, azm = az_bu(t0, dks), az_bu(tb, dkm)
    elong = acosd(sind(dks)*sind(dkm) + cosd(dks)*cosd(dkm)*cosd(ars-arm))
    lama = mari/15
    return dict(ghurub=ghurub, h0=h0, t0=t0, tb=tb, dks=dks, dkm=dkm, hakiki=h, mari=mari,
                elongasi=elong, azs=azs, azm=azm, lama=lama, elm=elm, alb=alb,
                nurul=math.sqrt((azm-azs)**2 + h*h)/15*2.5)

def dms(x):
    s = "-" if x < 0 else ""; x = abs(x); dd = int(x); m = int((x-dd)*60); sc = ((x-dd)*60-m)*60
    return f"{s}{dd}°{m:02d}'{sc:05.2f}\""
def jam(x):
    x %= 24; h=int(x); m=int((x-h)*60); s=((x-h)*60-m)*60
    return f"{h:02d}:{m:02d}:{s:05.2f}"

if __name__ == "__main__":
    d = Data(sys.argv[1:] or ["/tmp/eph/2026.csv"])
    ij = ijtimak_utc(d, datetime(2026,2,17,12))
    print("Ijtimak:", ij, "UTC  =", jam(ij.hour+ij.minute/60+ij.second/3600+7), "WIB")
    for nama,lat,lng,el,z in [("Jakarta Pusat",-6.1754,106.8272,0,7),("Banda Aceh",5.5577,95.3222,0,7),
                              ("Mentawai (Tuapejat)",-2.0333,99.5833,0,7),("Jayapura",-2.5333,140.7167,0,9)]:
        r = hitung(d, ij, lat, lng, el, z)
        print(f"{nama:22s} ghurub {jam(r['ghurub'])}  hakiki {dms(r['hakiki'])}  mar'i {dms(r['mari'])}  elong {dms(r['elongasi'])}")
