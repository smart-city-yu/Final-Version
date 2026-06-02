-- Seed: reports, report_h3, h3_token_agg
-- User 19: wadea  (wadiezwr@gmail.com)
-- User 20: omarkurde (omarkurde919@gmail.com)

BEGIN;

-- ============================================================
-- 1. report
-- ============================================================
INSERT INTO report (report_id, user_id, description, sub_problem, note, lat, lon,
                    category, status, priority, priority_set_by,
                    created_at, resolved_at, unassessed_at,
                    still_votes, fixed_votes,
                    validation_score, validation_reason, revalidation_count)
VALUES
  -- ---- User 19 (wadea) ----
  ('18677a7f-df4e-4b2b-92e8-ba704de81e9b', 19, 'Open manhole without warning signs',
   NULL, NULL, 32.5317, 35.855, 'manhole', 'PENDING', 'CRITICAL', 'ADMIN',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   25, 0, 0.99, 'Dangerous infrastructure issue', 2),

  ('37d52870-e326-422c-b084-a200c54825b2', 19, 'Unpaved street causing excessive dust and vehicle issues',
   NULL, NULL, 32.5333, 35.8499, 'unpavedStreet', 'PENDING', 'MEDIUM', 'AI',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   9, 0, 0.8, 'Street condition appears valid', 0),

  ('3ad7c3f4-e960-4333-a57c-82770ae64c2d', 19, 'Large pothole near university entrance causing traffic slowdown',
   NULL, NULL, 32.5356, 35.8572, 'pothole', 'PENDING', 'HIGH', 'AI',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   12, 1, 0.91, 'Multiple users confirmed the pothole', 0),

  ('5efca3f9-7315-4530-98b4-5d076c96cc1d', 19, 'Deep pothole damaging vehicle tires',
   NULL, NULL, 32.536, 35.8588, 'pothole', 'IN_PROGRESS', 'HIGH', 'ADMIN',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   30, 1, 0.97, 'High confidence report', 3),

  ('9f2e910f-0848-4296-9388-cae488e6c6e2', 19, 'Large pothole near university entrance causing traffic slowdown',
   NULL, NULL, 32.5356, 35.8572, 'pothole', 'PENDING', 'HIGH', 'AI',
   '2026-05-18 03:53:21.656773', NULL, '2026-05-18 03:53:21.656773',
   12, 1, 0.91, 'Multiple users confirmed the pothole', 0),

  -- ---- User 20 (omarkurde) ----
  ('5ed5ac23-3535-4692-84e9-4a6b9f941817', 20, 'Large tree branches obstructing road visibility',
   NULL, NULL, 32.5348, 35.8563, 'treeInRoad', 'REJECTED', 'LOW', 'ADMIN',
   '2026-05-15 03:44:20.454669', NULL, '2026-05-15 03:44:20.454669',
   1, 8, 0.32, 'Insufficient supporting evidence', 1),

  ('a09b2c4a-6ef8-4699-a560-8dedfb2b3245', 20, 'Tree fallen into the road blocking one lane',
   NULL, NULL, 32.5402, 35.8615, 'treeInRoad', 'IN_PROGRESS', 'HIGH', 'ADMIN',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   18, 2, 0.95, 'Obstacle confirmed by multiple reports', 1),

  ('ac036b29-e0f9-455d-8f49-41fcd655997e', 20, 'Lamppost not functioning during nighttime',
   NULL, NULL, 32.5285, 35.86, 'lamppost', 'RESOLVED', 'LOW', 'ADMIN',
   '2026-05-11 03:44:20.454669', '2026-05-16 03:44:20.454669', '2026-05-11 03:44:20.454669',
   7, 10, 0.72, 'Issue resolved by maintenance team', 1),

  ('b2cf0a8c-18c0-4ce6-9f2f-7871da495c89', 20, 'Broken road section with visible cracks and damage',
   NULL, NULL, 32.5291, 35.851, 'brokenRoad', 'REJECTED', 'MEDIUM', 'AI',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   5, 0, 0.77, 'Closed — not enough community confirmation within 48 hours', 0),

  ('eb90721f-92aa-41a0-8c18-3cabddd6b413', 20, 'Speed bump paint faded and difficult to notice',
   NULL, NULL, 32.5377, 35.8524, 'speedBump', 'REJECTED', 'LOW', 'AI',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   3, 0, 0.61, 'Closed — not enough community confirmation within 48 hours', 0),

  ('ff44af90-cc64-467d-8811-0bbc66a80e69', 20, 'Broken road near traffic light intersection',
   NULL, NULL, 32.532, 35.854, 'brokenRoad', 'PENDING', 'MEDIUM', 'AI',
   '2026-05-18 03:44:20.454669', NULL, '2026-05-18 03:44:20.454669',
   11, 0, 0.84, 'Road surface damage detected', 0)

ON CONFLICT (report_id) DO NOTHING;

-- ============================================================
-- 2. report_h3  (id is sequence-generated — not specified)
-- ============================================================
INSERT INTO report_h3 (id, h3token, rep_id)
SELECT nextval('report_h3_seq'), v.token, v.rid
FROM (VALUES
  (581769194442326015::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (586272244313882623::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (590775569063346175::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (595279142920912895::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (599782740400799743::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (604286339222863871::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (608789938833457151::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (613293538448244735::bigint, '3ad7c3f4-e960-4333-a57c-82770ae64c2d'),
  (581769194442326015::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (586272244313882623::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (590775569063346175::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (595279142920912895::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (599782740400799743::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (604286339222863871::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (608789938833457151::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (613293538446147583::bigint, 'b2cf0a8c-18c0-4ce6-9f2f-7871da495c89'),
  (581769194442326015::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (586272244313882623::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (590775569063346175::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (595279142920912895::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (599782740400799743::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (604286339222863871::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (608789938732793855::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (613293538358067199::bigint, 'a09b2c4a-6ef8-4699-a560-8dedfb2b3245'),
  (581769194442326015::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (586272244313882623::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (590775569063346175::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (595279142920912895::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (599782740400799743::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (604286339222863871::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (608789938833457151::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (613293538456633343::bigint, '37d52870-e326-422c-b084-a200c54825b2'),
  (581769194442326015::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (586272244313882623::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (590775569063346175::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (595279142920912895::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (599782740400799743::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (604286339222863871::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (608789938833457151::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (613293538448244735::bigint, '18677a7f-df4e-4b2b-92e8-ba704de81e9b'),
  (581769194442326015::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (586272244313882623::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (590775569063346175::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (595279142920912895::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (599782740400799743::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (604286339222863871::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (608789938833457151::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (613293538448244735::bigint, 'ac036b29-e0f9-455d-8f49-41fcd655997e'),
  (581769194442326015::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (586272244313882623::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (590775569063346175::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (595279142920912895::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (599782740400799743::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (604286339222863871::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (608789938833457151::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (613293538456633343::bigint, 'eb90721f-92aa-41a0-8c18-3cabddd6b413'),
  (581769194442326015::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (586272244313882623::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (590775569063346175::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (595279142920912895::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (599782740400799743::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (604286339222863871::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (608789938732793855::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (613293538448244735::bigint, '5efca3f9-7315-4530-98b4-5d076c96cc1d'),
  (581769194442326015::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (586272244313882623::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (590775569063346175::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (595279142920912895::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (599782740400799743::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (604286339222863871::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (608789938833457151::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (613293538448244735::bigint, 'ff44af90-cc64-467d-8811-0bbc66a80e69'),
  (581769194442326015::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (586272244313882623::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (590775569063346175::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (595279142920912895::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (599782740400799743::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (604286339222863871::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (608789938833457151::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (613293538448244735::bigint, '5ed5ac23-3535-4692-84e9-4a6b9f941817'),
  (581769194442326015::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (586272244313882623::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (590775569063346175::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (595279142920912895::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (599782740400799743::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (604286339222863871::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (608789938833457151::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2'),
  (613293538448244735::bigint, '9f2e910f-0848-4296-9388-cae488e6c6e2')
) AS v(token, rid)
WHERE NOT EXISTS (
  SELECT 1 FROM report_h3 rh WHERE rh.h3token = v.token AND rh.rep_id = v.rid
);

-- ============================================================
-- 3. h3_token_agg
-- ============================================================
INSERT INTO h3_token_agg (h3token_id, count, x, y, z)
VALUES
  (581769194442326015, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (586272244313882623, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (590775569063346175, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (595279142920912895, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (599782740400799743, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (604286339222863871, 11, 7.516354994564695,  5.432092717230683, 5.915807261899999),
  (608789938732793855,  2, 1.3664725396175308, 0.9877134696830567, 1.075720639072331),
  (608789938833457151,  9, 6.149882454947165,  4.444379247547626,  4.840086622827667),
  (613293538358067199,  1, 0.6832086567023841, 0.4938612848100625, 0.5378912183450092),
  (613293538446147583,  1, 0.6833836010417828, 0.4937970943239969, 0.5377278897958923),
  (613293538448244735,  7, 4.7830954995592405, 3.4569069367821554, 3.7645440272009068),
  (613293538456633343,  2, 1.3666672372612894, 0.9875274013144677, 1.0756441265581906)
ON CONFLICT (h3token_id) DO NOTHING;

COMMIT;
