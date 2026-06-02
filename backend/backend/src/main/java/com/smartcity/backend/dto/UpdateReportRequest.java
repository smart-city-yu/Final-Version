package com.smartcity.backend.dto;

import com.smartcity.backend.enums.ReportPriority;
import com.smartcity.backend.enums.ReportStatus;
import lombok.Data;

@Data
public class UpdateReportRequest {
    private ReportStatus status;
    private ReportPriority priority;

    // When true, admin hands control back to AI for future re-runs
    private boolean resetAiControl = false;
}
