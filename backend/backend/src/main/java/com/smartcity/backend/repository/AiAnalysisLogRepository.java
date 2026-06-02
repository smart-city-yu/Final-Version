package com.smartcity.backend.repository;

import com.smartcity.backend.model.AiAnalysisLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AiAnalysisLogRepository extends JpaRepository<AiAnalysisLog, String> {

    /** All log entries for a report, newest first. */
    List<AiAnalysisLog> findByReportIdOrderByRanAtDesc(String reportId);
}
