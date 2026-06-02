"""
Seed script — deletes all existing reports and recreates them through the full backend flow:

  1. Call real Python AI service  (/analyze)
  2. Apply same status logic as triggerAiAnalysis
  3. Insert into PostgreSQL: report, ai_analysis_log
  4. Insert into H3 spatial index: report_h3 + h3_token_agg  (for every PENDING report, res 1-12)
  5. Push to Firebase Realtime Database: reports/{reportId}
"""

import uuid
import json
import math
import time
import psycopg2
import requests
import firebase_admin
import h3 as h3lib
from firebase_admin import credentials, db as rtdb
from datetime import datetime, timedelta
import random

# ── Config ────────────────────────────────────────────────────────────────────
DB = dict(host="localhost", port=5432, dbname="smartcity",
          user="postgres", password="wadea1234")

AI  = "http://localhost:8000"

SERVICE_ACCOUNT = (
    r"E:\FireBase Test\backend\backend\src\main\resources"
    r"\roadna-ce6a0-firebase-adminsdk-fbsvc-bfa3e5fb4c.json"
)
FIREBASE_DB_URL = "https://roadna-ce6a0-default-rtdb.europe-west1.firebasedatabase.app"

USERS = [19, 20, 21, 23, 24, 25]

# ── Report definitions ─────────────────────────────────────────────────────────
# Two geographic clusters: Irbid (32.52-32.58, 35.83-35.89) and Amman (31.93-31.98, 35.87-35.93)
# Every report has a unique lat/lon — each pair is ~350-500m from its nearest neighbour.
REPORTS = [
    # ── Irbid cluster ──────────────────────────────────────────────────────────
    {"user_id": 19, "category": "pothole",       "is_predefined": True,
     "sub_problem": "Deep pothole blocking half the lane",
     "lat": 32.5410, "lon": 35.8510, "days_ago": 1},

    {"user_id": 20, "category": "brokenRoad",    "is_predefined": False,
     "description": "The road surface is completely cracked and broken, making it dangerous for cars",
     "lat": 32.5440, "lon": 35.8560, "days_ago": 2},

    {"user_id": 21, "category": "manhole",       "is_predefined": True,
     "sub_problem": "Open manhole cover in the middle of the road",
     "lat": 32.5470, "lon": 35.8610, "days_ago": 3},

    {"user_id": 23, "category": "lamppost",      "is_predefined": False,
     "description": "Street lamp has been knocked over and is lying across the pavement",
     "lat": 32.5500, "lon": 35.8650, "days_ago": 4},

    {"user_id": 24, "category": "treeInRoad",    "is_predefined": True,
     "sub_problem": "Fallen tree blocking entire road after storm",
     "lat": 32.5380, "lon": 35.8480, "days_ago": 5},

    {"user_id": 25, "category": "speedBump",     "is_predefined": False,
     "description": "Speed bump is completely broken and missing its reflective paint, invisible at night",
     "lat": 32.5350, "lon": 35.8430, "days_ago": 6},

    {"user_id": 19, "category": "unpavedStreet", "is_predefined": True,
     "sub_problem": "Dirt road that floods in rain and needs paving",
     "lat": 32.5530, "lon": 35.8700, "days_ago": 7},

    {"user_id": 20, "category": "pothole",       "is_predefined": False,
     "description": "Multiple large potholes along 200 meters of road near the school, children are at risk",
     "lat": 32.5320, "lon": 35.8390, "days_ago": 8},

    {"user_id": 21, "category": "brokenRoad",    "is_predefined": True,
     "sub_problem": "Severe cracking and subsidence after heavy rainfall",
     "lat": 32.5560, "lon": 35.8740, "days_ago": 9},

    {"user_id": 23, "category": "manhole",       "is_predefined": False,
     "description": "Manhole cover is raised about 10cm above road level, already damaged several tyres",
     "lat": 32.5290, "lon": 35.8350, "days_ago": 10},

    {"user_id": 24, "category": "lamppost",      "is_predefined": True,
     "sub_problem": "Lamppost leaning dangerously over road, may fall",
     "lat": 32.5590, "lon": 35.8780, "days_ago": 11},

    {"user_id": 25, "category": "treeInRoad",    "is_predefined": False,
     "description": "Large branch fell on the road, partially blocking traffic flow",
     "lat": 32.5260, "lon": 35.8310, "days_ago": 12},

    {"user_id": 19, "category": "pothole",       "is_predefined": True,
     "sub_problem": "Pothole causing accidents near the roundabout",
     "lat": 32.5620, "lon": 35.8820, "days_ago": 13},

    {"user_id": 20, "category": "speedBump",     "is_predefined": True,
     "sub_problem": "Speed bump completely eroded and no longer visible",
     "lat": 32.5230, "lon": 35.8270, "days_ago": 14},

    {"user_id": 21, "category": "unpavedStreet", "is_predefined": False,
     "description": "This side road has never been paved. Cars get stuck in mud every winter",
     "lat": 32.5650, "lon": 35.8860, "days_ago": 15},

    # ── Amman cluster ──────────────────────────────────────────────────────────
    {"user_id": 23, "category": "pothole",       "is_predefined": True,
     "sub_problem": "Deep pothole causing heavy vehicle damage",
     "lat": 31.9520, "lon": 35.8920, "days_ago": 3},

    {"user_id": 24, "category": "brokenRoad",    "is_predefined": False,
     "description": "Road surface is crumbling on both sides, water damage visible underneath",
     "lat": 31.9560, "lon": 35.8970, "days_ago": 5},

    {"user_id": 25, "category": "manhole",       "is_predefined": True,
     "sub_problem": "Broken manhole cover, open hole in traffic lane",
     "lat": 31.9600, "lon": 35.9020, "days_ago": 7},

    {"user_id": 19, "category": "lamppost",      "is_predefined": False,
     "description": "Two consecutive lampposts are not working, whole street is completely dark at night",
     "lat": 31.9640, "lon": 35.9060, "days_ago": 9},

    {"user_id": 20, "category": "treeInRoad",    "is_predefined": True,
     "sub_problem": "Fallen palm tree blocking the main road completely",
     "lat": 31.9480, "lon": 35.8870, "days_ago": 10},

    {"user_id": 21, "category": "speedBump",     "is_predefined": False,
     "description": "Speed bump paint is completely faded, drivers don't slow down near the school",
     "lat": 31.9440, "lon": 35.8830, "days_ago": 12},

    {"user_id": 23, "category": "unpavedStreet", "is_predefined": True,
     "sub_problem": "Gravel road turns to mud in rain and becomes impassable",
     "lat": 31.9680, "lon": 35.9100, "days_ago": 13},

    {"user_id": 24, "category": "pothole",       "is_predefined": False,
     "description": "Massive pothole 60cm wide near the intersection, already caused two accidents this week",
     "lat": 31.9400, "lon": 35.8790, "days_ago": 14},

    {"user_id": 25, "category": "brokenRoad",    "is_predefined": True,
     "sub_problem": "Road subsidence creating dangerous slope across lane",
     "lat": 31.9720, "lon": 35.9140, "days_ago": 15},

    {"user_id": 19, "category": "manhole",       "is_predefined": False,
     "description": "Manhole cover is missing entirely, just an open hole in the road near the bus stop",
     "lat": 31.9360, "lon": 35.8750, "days_ago": 16},

    {"user_id": 20, "category": "lamppost",      "is_predefined": True,
     "sub_problem": "Fallen lamppost blocking pavement and part of road",
     "lat": 31.9760, "lon": 35.9180, "days_ago": 17},

    {"user_id": 21, "category": "treeInRoad",    "is_predefined": False,
     "description": "Several tree branches blocking the road after last night's wind storm",
     "lat": 31.9800, "lon": 35.9220, "days_ago": 18},

    {"user_id": 23, "category": "pothole",       "is_predefined": True,
     "sub_problem": "Pothole with exposed rebar creating critical hazard",
     "lat": 31.9320, "lon": 35.8710, "days_ago": 19},

    {"user_id": 24, "category": "speedBump",     "is_predefined": False,
     "description": "Speed bump is cracked in half and one section has been displaced to the side of the road",
     "lat": 31.9840, "lon": 35.9260, "days_ago": 20},

    {"user_id": 25, "category": "unpavedStreet", "is_predefined": True,
     "sub_problem": "Unpaved access road to residential area with 200 families",
     "lat": 31.9280, "lon": 35.8670, "days_ago": 21},
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def to_xyz(lat: float, lon: float) -> tuple[float, float, float]:
    """Same formula as GeoUtil.toXYZ in Java."""
    lat_r = math.radians(lat)
    lon_r = math.radians(lon)
    return (
        math.cos(lat_r) * math.cos(lon_r),
        math.cos(lat_r) * math.sin(lon_r),
        math.sin(lat_r),
    )


def call_analyze(r: dict) -> dict:
    payload = {
        "category":            r["category"],
        "sub_problem":         r.get("sub_problem"),
        "description":         r.get("description"),
        "lat":                 r["lat"],
        "lon":                 r["lon"],
        "still_votes":         0,
        "is_predefined":       r["is_predefined"],
        "image_description":   None,
        "image_count":         0,
        "nemotron_detected":   False,
        "nemotron_category":   "other",
        "nemotron_confidence": 0.0,
        "nemotron_severity":   None,
        "nemotron_scene_type": None,
        "highway":             None,
        "maxspeed":            None,
        "lanes":               None,
        "road_name":           None,
    }
    resp = requests.post(f"{AI}/analyze", json=payload, timeout=120)
    resp.raise_for_status()
    return resp.json()


def determine_status(ai: dict) -> tuple[str, str, str]:
    confidence = ai["confidence"]
    valid      = ai["valid"]
    priority   = (ai.get("priority") or "MEDIUM").upper()
    reason     = ai.get("reason", "Validated by AI.")

    if confidence < 0.50:
        return "REJECTED", "LOW", "Auto-rejected: AI confidence too low ({:.0f}%).".format(confidence * 100)
    elif valid:
        return "PENDING", priority, reason
    else:
        return "UNASSESSED", "LOW", reason


def insert_h3(cur, report_id: str, lat: float, lon: float):
    """
    Mirrors H3ReportService.InsertReportH3 — inserts report_h3 rows and
    accumulates XYZ into h3_token_agg for resolutions 1-12.
    """
    x, y, z = to_xyz(lat, lon)
    for res in range(1, 13):
        # h3lib returns a string hex; cast to signed int64 to match Java's Long
        cell_hex = h3lib.latlng_to_cell(lat, lon, res)
        # Convert hex string to unsigned int, then to signed int64
        token = int(cell_hex, 16)
        if token >= (1 << 63):
            token -= (1 << 64)

        cur.execute(
            "INSERT INTO report_h3 (id, h3token, rep_id) VALUES (nextval('report_h3_seq'), %s, %s)",
            (token, report_id)
        )

        cur.execute("SELECT h3token_id, x, y, z, count FROM h3_token_agg WHERE h3token_id = %s", (token,))
        row = cur.fetchone()
        if row:
            cur.execute(
                "UPDATE h3_token_agg SET x=%s, y=%s, z=%s, count=%s WHERE h3token_id=%s",
                (row[1] + x, row[2] + y, row[3] + z, row[4] + 1, token)
            )
        else:
            cur.execute(
                "INSERT INTO h3_token_agg (h3token_id, x, y, z, count) VALUES (%s, %s, %s, %s, 1)",
                (token, x, y, z)
            )


def push_firebase(report_id: str, still: int, fixed: int, status: str, priority: str):
    """Mirrors RealtimeDbService.pushReportUpdate."""
    ref = rtdb.reference(f"reports/{report_id}")
    data = {"stillVotes": still, "fixedVotes": fixed, "status": status, "priority": priority}
    ref.set(data)


# ── Main ─────────────────────────────────────────────────────────────────────

def seed():
    # ── Init Firebase ──────────────────────────────────────────────────────────
    print("Initialising Firebase Admin SDK...")
    cred = credentials.Certificate(SERVICE_ACCOUNT)
    firebase_admin.initialize_app(cred, {"databaseURL": FIREBASE_DB_URL})

    # ── Connect PostgreSQL ─────────────────────────────────────────────────────
    conn = psycopg2.connect(**DB)
    cur  = conn.cursor()

    # ── Clear all report-related tables + Firebase node ───────────────────────
    print("Deleting existing report data from PostgreSQL...")
    cur.execute("DELETE FROM ai_analysis_log")
    cur.execute("DELETE FROM report_image_urls")
    cur.execute("DELETE FROM report_h3")
    cur.execute("DELETE FROM h3_token_agg")
    cur.execute("DELETE FROM user_vote")
    cur.execute("DELETE FROM report")
    conn.commit()

    print("Clearing Firebase reports node...")
    for attempt in range(3):
        try:
            rtdb.reference("reports").delete()
            break
        except Exception as e:
            print(f"  Firebase delete attempt {attempt+1} failed: {e}")
            time.sleep(3)

    print(f"All cleared. Seeding {len(REPORTS)} reports...\n")

    inserted = 0
    for i, r in enumerate(REPORTS):
        report_id  = str(uuid.uuid4())
        ai_text    = r.get("sub_problem") or r.get("description", "")
        created_at = datetime.now() - timedelta(
            days=r["days_ago"],
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59)
        )

        print(f"[{i+1:02d}/{len(REPORTS)}] {r['category']:15s} user={r['user_id']} "
              f"({r['lat']:.4f}, {r['lon']:.4f}) -> AI...", end=" ", flush=True)

        try:
            ai = call_analyze(r)
        except Exception as e:
            print(f"AI FAILED ({e}) -- skipping")
            continue

        status, priority, reason = determine_status(ai)
        confidence = ai["confidence"]

        short_reason = reason[:252] + "..." if len(reason) > 255 else reason

        # ── 1. Insert report ───────────────────────────────────────────────────
        cur.execute("""
            INSERT INTO report (
                report_id, user_id, category, sub_problem, description,
                lat, lon, status, priority, priority_set_by,
                still_votes, fixed_votes,
                validation_score, validation_reason, revalidation_count,
                metadata, created_at, unassessed_at, resolved_at
            ) VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, 'AI',
                0, 0,
                %s, %s, 1,
                '{}', %s, %s, NULL
            )
        """, (
            report_id, r["user_id"], r["category"],
            r.get("sub_problem"), ai_text,
            r["lat"], r["lon"],
            status, priority,
            confidence, short_reason,
            created_at, created_at,
        ))

        # ── 2. Insert AI analysis log ──────────────────────────────────────────
        cur.execute("""
            INSERT INTO ai_analysis_log (
                id, report_id, ran_at, valid, confidence, reason, priority, trigger
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'SUBMIT')
        """, (
            str(uuid.uuid4()), report_id,
            created_at + timedelta(seconds=random.randint(10, 45)),
            ai["valid"], confidence,
            reason[:2000], priority,
        ))

        # ── 3. H3 spatial index (only for map-visible reports) ─────────────────
        if status not in ("REJECTED", "UNASSESSED"):
            insert_h3(cur, report_id, r["lat"], r["lon"])

        conn.commit()

        # ── 4. Firebase Realtime Database ──────────────────────────────────────
        try:
            push_firebase(report_id, 0, 0, status, priority)
            fb_ok = "FB:ok"
        except Exception as e:
            fb_ok = f"FB:FAIL({e})"

        inserted += 1
        print(f"conf={confidence:.3f} => {status:10s} pri={priority:8s} H3:{'yes' if status=='PENDING' else 'no ':3s} {fb_ok}")

        time.sleep(1.5)

    cur.close()
    conn.close()

    print(f"\nDone. {inserted}/{len(REPORTS)} reports seeded.")

    # ── Final summary ──────────────────────────────────────────────────────────
    conn2 = psycopg2.connect(**DB)
    cur2  = conn2.cursor()
    cur2.execute("SELECT status, COUNT(*) FROM report GROUP BY status ORDER BY COUNT(*) DESC")
    print("\nPostgreSQL status summary:")
    for row in cur2.fetchall():
        print(f"  {row[0]:12s}: {row[1]}")
    cur2.execute("SELECT COUNT(*) FROM report_h3")
    print(f"\nreport_h3 rows   : {cur2.fetchone()[0]}")
    cur2.execute("SELECT COUNT(*) FROM h3_token_agg")
    print(f"h3_token_agg rows: {cur2.fetchone()[0]}")
    cur2.execute("SELECT COUNT(*) FROM ai_analysis_log")
    print(f"ai_analysis_log  : {cur2.fetchone()[0]}")
    cur2.close()
    conn2.close()


if __name__ == "__main__":
    seed()
