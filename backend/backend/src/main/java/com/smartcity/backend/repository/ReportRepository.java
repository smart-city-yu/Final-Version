package com.smartcity.backend.repository;

import com.smartcity.backend.enums.ReportCategory;
import com.smartcity.backend.enums.ReportStatus;
import com.smartcity.backend.model.Report;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ReportRepository extends JpaRepository<Report, String> {

    List<Report> findByUserIdOrderByCreatedAtDesc(Long userId);

    long countByUserIdAndCreatedAtAfter(Long userId, LocalDateTime cutoff);

    List<Report> findAllByOrderByCreatedAtDesc();

    long countByStatus(ReportStatus status);

    long countByCategory(ReportCategory category);

    @Query("SELECT r FROM Report r WHERE r.lat BETWEEN :latMin AND :latMax AND r.lon BETWEEN :lonMin AND :lonMax")
    List<Report> findReportsNearLocation(
            @Param("latMin") double latMin,
            @Param("latMax") double latMax,
            @Param("lonMin") double lonMin,
            @Param("lonMax") double lonMax
    );

    @Query(value = "SELECT AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600) FROM report WHERE resolved_at IS NOT NULL",
           nativeQuery = true)
    Double findAverageResolutionHours();

    @Query("SELECT r FROM Report r WHERE " +
            "(:status IS NULL OR r.status = :status) AND " +
            "(:category IS NULL OR r.category = :category) AND " +
            "(:startDate IS NULL OR r.createdAt >= :startDate) AND " +
            "(:endDate IS NULL OR r.createdAt <= :endDate) " +
            "ORDER BY r.createdAt DESC")
    List<Report> findWithFilters(
            @Param("status") ReportStatus status,
            @Param("category") ReportCategory category,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate
    );

    // Used by the @Scheduled expiry job to find UNASSESSED reports past their 48h window
    @Query("SELECT r FROM Report r WHERE r.status = com.smartcity.backend.enums.ReportStatus.UNASSESSED AND r.unassessedAt < :cutoff")
    List<Report> findUnassessedOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
