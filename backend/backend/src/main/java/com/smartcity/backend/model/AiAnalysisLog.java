package com.smartcity.backend.model;

import com.smartcity.backend.enums.ReportPriority;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * One row per AI analysis run.
 * Appended every time ReportService.triggerAiAnalysis() completes — the
 * current Report row always holds the latest result; this table holds the
 * full history.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "ai_analysis_log",
       indexes = @Index(name = "idx_ai_log_report_id", columnList = "report_id"))
public class AiAnalysisLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(name = "report_id", nullable = false)
    private String reportId;

    @Column(nullable = false)
    private LocalDateTime ranAt;

    @Column(nullable = false)
    private boolean valid;

    @Column(nullable = false)
    private double confidence;

    @Column(length = 2000)
    private String reason;

    @Enumerated(EnumType.STRING)
    private ReportPriority priority;

    /**
     * What triggered this run:
     *   "SUBMIT"           — initial analysis on report creation
     *   "VOTE_MILESTONE_3" — re-analysis triggered when stillVotes reached 3
     *   "VOTE_MILESTONE_5" — re-analysis triggered when stillVotes reached 5
     */
    @Column(length = 30)
    private String trigger;
}
