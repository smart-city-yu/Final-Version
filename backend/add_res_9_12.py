"""
add_res_9_12.py  — adds H3 resolutions 9-12 for the 200 seed reports
"""
import h3, math, os

OUT = os.path.join(os.path.dirname(__file__), "seed_res9_12.sql")

LOCATIONS = [
    (31.9539,35.9106),(31.9638,35.8803),(31.9836,35.8947),(31.9540,35.9267),(31.9972,35.9381),
    (31.9788,35.8556),(31.9592,35.8556),(31.9600,35.8750),(31.9450,35.9100),(32.0100,36.0400),
    (32.5556,35.8500),(32.5356,35.8572),(32.5700,35.8600),(32.5200,35.8450),(32.5450,35.8650),
    (32.0728,36.0876),(32.0500,36.0500),(29.5321,35.0062),(29.5200,35.0150),(31.7167,35.8000),
    (32.2714,35.8967),(32.0392,35.7283),(31.1756,35.7053),(30.1928,35.7345),(32.3428,36.2080),
]

def h3int(lat, lon, res):
    try:    s = h3.latlng_to_cell(lat, lon, res)
    except: s = h3.geo_to_h3(lat, lon, res)
    v = int(s, 16)
    return v - 2**64 if v >= 2**63 else v

def xyz(lat, lon):
    lr, pr = math.radians(lat), math.radians(lon)
    return math.cos(lr)*math.cos(pr), math.cos(lr)*math.sin(pr), math.sin(lr)

rows, agg = [], {}
for i in range(1, 201):
    uuid = f'a{i:07x}-beef-4abc-8def-{i:012x}'
    lat, lon = LOCATIONS[(i-1) % 25]
    x0, y0, z0 = xyz(lat, lon)
    for res in range(9, 13):
        tok = h3int(lat, lon, res)
        rows.append((tok, uuid))
        if tok not in agg:
            agg[tok] = {'count':0,'x':0.0,'y':0.0,'z':0.0}
        agg[tok]['count'] += 1
        agg[tok]['x'] += x0; agg[tok]['y'] += y0; agg[tok]['z'] += z0

with open(OUT, 'w', encoding='utf-8') as f:
    f.write("BEGIN;\n\n")
    f.write(f"-- report_h3: {len(rows)} new rows (200 reports x 4 resolutions)\n")
    f.write("INSERT INTO report_h3 (id, h3token, rep_id)\n")
    f.write("SELECT nextval('report_h3_seq'), v.token, v.rid FROM (VALUES\n")
    f.write(",\n".join(f"  ({t}::bigint,'{u}')" for t,u in rows))
    f.write("\n) AS v(token,rid)\nWHERE NOT EXISTS (\n")
    f.write("  SELECT 1 FROM report_h3 rh WHERE rh.h3token=v.token AND rh.rep_id=v.rid\n);\n\n")
    f.write(f"-- h3_token_agg: {len(agg)} new tokens\n")
    f.write("INSERT INTO h3_token_agg (h3token_id, count, x, y, z) VALUES\n")
    f.write(",\n".join(f"  ({t},{v['count']},{v['x']:.15f},{v['y']:.15f},{v['z']:.15f})" for t,v in agg.items()))
    f.write("\nON CONFLICT (h3token_id) DO UPDATE\n")
    f.write("  SET count=h3_token_agg.count+EXCLUDED.count,\n")
    f.write("      x=h3_token_agg.x+EXCLUDED.x,\n")
    f.write("      y=h3_token_agg.y+EXCLUDED.y,\n")
    f.write("      z=h3_token_agg.z+EXCLUDED.z;\n\n")
    f.write("COMMIT;\n")

print(f"Done  H3 rows:{len(rows)}  new tokens:{len(agg)}")
