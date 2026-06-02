package com.smartcity.backend.dto;

import com.smartcity.backend.model.AiAnalysisLog;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class AiAnalysisLogResponse {

    private String id;
    private String reportId;
    private LocalDateTime ranAt;
    private boolean valid;
    private double confidence;
    private String reason;
    private String priority;   // enum name as String so Flutter parses easily
    private String trigger;    // "SUBMIT" | "VOTE_MILESTONE_3" | "VOTE_MILESTONE_5"

    public static AiAnalysisLogResponse from(AiAnalysisLog log) {
        return AiAnalysisLogResponse.builder()
                .id(log.getId())
                .reportId(log.getReportId())
                .ranAt(log.getRanAt())
                .valid(log.isValid())
                .confidence(log.getConfidence())
                .reason(log.getReason())
                .priority(log.getPriority() != null ? log.getPriority().name() : null)
                .trigger(log.getTrigger())
                .build();
    }
}
