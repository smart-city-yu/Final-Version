package com.smartcity.backend.dto;

import lombok.Builder;
import lombok.Data;

import java.util.Map;

@Data
@Builder
public class AdminStatsResponse {
    private long totalReports;
    private Map<String, Long> reportsByCategory;
    private Map<String, Long> reportsByStatus;
    private double resolutionRate;
    private double averageResolutionHours;
}
