package com.smartcity.backend.dto;

import com.smartcity.backend.enums.ReportPriority;
import lombok.Builder;
import lombok.Data;

/**
 * Result of one AI analysis run.
 *
 * The first four fields are authoritative and persisted on the report:
 *   - valid       : did the AI decide this is a real, actionable issue?
 *   - confidence  : final calibrated confidence in [0.0, 1.0]
 *   - reason      : 1–2 sentence human-readable explanation
 *   - priority    : LOW / MEDIUM / HIGH / CRITICAL
 *
 * The remaining fields are transparency signals from the Python pipeline.
 * They are not persisted yet but are logged for debugging and may be surfaced
 * to admins in the future.
 */
@Data
@Builder
public class AiAnalysisResult {
    private boolean valid;
    private double  confidence;       // 0.0 → 1.0 (final, post-calibration)
    private String  reason;
    private ReportPriority priority;

    // Transparency signals (nullable — populated by Python pipeline only)
    private String  agreement;        // STRONG | PARTIAL | WEAK | CONFLICT | NO_IMAGE
    private String  severity;         // mirror of priority for clients that need the raw severity label
    private Double  textPlausibility; // 0.0 → 1.0 raw text-only score from Pass A
}
