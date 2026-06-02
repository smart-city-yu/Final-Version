package com.smartcity.backend.repository;

import com.smartcity.backend.model.Report;
import com.smartcity.backend.model.ReportH3;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ReportH3Repository extends JpaRepository<ReportH3, Long> {

    @Query("""
        SELECT rh.report
        FROM ReportH3 rh
        WHERE rh.h3Token = :h3Token
""")
    List<Report> findReportsByH3Token(Long h3Token);
    long countByH3Token(Long h3Token);
    @Query("""
        SELECT r.report
        FROM ReportH3 r
        WHERE r.h3Token IN :tokens
    """)
    List<Report> getAllReportByH3Tokens(@Param("tokens") List<Long> tokens);
}
