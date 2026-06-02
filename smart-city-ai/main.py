"""
SmartCity AI Service — RoadNa report validator.

Pipeline:
    /detect   (Nemotron)        →  structured visual evidence
    /analyze  (Pass A + Pass C + Calibrator)
              →  final verdict with deterministic, explainable confidence

Confidence is NOT taken directly from the LLM. The LLM produces qualitative
signals (plausibility, severity, agreement, category match), and a
deterministic calibrator combines them with image evidence, community votes,
and category floors to compute the final 0.0–1.0 score the backend persists.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import re
import time
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from openai import OpenAI
from pydantic import BaseModel, Field

# ───────────────────────────────────────────────────────────────────────────
# Logging
# ───────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("smartcity-ai")

# ───────────────────────────────────────────────────────────────────────────
# Config
# ───────────────────────────────────────────────────────────────────────────
load_dotenv()

NVIDIA_API_KEY     = os.getenv("NVIDIA_API_KEY", "")
NVIDIA_BASE_URL    = os.getenv("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1")
NVIDIA_TEXT_MODEL  = os.getenv("NVIDIA_TEXT_MODEL", "meta/llama-3.1-8b-instruct")
NVIDIA_IMAGE_MODEL = os.getenv(
    "NVIDIA_IMAGE_MODEL",
    os.getenv("NVIDIA_MODEL", "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"),
)

MAX_IMAGES                 = 5
IMAGE_DOWNLOAD_TIMEOUT_SEC = 15
TEXT_LLM_TIMEOUT_SEC       = 30
TEXT_PASS_MAX_TOKENS       = 260
VERDICT_PASS_MAX_TOKENS    = 260

# ───────────────────────────────────────────────────────────────────────────
# Clients
# ───────────────────────────────────────────────────────────────────────────
app = FastAPI(title="SmartCity AI Service", version="2.1.0")

nvidia_client: OpenAI | None = None
if NVIDIA_API_KEY:
    nvidia_client = OpenAI(
        base_url=NVIDIA_BASE_URL,
        api_key=NVIDIA_API_KEY,
        timeout=TEXT_LLM_TIMEOUT_SEC,
    )
    log.info("NVIDIA client ready — text=%s | image=%s", NVIDIA_TEXT_MODEL, NVIDIA_IMAGE_MODEL)
else:
    log.warning("NVIDIA_API_KEY is not set — /analyze and /detect will be unavailable.")


# ───────────────────────────────────────────────────────────────────────────
# Domain constants
# ───────────────────────────────────────────────────────────────────────────
VISIBLE_CATEGORIES = {
    "pothole", "manhole", "lamppost", "speedBump",
    "treeInRoad", "brokenRoad", "unpavedStreet",
}
ALL_CATEGORIES = VISIBLE_CATEGORIES | {"other"}

CATEGORY_LABELS = {
    "pothole":       "a pothole or hole in the road surface",
    "brokenRoad":    "broken, cracked, or damaged road surface",
    "treeInRoad":    "a fallen tree or large branch blocking the road",
    "unpavedStreet": "an unpaved, dirt, or gravel street that should be paved",
    "manhole":       "an open, broken, or raised manhole cover",
    "lamppost":      "a damaged, fallen, or non-working street lamp or lamppost",
    "speedBump":     "a damaged, missing, or unmarked speed bump",
    "other":         "an unspecified road or street infrastructure issue",
}

SEVERITY_RANK    = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
PRIORITY_VALUES  = {"LOW", "MEDIUM", "HIGH", "CRITICAL"}

# Categories that, by their nature, typically warrant at least these priorities
CATEGORY_FLOOR_PRIORITY = {
    "treeInRoad":    "HIGH",
    "manhole":       "HIGH",
    "brokenRoad":    "MEDIUM",
    "pothole":       "MEDIUM",
    "lamppost":      "MEDIUM",
    "speedBump":     "LOW",
    "unpavedStreet": "LOW",
    "other":         "LOW",
}

# Minimum priority floor based on OSM highway classification.
# Only defined for road types where the classification meaningfully raises the bar.
# Lower-traffic roads (residential, service, track) fall back to the category floor.
HIGHWAY_PRIORITY_FLOOR = {
    "motorway":       "HIGH",
    "trunk":          "HIGH",
    "primary":        "MEDIUM",
    "secondary":      "MEDIUM",
    "motorway_link":  "HIGH",
    "trunk_link":     "HIGH",
    "primary_link":   "MEDIUM",
    "secondary_link": "MEDIUM",
}

# Keywords that, when central to the image description, strongly suggest
# a non-road or off-topic scene (e.g. selfies, indoor shots, food photos)
NON_ROAD_KEYWORDS = {
    "headphones", "mouse", "keyboard", "laptop", "computer", "monitor",
    "phone", "smartphone", "tablet", "food", "plate", "cup", "bottle",
    "selfie", "face", "person", "people", "cat", "dog", "animal",
    "bedroom", "kitchen", "bathroom", "living room", "ceiling", "sofa",
    "couch", "bed", "pillow", "carpet", "rug", "wooden surface",
    "table", "chair", "desk", "shelf", "indoor", "inside",
    "screenshot", "screen", "display",
}


# ───────────────────────────────────────────────────────────────────────────
# Request / Response models
# ───────────────────────────────────────────────────────────────────────────
class AnalyzeRequest(BaseModel):
    category:            str
    sub_problem:         str | None = None
    description:         str | None = None
    lat:                 float
    lon:                 float
    still_votes:         int  = 0
    is_predefined:       bool = False
    # Populated by /detect before calling /analyze
    image_description:   str | None = None
    image_count:         int  = 1
    nemotron_detected:   bool = False
    nemotron_category:   str  = "other"
    nemotron_confidence: float = 0.0
    nemotron_severity:   str | None = None
    nemotron_scene_type: str | None = None
    # OSM way-tag context (populated by the Java backend from report.metadata)
    highway:             str | None = None
    maxspeed:            str | None = None
    lanes:               str | None = None
    road_name:           str | None = None


class AnalyzeResponse(BaseModel):
    valid:             bool
    confidence:        float
    reason:            str
    priority:          str
    agreement:         str | None = None
    severity:          str | None = None
    text_plausibility: float | None = None


class DetectRequest(BaseModel):
    image_urls: list[str] = Field(default_factory=list)


class DetectResponse(BaseModel):
    detected:          bool
    category:          str
    confidence:        float
    image_description: str = ""
    severity:          str = "MEDIUM"
    scene_type:        str = "UNCLEAR"


# ───────────────────────────────────────────────────────────────────────────
# JSON extraction — robust against fenced code blocks, prefixes, trailing prose
# ───────────────────────────────────────────────────────────────────────────
def extract_json(raw: str) -> dict:
    """Best-effort JSON extraction from a noisy LLM string."""
    if not raw:
        raise ValueError("empty model output")

    text = raw.strip()

    # Strip markdown code fences
    if text.startswith("```"):
        parts = text.split("```")
        if len(parts) >= 2:
            text = parts[1]
            if text.lstrip().lower().startswith("json"):
                text = text.lstrip()[4:]
            text = text.strip()

    # Find outermost { ... }
    start = text.find("{")
    end   = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError(f"no JSON object found in model output: {raw[:200]}")

    candidate = text[start:end + 1]

    # First attempt — strict parse
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        pass

    # Cleanup: remove trailing commas, fix smart quotes
    cleaned = re.sub(r",\s*([}\]])", r"\1", candidate)
    cleaned = (cleaned
               .replace("“", '"').replace("”", '"')
               .replace("‘", "'").replace("’", "'"))
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(f"JSON parse failed after cleanup: {e}; raw={raw[:200]}")


def _clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, v))


def _normalize_severity(value: Any, default: str = "MEDIUM") -> str:
    if not isinstance(value, str):
        return default
    v = value.strip().upper()
    return v if v in PRIORITY_VALUES else default


# ───────────────────────────────────────────────────────────────────────────
# PROMPTS
# ───────────────────────────────────────────────────────────────────────────
def _build_road_context_block(
    highway: str | None,
    maxspeed: str | None,
    lanes: str | None,
    road_name: str | None,
) -> str:
    """Formats OSM way-tag context for injection into LLM prompts."""
    parts = []
    if road_name:
        parts.append(f"  Road name  : {road_name}")
    if highway:
        parts.append(f"  Road type  : {highway}")
    if maxspeed:
        parts.append(f"  Speed limit: {maxspeed}")
    if lanes:
        parts.append(f"  Lanes      : {lanes}")
    if not parts:
        return ""
    return (
        "ROAD CONTEXT (OpenStreetMap)\n"
        "─────────────────────────────────────────────\n"
        + "\n".join(parts) + "\n"
        "─────────────────────────────────────────────"
    )


def build_text_pass_prompt(
    category: str,
    sub_problem: str | None,
    description: str | None,
    still_votes: int,
    is_predefined: bool,
    highway: str | None = None,
    maxspeed: str | None = None,
    lanes: str | None = None,
    road_name: str | None = None,
) -> str:
    """Pass A — text-only structured analysis (no image context)."""
    cat_label = CATEGORY_LABELS.get(category, category)

    if is_predefined and sub_problem:
        report_block = (
            f"  Form type   : Dropdown (predefined option)\n"
            f"  Selected    : {sub_problem}"
        )
    elif description:
        report_block = (
            f"  Form type   : Free-text\n"
            f"  Description : \"{description.strip()}\""
        )
    else:
        report_block = "  Form type   : Category-only (no extra detail)"

    vote_line = f"  Community confirmations (still-votes): {still_votes}"

    road_block   = _build_road_context_block(highway, maxspeed, lanes, road_name)
    road_section = f"\n{road_block}\n" if road_block else ""

    if highway in ("motorway", "trunk", "motorway_link", "trunk_link"):
        highway_severity_note = (
            "\n   Road-type modifier — this is a high-speed, high-traffic road:\n"
            f"     \"{highway}\" → any notable hazard is at least HIGH severity"
        )
    elif highway in ("primary", "secondary", "primary_link", "secondary_link"):
        highway_severity_note = (
            "\n   Road-type modifier — this is a major road:\n"
            f"     \"{highway}\" → confirmed infrastructure damage is at least MEDIUM severity"
        )
    else:
        highway_severity_note = ""

    return f"""You are a road infrastructure analyst.
Evaluate the TEXT EVIDENCE of a citizen road report. You CANNOT see any photo
in this step — reason purely from what the citizen wrote.

CITIZEN REPORT
─────────────────────────────────────────────
  Selected category : {category} — {cat_label}
{report_block}
{vote_line}
─────────────────────────────────────────────
{road_section}
Score the report on four dimensions:

1. plausibility (0.0–1.0)
   How likely is this a real, actionable road issue?
     0.00–0.20 → clearly spam, off-topic, nonsense, or abusive
     0.20–0.45 → vague, contradictory, very low information
     0.45–0.70 → plausible but unverified, average information
     0.70–0.90 → coherent, specific, sounds like a genuine report
     0.90–1.00 → highly specific with concrete details (size, location, hazard type)

2. category_match — does the wording fit the selected category?
   "STRONG"   → wording clearly matches the category
   "WEAK"     → wording loosely matches, ambiguous
   "MISMATCH" → wording describes a different kind of issue than the selected category
   "UNCLEAR"  → not enough wording to tell (e.g. dropdown without text)

3. severity (LOW | MEDIUM | HIGH | CRITICAL)
   Severity implied by the wording and road context:{highway_severity_note}
     CRITICAL → immediate danger (sinkhole, collapse, blocking, open manhole in lane, exposed wires)
     HIGH     → serious hazard (large/deep damage, fallen tree, broken infrastructure)
     MEDIUM   → clear damage needing repair (cracked road, raised manhole, broken lamppost)
     LOW      → minor issue (small crack, faded markings, light wear)

4. concerns — list short tags of any red flags (e.g. "very_short", "contradicts_category",
   "off_topic", "no_detail"). Empty list if none.

Reply with ONLY this JSON, no other text:
{{"plausibility": 0.78, "category_match": "STRONG", "severity": "MEDIUM", "concerns": [], "reasoning": "1–2 short sentences."}}

Now respond for the report above."""


def build_verdict_pass_prompt(
    category: str,
    text_analysis: dict,
    image_block: str,
    still_votes: int,
    highway: str | None = None,
    maxspeed: str | None = None,
    lanes: str | None = None,
    road_name: str | None = None,
) -> str:
    """Pass C — qualitative verdict (priority + agreement). Confidence is NOT asked of the LLM."""
    text_block = (
        f"  plausibility    : {text_analysis.get('plausibility', 0.5):.2f}\n"
        f"  category_match  : {text_analysis.get('category_match', 'UNCLEAR')}\n"
        f"  severity        : {text_analysis.get('severity', 'MEDIUM')}\n"
        f"  concerns        : {text_analysis.get('concerns', []) or 'none'}\n"
        f"  reasoning       : {text_analysis.get('reasoning', '').strip()}"
    )

    road_block   = _build_road_context_block(highway, maxspeed, lanes, road_name)
    road_section = f"\n{road_block}\n" if road_block else ""

    if highway in ("motorway", "trunk", "motorway_link", "trunk_link"):
        highway_priority_note = (
            f"\n   Road-type override: this report is on a \"{highway}\" — a high-speed, high-traffic road.\n"
            "   Elevate priority one level above what the issue alone would warrant (MEDIUM → HIGH, HIGH → CRITICAL)."
        )
    elif highway in ("primary", "secondary", "primary_link", "secondary_link"):
        highway_priority_note = (
            f"\n   Road-type note: this report is on a \"{highway}\" — a main road with significant traffic.\n"
            "   Prefer MEDIUM or above for any confirmed infrastructure issue."
        )
    else:
        highway_priority_note = ""

    return f"""You are the FINAL validator for a smart city road report.
You have two independent analyses below. Decide whether the report is valid
and what priority it should receive. Do NOT output a confidence score — the
system computes confidence deterministically from your signals.

CITIZEN CHOICE
  Selected category : {category} — {CATEGORY_LABELS.get(category, category)}
  Still-votes from community: {still_votes}
{road_section}
TEXT ANALYSIS (Pass A — citizen text only)
─────────────────────────────────────────────
{text_block}
─────────────────────────────────────────────

{image_block}

DECISION RULES
A. "valid": true if the report describes a real, actionable road issue worth
   passing on to city workers — even if the user picked the wrong category.
   "valid": false ONLY if it is spam / nonsense / off-topic / impossible to act on.

B. "agreement" — overall coherence between text and image evidence:
   STRONG    → text plausibility ≥ 0.65 AND image shows same category
   PARTIAL   → text plausibility ≥ 0.65 AND image shows a DIFFERENT real road issue
   WEAK      → text plausibility ≥ 0.5 AND image is unclear / no issue detected
   CONFLICT  → text describes a road issue but image clearly shows NON_ROAD scene
   NO_IMAGE  → no photo was submitted; verdict relies on text only

C. "priority" — severity of the issue if valid:{highway_priority_note}
   CRITICAL → immediate danger to drivers/pedestrians
              (sinkhole, collapsed road, open manhole in traffic, total blockage, exposed live wires)
   HIGH     → serious hazard
              (large pothole, fallen tree partially blocking lane, broken signage in lane)
   MEDIUM   → clear damage needing repair
              (raised manhole, broken lamppost, cracked road surface, damaged speed bump)
   LOW      → minor wear
              (small crack, faded markings, minor unpaved patch)
   If valid is false, set priority to "LOW".

D. "reason" — ONE or TWO sentences explaining the verdict and citing the
   strongest piece of evidence (text or image). No filler.

Reply with ONLY this JSON, no other text:
{{"valid": true, "agreement": "STRONG", "priority": "HIGH", "reason": "..."}}

Now respond for the report above."""


def build_image_block_for_verdict(
    image_description: str | None,
    nemotron_detected: bool,
    nemotron_category: str,
    nemotron_confidence: float,
    nemotron_severity: str | None,
    nemotron_scene_type: str | None,
    image_count: int,
) -> str:
    if not image_description or not image_description.strip():
        return (
            "IMAGE ANALYSIS\n"
            "─────────────────────────────────────────────\n"
            "  No photo was submitted.\n"
            "─────────────────────────────────────────────"
        )

    photo_word    = f"{image_count} photo{'s' if image_count > 1 else ''}"
    detected_line = (
        f"detected         : YES — {nemotron_category} (model confidence {nemotron_confidence:.0%})"
        if nemotron_detected else
        "detected         : NO — no road issue identified"
    )

    lines = [
        f"IMAGE ANALYSIS (Pass B — Nemotron examined {photo_word}, no text seen)",
        "─────────────────────────────────────────────",
        f"  {detected_line}",
    ]
    if nemotron_severity:   lines.append(f"  image_severity   : {nemotron_severity}")
    if nemotron_scene_type: lines.append(f"  scene_type       : {nemotron_scene_type}")
    lines.append(f"  visual_reasoning : {image_description.strip()}")
    lines.append("─────────────────────────────────────────────")
    return "\n".join(lines)


def build_detect_prompt(image_count: int) -> str:
    if image_count == 1:
        photo_ref = "this road photo"
        opener    = "Examine the photo carefully."
    else:
        photo_ref = f"these {image_count} photos of the same report"
        opener    = f"You are given {image_count} photos of the same citizen report. Examine all of them together."

    categories_list = (
        "  - pothole         hole or depression in the road surface\n"
        "  - brokenRoad      cracked, broken, or damaged road surface (not a single hole)\n"
        "  - treeInRoad      fallen tree or large branch on/over the road\n"
        "  - unpavedStreet   unpaved dirt/gravel street that should be paved\n"
        "  - manhole         open, broken, raised, or sunken manhole cover\n"
        "  - lamppost        damaged, fallen, or broken street lamp / pole\n"
        "  - speedBump       damaged, missing, or unmarked speed bump"
    )

    return f"""You are a road infrastructure visual analyst. {opener}

TASK 1 — Scene check
  Decide what the photo actually shows:
    "ROAD"     → a road / street / sidewalk / road-side infrastructure is clearly visible
    "ADJACENT" → mostly off-road (yard, building) but some road context is present
    "NON_ROAD" → not a road context at all (interior, face, food, animals, screenshots, etc.)
    "UNCLEAR"  → too blurry / dark / cropped / abstract to tell

TASK 2 — Issue detection
  Identify if any of these road issues is clearly visible in {photo_ref}:
{categories_list}
  If NO road issue is visible, set "detected": false and "category": "other".

TASK 3 — Severity (only if detected)
  Rate severity:
    "CRITICAL" → immediate danger to drivers/pedestrians (deep hole in lane, blocked road, exposed wires, open manhole in traffic)
    "HIGH"     → serious hazard (large pothole, fallen tree partially blocking, broken signage)
    "MEDIUM"   → clear damage, repair needed (raised manhole, broken lamppost, cracked road)
    "LOW"      → minor wear (small crack, faded markings)
  If not detected, use "LOW".

TASK 4 — Description
  ONE concrete sentence (max 30 words) describing what is actually visible.
  Mention road condition, damage type, approximate size, and severity if applicable.

Reply with ONLY this JSON, nothing else:
{{"detected": true, "category": "pothole", "confidence": 0.87, "severity": "HIGH", "scene_type": "ROAD", "image_description": "A large pothole roughly 50cm wide is visible in the center lane with deep damage and jagged edges exposing the road base."}}

If no road issue is visible:
{{"detected": false, "category": "other", "confidence": 0.0, "severity": "LOW", "scene_type": "NON_ROAD", "image_description": "The image shows an indoor scene unrelated to any road."}}"""


# ───────────────────────────────────────────────────────────────────────────
# Deterministic confidence calibrator
# ───────────────────────────────────────────────────────────────────────────
def calibrate_confidence(
    *,
    text_plausibility: float,
    text_category_match: str,
    agreement: str,
    is_predefined: bool,
    still_votes: int,
    valid: bool,
    nemotron_scene_type: str | None,
) -> float:
    """
    Combine all signals into a single calibrated 0.0–1.0 confidence score.

    Base is anchored on text plausibility so one noisy LLM call cannot push
    us to extremes alone. Each subsequent signal adjusts up or down.
    """
    base = 0.30 + 0.50 * _clamp(text_plausibility)

    # Image agreement adjustment
    base += {
        "STRONG":   +0.18,
        "PARTIAL":  +0.04,
        "WEAK":     -0.06,
        "CONFLICT": -0.22,
        "NO_IMAGE": -0.08,
    }.get(agreement, -0.04)

    # Scene-type penalty — a definitively NON_ROAD photo is a strong negative signal
    if nemotron_scene_type == "NON_ROAD":
        base -= 0.12

    # Community votes — diminishing returns, capped at +0.18
    if still_votes > 0:
        base += min(0.18, 0.04 * min(still_votes, 6) + 0.01 * max(0, still_votes - 6))

    # Predefined-dropdown bonus — a category selection is a stronger commitment than typed text
    if is_predefined:
        base += 0.03

    # Category-match adjustment from Pass A
    base += {"STRONG": +0.03, "MISMATCH": -0.10}.get(text_category_match, 0.0)

    # Invalid floor — invalid reports must never carry high confidence
    if not valid:
        base = min(base, 0.22)

    return round(_clamp(base, 0.02, 0.97), 3)


def compute_priority(
    *,
    valid: bool,
    llm_priority: str,
    text_severity: str,
    image_severity: str | None,
    category: str,
    highway: str | None = None,
) -> str:
    """
    Combine five severity signals into a final priority.
    Takes the MAX of LLM verdict, text severity, image severity, category floor, and highway floor.
    Invalid reports collapse to LOW.
    """
    if not valid:
        return "LOW"

    def rank(p: str | None) -> int:
        return SEVERITY_RANK.get((p or "").upper(), 0)

    category_floor = CATEGORY_FLOOR_PRIORITY.get(category, "LOW")
    highway_floor  = HIGHWAY_PRIORITY_FLOOR.get((highway or "").lower())

    best = max(
        rank(llm_priority),
        rank(text_severity),
        rank(image_severity),
        rank(category_floor),
        rank(highway_floor) if highway_floor else 0,
    )

    for name, value in SEVERITY_RANK.items():
        if value == best:
            return name
    return "MEDIUM"


# ───────────────────────────────────────────────────────────────────────────
# LLM helper
# ───────────────────────────────────────────────────────────────────────────
def run_text_llm(prompt: str, temperature: float, max_tokens: int, top_p: float = 0.8) -> str:
    """Call the NVIDIA-hosted Llama 3.1 8B text LLM and return the raw response string."""
    if nvidia_client is None:
        raise RuntimeError("NVIDIA_API_KEY not set — text LLM unavailable.")

    completion = nvidia_client.chat.completions.create(
        model       = NVIDIA_TEXT_MODEL,
        messages    = [{"role": "user", "content": prompt}],
        temperature = temperature,
        top_p       = top_p,
        max_tokens  = max_tokens,
        stream      = True,
    )

    raw = ""
    for chunk in completion:
        if chunk.choices and chunk.choices[0].delta.content:
            raw += chunk.choices[0].delta.content
    return raw.strip()


# ───────────────────────────────────────────────────────────────────────────
# /analyze — full pipeline
# ───────────────────────────────────────────────────────────────────────────
@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest) -> AnalyzeResponse:
    started = time.perf_counter()
    log.info(
        "ANALYZE start: category=%s predefined=%s sub_problem=%r votes=%s "
        "img_count=%s nemotron(detected=%s, cat=%s, conf=%.2f) "
        "highway=%s maxspeed=%s lanes=%s road_name=%r",
        req.category, req.is_predefined, req.sub_problem, req.still_votes,
        req.image_count, req.nemotron_detected, req.nemotron_category, req.nemotron_confidence,
        req.highway, req.maxspeed, req.lanes, req.road_name,
    )

    # ── 1. Pass A — text-only structured analysis ────────────────────────
    try:
        text_raw = run_text_llm(
            build_text_pass_prompt(
                category      = req.category,
                sub_problem   = req.sub_problem,
                description   = req.description,
                still_votes   = req.still_votes,
                is_predefined = req.is_predefined,
                highway       = req.highway,
                maxspeed      = req.maxspeed,
                lanes         = req.lanes,
                road_name     = req.road_name,
            ),
            temperature = 0.25,
            top_p       = 0.8,
            max_tokens  = TEXT_PASS_MAX_TOKENS,
        )
        log.info("─── PASS A (raw) ───\n%s", text_raw)
        text_data = extract_json(text_raw)
    except Exception as e:
        log.warning("Pass A failed (%s) — using safe defaults.", e)
        text_data = {
            "plausibility":   0.55,
            "category_match": "UNCLEAR",
            "severity":       "MEDIUM",
            "concerns":       ["pass_a_parse_error"],
            "reasoning":      "Text analysis unavailable; using defaults.",
        }

    text_plausibility   = _clamp(float(text_data.get("plausibility", 0.55)))
    text_category_match = str(text_data.get("category_match", "UNCLEAR")).upper()
    text_severity       = _normalize_severity(text_data.get("severity", "MEDIUM"))
    text_reasoning      = str(text_data.get("reasoning", "")).strip()

    # ── 2. Pass C — combined verdict ────────────────────────────────────
    try:
        verdict_raw = run_text_llm(
            build_verdict_pass_prompt(
                category      = req.category,
                text_analysis = {
                    "plausibility":   text_plausibility,
                    "category_match": text_category_match,
                    "severity":       text_severity,
                    "concerns":       text_data.get("concerns") or [],
                    "reasoning":      text_reasoning,
                },
                image_block   = build_image_block_for_verdict(
                    image_description   = req.image_description,
                    nemotron_detected   = req.nemotron_detected,
                    nemotron_category   = req.nemotron_category,
                    nemotron_confidence = req.nemotron_confidence,
                    nemotron_severity   = req.nemotron_severity,
                    nemotron_scene_type = req.nemotron_scene_type,
                    image_count         = req.image_count,
                ),
                still_votes   = req.still_votes,
                highway       = req.highway,
                maxspeed      = req.maxspeed,
                lanes         = req.lanes,
                road_name     = req.road_name,
            ),
            temperature = 0.1,
            top_p       = 0.7,
            max_tokens  = VERDICT_PASS_MAX_TOKENS,
        )
        log.info("─── PASS C (raw) ───\n%s", verdict_raw)
        verdict_data = extract_json(verdict_raw)
    except Exception as e:
        log.warning("Pass C failed (%s) — defaulting to plausibility-based verdict.", e)
        verdict_data = {
            "valid":     text_plausibility >= 0.45,
            "agreement": "NO_IMAGE" if not req.image_description else "WEAK",
            "priority":  text_severity,
            "reason":    text_reasoning or "AI verdict unavailable; based on text plausibility only.",
        }

    valid       = bool(verdict_data.get("valid", True))
    agreement   = str(verdict_data.get("agreement", "NO_IMAGE")).upper()
    llm_prio    = _normalize_severity(verdict_data.get("priority", "MEDIUM"))
    reason_text = str(verdict_data.get("reason", "Validated by AI.")).strip() or "Validated by AI."

    # ── Hard override: no image evidence ─────────────────────────────────
    # When image_description is empty the LLM had no visual data and must not
    # award STRONG/PARTIAL agreement — cap it to NO_IMAGE regardless of what
    # the LLM returned (guards against hallucination on a high-plausibility text).
    image_was_analyzed = bool(req.image_description and req.image_description.strip())
    if not image_was_analyzed and agreement not in ("NO_IMAGE", "CONFLICT"):
        log.info("Agreement cap: LLM returned %s but no image was analyzed — forcing NO_IMAGE", agreement)
        agreement = "NO_IMAGE"

    # ── Hard override: Nemotron found nothing ─────────────────────────────
    # Even when an image WAS analyzed, if Nemotron returned detected=False the
    # LLM in Pass C can still hallucinate STRONG/PARTIAL agreement because the
    # text description is convincing.  Enforce the contract: STRONG/PARTIAL
    # both require detected=True.  When nothing was detected the best agreement
    # that can be awarded is WEAK (image present but inconclusive).
    if (
        image_was_analyzed
        and not req.nemotron_detected
        and agreement in ("STRONG", "PARTIAL")
    ):
        log.info(
            "Agreement cap: nemotron_detected=False → downgrading agreement %s → WEAK "
            "(scene_type=%s, category=%s)",
            agreement, req.nemotron_scene_type, req.category,
        )
        agreement = "WEAK"

    # ── Hard override: irrelevant photo ──────────────────────────────────
    # If an image was analyzed and it clearly shows a non-road scene the
    # report is invalid regardless of how convincing the text sounds.
    desc_lower           = (req.image_description or "").lower()
    desc_has_non_road_kw = any(kw in desc_lower for kw in NON_ROAD_KEYWORDS)
    scene_not_road       = req.nemotron_scene_type not in ("ROAD", "ADJACENT")

    override_reason = (
        "scene_type=NON_ROAD" if req.nemotron_scene_type == "NON_ROAD"
        else "no_detection+non_road_keywords" if (
            image_was_analyzed
            and not req.nemotron_detected
            and scene_not_road
            and desc_has_non_road_kw
        )
        else None
    )

    if override_reason:
        valid       = False
        agreement   = "CONFLICT"
        reason_text = (
            "The submitted photo does not show a road, street, or any related "
            "infrastructure. A valid report photo must clearly show the reported "
            "issue in a road or street context."
        )
        log.info(
            "Hard override → valid=False [%s] (category=%s, scene_type=%s, detected=%s).",
            override_reason, req.category, req.nemotron_scene_type, req.nemotron_detected,
        )

    # ── 3. Deterministic calibration ─────────────────────────────────────
    final_conf = calibrate_confidence(
        text_plausibility   = text_plausibility,
        text_category_match = text_category_match,
        agreement           = agreement,
        is_predefined       = req.is_predefined,
        still_votes         = req.still_votes,
        valid               = valid,
        nemotron_scene_type = req.nemotron_scene_type,
    )

    priority = compute_priority(
        valid          = valid,
        llm_priority   = llm_prio,
        text_severity  = text_severity,
        image_severity = req.nemotron_severity,
        category       = req.category,
        highway        = req.highway,
    )

    # ── 4. Append transparency signals to reason ──────────────────────────
    suffix_bits: list[str] = []
    if req.highway:
        suffix_bits.append(f"road={req.highway}")
    if agreement and agreement != "NO_IMAGE":
        suffix_bits.append(f"image_evidence={agreement.lower()}")
    if req.still_votes > 0:
        suffix_bits.append(f"votes={req.still_votes}")
    final_reason = reason_text + ((" [" + ", ".join(suffix_bits) + "]") if suffix_bits else "")

    log.info(
        "ANALYZE done in %dms → valid=%s confidence=%.3f priority=%s agreement=%s",
        int((time.perf_counter() - started) * 1000), valid, final_conf, priority, agreement,
    )

    return AnalyzeResponse(
        valid             = valid,
        confidence        = final_conf,
        reason            = final_reason,
        priority          = priority,
        agreement         = agreement,
        severity          = priority,
        text_plausibility = text_plausibility,
    )


# ───────────────────────────────────────────────────────────────────────────
# /detect — Nemotron image analysis
# ───────────────────────────────────────────────────────────────────────────
@app.post("/detect", response_model=DetectResponse)
async def detect(req: DetectRequest) -> DetectResponse:
    if not req.image_urls:
        raise HTTPException(status_code=400, detail="Provide at least one URL in image_urls.")
    return await _detect_nemotron(req.image_urls)


async def _detect_nemotron(urls: list[str]) -> DetectResponse:
    if nvidia_client is None:
        raise HTTPException(status_code=503, detail="NVIDIA_API_KEY not set.")

    urls = urls[:MAX_IMAGES]
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                      "AppleWebKit/537.36 (KHTML, like Gecko) "
                      "Chrome/120.0.0.0 Safari/537.36"
    }

    encoded_images: list[str] = []
    last_error = ""

    async with httpx.AsyncClient(
        timeout=IMAGE_DOWNLOAD_TIMEOUT_SEC,
        headers=headers,
        follow_redirects=True,
    ) as http:
        for url in urls:
            try:
                resp = await http.get(url)
                resp.raise_for_status()
                content_type = resp.headers.get("content-type", "")
                if not content_type.startswith("image/"):
                    last_error = f"URL returned {content_type!r}, expected an image"
                    log.warning("Nemotron skipped %s: %s", url, last_error)
                    continue
                encoded_images.append(base64.b64encode(resp.content).decode("utf-8"))
            except Exception as e:
                last_error = str(e)
                log.warning("Nemotron skipped image %s: %s", url, e)

    if not encoded_images:
        raise HTTPException(
            status_code=400,
            detail=f"Could not download any of the provided images. Reason: {last_error}",
        )

    img_count = len(encoded_images)
    content: list[dict[str, Any]] = [{"type": "text", "text": build_detect_prompt(img_count)}]
    for img_b64 in encoded_images:
        content.append({
            "type":      "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"},
        })

    try:
        completion = nvidia_client.chat.completions.create(
            model       = NVIDIA_IMAGE_MODEL,
            messages    = [{"role": "user", "content": content}],
            temperature = 0.15,
            top_p       = 0.9,
            max_tokens  = 260,
            extra_body  = {"chat_template_kwargs": {"enable_thinking": False}},
            stream      = True,
        )

        raw = ""
        for chunk in completion:
            if chunk.choices and chunk.choices[0].delta.content:
                raw += chunk.choices[0].delta.content

        raw = raw.strip()
        log.info("─── NEMOTRON /detect (raw) ───\n%s", raw)

        data       = extract_json(raw)
        detected   = bool(data.get("detected", False))
        category   = str(data.get("category", "other"))
        confidence = _clamp(float(data.get("confidence", 0.0)))
        severity   = _normalize_severity(data.get("severity"), default="MEDIUM" if detected else "LOW")
        scene_type = str(data.get("scene_type", "UNCLEAR")).upper()
        if scene_type not in {"ROAD", "ADJACENT", "NON_ROAD", "UNCLEAR"}:
            scene_type = "UNCLEAR"
        image_description = str(data.get("image_description", "")).strip()

        if category not in ALL_CATEGORIES:
            category = "other"

        # If model detected an issue but flagged scene as NON_ROAD, downgrade to not-detected
        if detected and scene_type == "NON_ROAD":
            log.info("Nemotron downgraded: detected=True but scene_type=NON_ROAD → forcing detected=False")
            detected   = False
            category   = "other"
            confidence = min(confidence, 0.10)

        if not detected and not image_description:
            image_description = (
                "No road infrastructure issue was detected in the submitted image(s). "
                "The image does not appear to show any road damage or hazard."
            )

        log.info(
            "Nemotron /detect → detected=%s category=%s confidence=%.2f severity=%s scene=%s",
            detected, category, confidence, severity, scene_type,
        )

        return DetectResponse(
            detected=detected, category=category, confidence=confidence,
            image_description=image_description, severity=severity, scene_type=scene_type,
        )

    except ValueError as e:
        log.warning("Nemotron JSON parse failed: %s", e)
        return DetectResponse(
            detected=False, category="other", confidence=0.0,
            image_description="Image analysis was inconclusive — no road issue could be identified.",
            severity="LOW", scene_type="UNCLEAR",
        )
    except Exception as e:
        log.error("Nemotron call failed: %s", e)
        raise HTTPException(status_code=500, detail=f"Nemotron image analysis failed: {e}")


# ───────────────────────────────────────────────────────────────────────────
# Health check
# ───────────────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "status":           "ok",
        "version":          "2.1.0",
        "text_llm":         NVIDIA_TEXT_MODEL,
        "image_llm":        NVIDIA_IMAGE_MODEL,
        "provider":         "nvidia/integrate-api",
        "nvidia_key":       "configured" if NVIDIA_API_KEY else "MISSING",
        "pipeline":         "Pass A (text) → /detect (image) → Pass C (verdict) → calibrator",
        "confidence_model": "deterministic: text_plausibility + image_agreement + votes + category_match + highway_floor",
    }
