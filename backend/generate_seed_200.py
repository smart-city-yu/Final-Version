"""
generate_seed_200.py
--------------------
Generates seed_200_h3.sql — 200 reports across Jordan WITH correct H3 index data.
Mirrors InsertReportH3: resolutions 1..8 per report.

Run:
    pip install h3
    python generate_seed_200.py
"""

import h3
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "seed_200_h3.sql")

# ── 25 Jordan locations (lat, lon) ─────────────────────────────────────────
LOCATIONS = [
    (31.9539, 35.9106),  #  1 Amman Downtown
    (31.9638, 35.8803),  #  2 Abdoun
    (31.9836, 35.8947),  #  3 Shmeisani
    (31.9540, 35.9267),  #  4 Jabal Amman
    (31.9972, 35.9381),  #  5 Marka
    (31.9788, 35.8556),  #  6 Sports City
    (31.9592, 35.8556),  #  7 7th Circle
    (31.9600, 35.8750),  #  8 Swefieh
    (31.9450, 35.9100),  #  9 Tla Ali
    (32.0100, 36.0400),  # 10 Al-Rusaifah
    (32.5556, 35.8500),  # 11 Irbid Downtown
    (32.5356, 35.8572),  # 12 Irbid University
    (32.5700, 35.8600),  # 13 Yarmouk
    (32.5200, 35.8450),  # 14 Irbid South
    (32.5450, 35.8650),  # 15 Irbid North
    (32.0728, 36.0876),  # 16 Zarqa
    (32.0500, 36.0500),  # 17 Rusaifa
    (29.5321, 35.0062),  # 18 Aqaba
    (29.5200, 35.0150),  # 19 Aqaba Beach
    (31.7167, 35.8000),  # 20 Madaba
    (32.2714, 35.8967),  # 21 Jerash
    (32.0392, 35.7283),  # 22 Salt
    (31.1756, 35.7053),  # 23 Karak
    (30.1928, 35.7345),  # 24 Ma'an
    (32.3428, 36.2080),  # 25 Mafraq
]

# ── Same patterns as seed_200_reports.sql ──────────────────────────────────
STATUS_PAT  = (['PENDING']*8 + ['IN_PROGRESS']*3 + ['RESOLVED']*5 +
               ['REJECTED']*3 + ['UNASSESSED']*1)
PRI_PAT     = ['LOW']*3 + ['MEDIUM']*4 + ['HIGH']*2 + ['CRITICAL']*1
REJ_PRI     = ['LOW']*3 + ['MEDIUM']*1
USER_IDS    = [19, 20, 21, 22]   # corrected from earlier fix

CATS = ['pothole','brokenRoad','manhole','lamppost',
        'speedBump','treeInRoad','unpavedStreet']

DESCS = {
    'pothole':      ['Large pothole causing vehicle damage near traffic signal',
                     'Deep pothole after recent road construction work',
                     'Multiple potholes forming dangerous cluster in area',
                     'Pothole expanding after heavy rainfall blocking right lane',
                     'Severe pothole damaging vehicle tires and suspensions',
                     'Pothole near school entrance creating daily hazard',
                     'Road pothole partially blocking emergency vehicle access',
                     'Wide pothole at intersection causing traffic disruption'],
    'brokenRoad':   ['Severe road cracks and surface deterioration affecting traffic',
                     'Road subsidence creating dangerous raised bump section',
                     'Road surface peeling and crumbling after winter season',
                     'Broken asphalt from utility excavation left unrepaired',
                     'Road damage from heavy truck traffic needing urgent repair',
                     'Large crack splitting road lane into hazardous sections',
                     'Crumbling road edges creating safety hazard for cyclists',
                     'Road surface deterioration severely affecting daily traffic flow'],
    'manhole':      ['Open manhole without warning signs or protective cover',
                     'Broken manhole cover creating dangerous road hazard',
                     'Missing manhole lid dangerous for pedestrians at night',
                     'Raised manhole cover causing vehicle suspension damage',
                     'Sunken manhole collecting water and creating pool hazard',
                     'Cracked manhole cover about to collapse under traffic load',
                     'Open drainage manhole near school entrance',
                     'Loose manhole cover making dangerous noise and road hazard'],
    'lamppost':     ['Street light completely non-functional causing unsafe dark road',
                     'Broken lamppost leaning dangerously toward traffic lane',
                     'Multiple street lights out creating unsafe area at night',
                     'Lamppost damaged by vehicle collision blocking pedestrian path',
                     'Flickering street light causing distraction to drivers',
                     'Exposed lamppost electrical wires dangerous to public',
                     'Corroded lamppost pole structurally unstable and dangerous',
                     'Street light out at pedestrian crossing creating danger'],
    'speedBump':    ['Speed bump completely unmarked and invisible at night',
                     'Damaged speed bump with sharp exposed metal edges',
                     'Speed bump paint completely faded and invisible to drivers',
                     'Unauthorized speed bump causing unnecessary traffic issues',
                     'Speed bump too high causing vehicle underside damage',
                     'Broken speed bump section missing creating road hazard',
                     'Speed bump road markings completely worn away',
                     'Incorrectly installed speed bump causing vehicle accidents'],
    'treeInRoad':   ['Large tree fallen blocking entire road after heavy storm',
                     'Overhanging tree branches blocking traffic and road signs',
                     'Tree roots lifting and cracking road surface severely',
                     'Fallen tree blocking main street needs urgent removal',
                     'Dead tree leaning dangerously over busy road',
                     'Tree branches fallen blocking pedestrian pathway',
                     'Tree growing into road reducing lane width significantly',
                     'Uprooted tree blocking road after heavy rain and wind'],
    'unpavedStreet':['Unpaved dirt road causing severe dust and health issues',
                     'Gravel road flooding and becoming impassable during rain',
                     'Unpaved road creating dangerous mud conditions in winter',
                     'Dirt road with large rocks causing daily vehicle damage',
                     'Unpaved residential street urgently needs paving',
                     'Deteriorating gravel path with deep uneven surface',
                     'Dirt road with large holes affecting daily commuters',
                     'Unpaved street causing flooding in nearby properties'],
}

# ── H3 helpers ────────────────────────────────────────────────────────────
def get_h3_int(lat, lon, res):
    """Return H3 cell as signed Python int (matches Java Long)."""
    try:
        hex_str = h3.latlng_to_cell(lat, lon, res)   # h3 v4
    except AttributeError:
        hex_str = h3.geo_to_h3(lat, lon, res)          # h3 v3
    val = int(hex_str, 16)
    if val >= 2**63:
        val -= 2**64
    return val

def unit_xyz(lat, lon):
    lr, pr = math.radians(lat), math.radians(lon)
    return (math.cos(lr)*math.cos(pr),
            math.cos(lr)*math.sin(pr),
            math.sin(lr))

# ── Build report list & H3 index ─────────────────────────────────────────
report_h3_rows = []   # (token_int, uuid)
token_agg      = {}   # token_int -> {count, x, y, z}
reports        = []

for i in range(1, 201):
    uuid   = f'a{i:07x}-beef-4abc-8def-{i:012x}'
    cat    = CATS[(i-1) % 7]
    stat   = STATUS_PAT[(i-1) % 20]
    pri    = PRI_PAT[(i-1) % 10]
    uid    = USER_IDS[(i-1) // 50]
    lat, lon = LOCATIONS[(i-1) % 25]
    desc   = DESCS[cat][(i-1) % 8]

    # Status-specific fields
    if stat == 'PENDING':
        still, fixed = (i%14)+2, i%3
        score  = round(0.60 + (i%36)*0.01, 2)
        reason = 'AI validated — awaiting city worker assignment'
        rcount = 1 + (i%2)
        rpri   = pri
        setby  = 'ADMIN' if pri in ('HIGH','CRITICAL') and i%3==0 else 'AI'
        res_ts = 'NULL'
    elif stat == 'IN_PROGRESS':
        still, fixed = (i%20)+10, i%5
        score  = round(0.80 + (i%20)*0.01, 2)
        reason = 'High-confidence report — city workers dispatched'
        rcount = 1 + (i%3)
        rpri   = pri
        setby  = 'ADMIN' if i%2==0 else 'AI'
        res_ts = 'NULL'
    elif stat == 'RESOLVED':
        still, fixed = (i%15)+5, (i%10)+5
        score  = round(0.75 + (i%25)*0.01, 2)
        reason = 'Issue confirmed and resolved by maintenance crew'
        rcount = 2 + (i%2)
        rpri   = pri
        setby  = 'ADMIN' if i%3==0 else 'AI'
        res_ts = f"'2026-01-10 08:00:00'::TIMESTAMP + ({i-1} * INTERVAL '17 hours') + INTERVAL '5 days'"
    elif stat == 'REJECTED':
        still, fixed = i%6, i%8
        score  = round(0.20 + (i%35)*0.01, 2)
        reason = 'Insufficient evidence or community support — auto-rejected'
        rcount = i%2
        rpri   = REJ_PRI[(i-1) % 4]
        setby  = 'AI'
        res_ts = 'NULL'
    else:  # UNASSESSED
        still, fixed = i%4, 0
        score  = round(0.10 + (i%30)*0.01, 2)
        reason = 'Awaiting AI analysis'
        rcount = 0
        rpri   = 'LOW'
        setby  = 'AI'
        res_ts = 'NULL'

    reports.append(dict(uuid=uuid, uid=uid, desc=desc, lat=lat, lon=lon,
                        cat=cat, stat=stat, pri=rpri, setby=setby,
                        still=still, fixed=fixed, score=score,
                        reason=reason, rcount=rcount, res_ts=res_ts, i=i))

    # H3 tokens resolutions 1-8
    x0, y0, z0 = unit_xyz(lat, lon)
    for res in range(1, 9):
        tok = get_h3_int(lat, lon, res)
        report_h3_rows.append((tok, uuid))
        if tok not in token_agg:
            token_agg[tok] = {'count': 0, 'x': 0.0, 'y': 0.0, 'z': 0.0}
        token_agg[tok]['count'] += 1
        token_agg[tok]['x']     += x0
        token_agg[tok]['y']     += y0
        token_agg[tok]['z']     += z0

# ── Write SQL ─────────────────────────────────────────────────────────────
with open(OUT, 'w', encoding='utf-8') as f:
    f.write("-- Auto-generated by generate_seed_200.py\n")
    f.write("-- 200 reports across Jordan WITH H3 index (resolutions 1-8)\n\n")
    f.write("BEGIN;\n\n")

    # 1. report
    f.write("-- ===========================================================\n")
    f.write("-- 1. report  (200 rows)\n")
    f.write("-- ===========================================================\n")
    f.write("INSERT INTO report (\n")
    f.write("    report_id, user_id, description, sub_problem, note,\n")
    f.write("    lat, lon, category, status, priority, priority_set_by,\n")
    f.write("    created_at, resolved_at, unassessed_at,\n")
    f.write("    still_votes, fixed_votes, validation_score,\n")
    f.write("    validation_reason, revalidation_count\n")
    f.write(") VALUES\n")
    rows = []
    for r in reports:
        created = f"'2026-01-10 08:00:00'::TIMESTAMP + ({r['i']-1} * INTERVAL '17 hours')"
        if r['res_ts'] == 'NULL':
            resolved = 'NULL'
        else:
            resolved = r['res_ts']
        desc_esc = r['desc'].replace("'", "''")
        reason_esc = r['reason'].replace("'", "''")
        rows.append(
            f"  ('{r['uuid']}', {r['uid']}, '{desc_esc}', NULL, NULL,\n"
            f"   {r['lat']}, {r['lon']}, '{r['cat']}', '{r['stat']}', "
            f"'{r['pri']}', '{r['setby']}',\n"
            f"   {created},\n"
            f"   {resolved},\n"
            f"   {created},\n"
            f"   {r['still']}, {r['fixed']}, {r['score']},\n"
            f"   '{reason_esc}', {r['rcount']})"
        )
    f.write(",\n".join(rows))
    f.write("\nON CONFLICT (report_id) DO NOTHING;\n\n")

    # 2. report_h3
    f.write("-- ===========================================================\n")
    f.write(f"-- 2. report_h3  ({len(report_h3_rows)} rows = 200 reports × 8 resolutions)\n")
    f.write("-- ===========================================================\n")
    f.write("INSERT INTO report_h3 (id, h3token, rep_id)\n")
    f.write("SELECT nextval('report_h3_seq'), v.token, v.rid\n")
    f.write("FROM (VALUES\n")
    h3_rows_sql = []
    for tok, uuid in report_h3_rows:
        h3_rows_sql.append(f"  ({tok}::bigint, '{uuid}')")
    f.write(",\n".join(h3_rows_sql))
    f.write("\n) AS v(token, rid)\n")
    f.write("WHERE NOT EXISTS (\n")
    f.write("  SELECT 1 FROM report_h3 rh\n")
    f.write("   WHERE rh.h3token = v.token AND rh.rep_id = v.rid\n")
    f.write(");\n\n")

    # 3. h3_token_agg
    f.write("-- ===========================================================\n")
    f.write(f"-- 3. h3_token_agg  ({len(token_agg)} unique tokens)\n")
    f.write("-- ===========================================================\n")
    f.write("INSERT INTO h3_token_agg (h3token_id, count, x, y, z)\n")
    f.write("VALUES\n")
    agg_rows = []
    for tok, v in token_agg.items():
        agg_rows.append(
            f"  ({tok}, {v['count']}, "
            f"{v['x']:.15f}, {v['y']:.15f}, {v['z']:.15f})"
        )
    f.write(",\n".join(agg_rows))
    f.write("\nON CONFLICT (h3token_id) DO UPDATE\n")
    f.write("  SET count = h3_token_agg.count + EXCLUDED.count,\n")
    f.write("      x     = h3_token_agg.x     + EXCLUDED.x,\n")
    f.write("      y     = h3_token_agg.y     + EXCLUDED.y,\n")
    f.write("      z     = h3_token_agg.z     + EXCLUDED.z;\n\n")

    f.write("COMMIT;\n")
    f.write(f"-- Done: 200 reports, {len(report_h3_rows)} H3 rows, {len(token_agg)} unique tokens\n")

print(f"Done: {OUT}")
print(f"  Reports   : 200")
print(f"  H3 rows   : {len(report_h3_rows)}")
print(f"  Agg tokens: {len(token_agg)}")
