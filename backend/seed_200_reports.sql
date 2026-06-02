-- ============================================================
-- 200 seed reports spread across Jordan
-- Users: 24 (Omar) · 25 (WADEA) · 26 (wadea) · 27 (Test Claude)
-- 50 reports per user
-- Run in pgAdmin Query Tool against the smartcity database
-- ============================================================

DO $$
DECLARE
    i          INTEGER;
    uuid_str   TEXT;

    user_ids   INTEGER[] := ARRAY[24, 25, 26, 27];

    cats TEXT[] := ARRAY[
        'pothole','brokenRoad','manhole','lamppost',
        'speedBump','treeInRoad','unpavedStreet'
    ];

    -- 25 real Jordan locations  (lat, lon)
    lats NUMERIC[] := ARRAY[
        31.9539, 31.9638, 31.9836, 31.9540, 31.9972,   -- Amman (downtown / Abdoun / Shmeisani / Jabal / Marka)
        31.9788, 31.9592, 31.9600, 31.9450, 32.0100,   -- Amman (Sports City / 7th Circle / Swefieh / Tla' Ali / Al-Rusaifah)
        32.5556, 32.5356, 32.5700, 32.5200, 32.5450,   -- Irbid (Downtown / University / Yarmouk / South / North)
        32.0728, 32.0500, 29.5321, 29.5200, 31.7167,   -- Zarqa / Rusaifa / Aqaba / Aqaba Beach / Madaba
        32.2714, 32.0392, 31.1756, 30.1928, 32.3428    -- Jerash / Salt / Karak / Ma'an / Mafraq
    ];
    lons NUMERIC[] := ARRAY[
        35.9106, 35.8803, 35.8947, 35.9267, 35.9381,
        35.8556, 35.8556, 35.8750, 35.9100, 36.0400,
        35.8500, 35.8572, 35.8600, 35.8450, 35.8650,
        36.0876, 36.0500, 35.0062, 35.0150, 35.8000,
        35.8967, 35.7283, 35.7053, 35.7345, 36.2080
    ];

    -- Status pattern (repeating block of 20)
    -- 8×PENDING  3×IN_PROGRESS  5×RESOLVED  3×REJECTED  1×UNASSESSED
    status_pat TEXT[] := ARRAY[
        'PENDING','PENDING','PENDING','PENDING','PENDING','PENDING','PENDING','PENDING',
        'IN_PROGRESS','IN_PROGRESS','IN_PROGRESS',
        'RESOLVED','RESOLVED','RESOLVED','RESOLVED','RESOLVED',
        'REJECTED','REJECTED','REJECTED',
        'UNASSESSED'
    ];

    -- Priority pattern (repeating block of 10)
    -- 3×LOW  4×MEDIUM  2×HIGH  1×CRITICAL
    pri_pat TEXT[] := ARRAY[
        'LOW','LOW','LOW','MEDIUM','MEDIUM','MEDIUM','MEDIUM','HIGH','HIGH','CRITICAL'
    ];

    cat        TEXT;
    stat       TEXT;
    pri        TEXT;
    r_priority TEXT;
    set_by     TEXT;
    still_v    INTEGER;
    fixed_v    INTEGER;
    score      NUMERIC;
    reason     TEXT;
    r_count    INTEGER;
    created_ts TIMESTAMP;
    resolved_ts TIMESTAMP;
BEGIN
    FOR i IN 1..200 LOOP

        -- UUID: a000000i-beef-4abc-8def-00000000000i  (valid hex UUID)
        uuid_str := 'a' || lpad(to_hex(i), 7, '0')
                    || '-beef-4abc-8def-'
                    || lpad(to_hex(i), 12, '0');

        cat  := cats        [((i - 1) % 7)  + 1];
        stat := status_pat  [((i - 1) % 20) + 1];
        pri  := pri_pat     [((i - 1) % 10) + 1];

        -- Spread creation dates: 2026-01-10 + 17 h per report  → ends ~2026-06-01
        created_ts  := '2026-01-10 08:00:00'::TIMESTAMP + ((i - 1) * INTERVAL '17 hours');
        resolved_ts := NULL;

        -- Per-status logic
        CASE stat
            WHEN 'PENDING' THEN
                still_v     := (i % 14) + 2;
                fixed_v     := i % 3;
                score       := ROUND((0.60 + (i % 36) * 0.01)::NUMERIC, 2);
                reason      := 'AI validated — awaiting city worker assignment';
                r_count     := 1 + (i % 2);
                r_priority  := pri;
                set_by      := CASE WHEN pri IN ('HIGH','CRITICAL') AND i % 3 = 0 THEN 'ADMIN' ELSE 'AI' END;

            WHEN 'IN_PROGRESS' THEN
                still_v     := (i % 20) + 10;
                fixed_v     := i % 5;
                score       := ROUND((0.80 + (i % 20) * 0.01)::NUMERIC, 2);
                reason      := 'High-confidence report — city workers dispatched';
                r_count     := 1 + (i % 3);
                r_priority  := pri;
                set_by      := CASE WHEN i % 2 = 0 THEN 'ADMIN' ELSE 'AI' END;

            WHEN 'RESOLVED' THEN
                still_v     := (i % 15) + 5;
                fixed_v     := (i % 10) + 5;
                score       := ROUND((0.75 + (i % 25) * 0.01)::NUMERIC, 2);
                reason      := 'Issue confirmed and resolved by maintenance crew';
                r_count     := 2 + (i % 2);
                resolved_ts := created_ts + INTERVAL '5 days';
                r_priority  := pri;
                set_by      := CASE WHEN i % 3 = 0 THEN 'ADMIN' ELSE 'AI' END;

            WHEN 'REJECTED' THEN
                still_v     := i % 6;
                fixed_v     := i % 8;
                score       := ROUND((0.20 + (i % 35) * 0.01)::NUMERIC, 2);
                reason      := 'Insufficient evidence or community support — auto-rejected';
                r_count     := i % 2;
                r_priority  := pri_pat[((i - 1) % 4) + 1];   -- only LOW / MEDIUM
                set_by      := 'AI';

            WHEN 'UNASSESSED' THEN
                still_v     := i % 4;
                fixed_v     := 0;
                score       := ROUND((0.10 + (i % 30) * 0.01)::NUMERIC, 2);
                reason      := 'Awaiting AI analysis';
                r_count     := 0;
                r_priority  := 'LOW';
                set_by      := 'AI';
        END CASE;

        INSERT INTO report (
            report_id, user_id, description, sub_problem, note,
            lat, lon, category, status, priority, priority_set_by,
            created_at, resolved_at, unassessed_at,
            still_votes, fixed_votes,
            validation_score, validation_reason, revalidation_count
        ) VALUES (
            uuid_str,
            user_ids[((i - 1) / 50) + 1],

            -- Description (category + row variant)
            CASE cat
                WHEN 'pothole' THEN CASE (i % 8)
                    WHEN 0 THEN 'Large pothole causing vehicle damage near traffic signal'
                    WHEN 1 THEN 'Deep pothole after recent road construction work'
                    WHEN 2 THEN 'Multiple potholes forming dangerous cluster in area'
                    WHEN 3 THEN 'Pothole expanding after heavy rainfall blocking right lane'
                    WHEN 4 THEN 'Severe pothole damaging vehicle tires and suspensions'
                    WHEN 5 THEN 'Pothole near school entrance creating daily hazard'
                    WHEN 6 THEN 'Road pothole partially blocking emergency vehicle access'
                    ELSE        'Wide pothole at intersection causing traffic disruption'
                END
                WHEN 'brokenRoad' THEN CASE (i % 8)
                    WHEN 0 THEN 'Severe road cracks and surface deterioration affecting traffic'
                    WHEN 1 THEN 'Road subsidence creating dangerous raised bump section'
                    WHEN 2 THEN 'Road surface peeling and crumbling after winter season'
                    WHEN 3 THEN 'Broken asphalt from utility excavation left unrepaired'
                    WHEN 4 THEN 'Road damage from heavy truck traffic needing urgent repair'
                    WHEN 5 THEN 'Large crack splitting road lane into hazardous sections'
                    WHEN 6 THEN 'Crumbling road edges creating safety hazard for cyclists'
                    ELSE        'Road surface deterioration severely affecting daily traffic flow'
                END
                WHEN 'manhole' THEN CASE (i % 8)
                    WHEN 0 THEN 'Open manhole without warning signs or protective cover'
                    WHEN 1 THEN 'Broken manhole cover creating dangerous road hazard'
                    WHEN 2 THEN 'Missing manhole lid dangerous for pedestrians at night'
                    WHEN 3 THEN 'Raised manhole cover causing vehicle suspension damage'
                    WHEN 4 THEN 'Sunken manhole collecting water and creating pool hazard'
                    WHEN 5 THEN 'Cracked manhole cover about to collapse under traffic load'
                    WHEN 6 THEN 'Open drainage manhole near school entrance'
                    ELSE        'Loose manhole cover making dangerous noise and road hazard'
                END
                WHEN 'lamppost' THEN CASE (i % 8)
                    WHEN 0 THEN 'Street light completely non-functional causing unsafe dark road'
                    WHEN 1 THEN 'Broken lamppost leaning dangerously toward traffic lane'
                    WHEN 2 THEN 'Multiple street lights out creating unsafe area at night'
                    WHEN 3 THEN 'Lamppost damaged by vehicle collision blocking pedestrian path'
                    WHEN 4 THEN 'Flickering street light causing distraction to drivers'
                    WHEN 5 THEN 'Exposed lamppost electrical wires dangerous to public'
                    WHEN 6 THEN 'Corroded lamppost pole structurally unstable and dangerous'
                    ELSE        'Street light out at pedestrian crossing creating danger'
                END
                WHEN 'speedBump' THEN CASE (i % 8)
                    WHEN 0 THEN 'Speed bump completely unmarked and invisible at night'
                    WHEN 1 THEN 'Damaged speed bump with sharp exposed metal edges'
                    WHEN 2 THEN 'Speed bump paint completely faded and invisible to drivers'
                    WHEN 3 THEN 'Unauthorized speed bump causing unnecessary traffic issues'
                    WHEN 4 THEN 'Speed bump too high causing vehicle underside damage'
                    WHEN 5 THEN 'Broken speed bump section missing creating road hazard'
                    WHEN 6 THEN 'Speed bump road markings completely worn away'
                    ELSE        'Incorrectly installed speed bump causing vehicle accidents'
                END
                WHEN 'treeInRoad' THEN CASE (i % 8)
                    WHEN 0 THEN 'Large tree fallen blocking entire road after heavy storm'
                    WHEN 1 THEN 'Overhanging tree branches blocking traffic and road signs'
                    WHEN 2 THEN 'Tree roots lifting and cracking road surface severely'
                    WHEN 3 THEN 'Fallen tree blocking main street needs urgent removal'
                    WHEN 4 THEN 'Dead tree leaning dangerously over busy road'
                    WHEN 5 THEN 'Tree branches fallen blocking pedestrian pathway'
                    WHEN 6 THEN 'Tree growing into road reducing lane width significantly'
                    ELSE        'Uprooted tree blocking road after heavy rain and wind'
                END
                ELSE CASE (i % 8)    -- unpavedStreet
                    WHEN 0 THEN 'Unpaved dirt road causing severe dust and health issues'
                    WHEN 1 THEN 'Gravel road flooding and becoming impassable during rain'
                    WHEN 2 THEN 'Unpaved road creating dangerous mud conditions in winter'
                    WHEN 3 THEN 'Dirt road with large rocks causing daily vehicle damage'
                    WHEN 4 THEN 'Unpaved residential street urgently needs paving'
                    WHEN 5 THEN 'Deteriorating gravel path with deep uneven surface'
                    WHEN 6 THEN 'Dirt road with large holes affecting daily commuters'
                    ELSE        'Unpaved street causing flooding in nearby properties'
                END
            END,

            NULL,           -- sub_problem
            NULL,           -- note
            lats[((i - 1) % 25) + 1],
            lons[((i - 1) % 25) + 1],
            cat,
            stat,
            r_priority,
            set_by,
            created_ts,
            resolved_ts,
            created_ts,     -- unassessed_at = created_at
            still_v,
            fixed_v,
            score,
            reason,
            r_count
        )
        ON CONFLICT (report_id) DO NOTHING;

    END LOOP;

    RAISE NOTICE '200 reports seeded successfully.';
END $$;
