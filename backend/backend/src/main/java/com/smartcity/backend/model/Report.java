package com.smartcity.backend.model;

import com.smartcity.backend.enums.ReportCategory;
import com.smartcity.backend.enums.ReportPriority;
import com.smartcity.backend.enums.ReportStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "report")
@Entity
public class Report {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String reportId;

    @Column(nullable = false)
    private Long userId;

    // The text the AI sees. For normal path = subProblem text; for "other" path = user description.
    @Column(nullable = false, length = 2000)
    private String description;

    // The predefined option the user selected (null when category or subProblem is "other").
    @Column(nullable = true, length = 500)
    private String subProblem;

    // Staff-only note — never sent to AI. Only visible to staff/admin.
    @Column(nullable = true, length = 2000)
    private String note;

    @Column(nullable = false)
    private double lat;

    @Column(nullable = false)
    private double lon;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReportCategory category;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, String> metadata;
    // --- Status & Priority ---

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReportStatus status;

    @Enumerated(EnumType.STRING)
    private ReportPriority priority;

    // "AI" or "ADMIN" — whoever last set this field owns it
    // Only priority needs tracking — status conflict is handled by checking
    // the current status value (AI only ever moves UNASSESSED → PENDING)
    @Column(nullable = false)
    @Builder.Default
    private String prioritySetBy = "AI";

    // --- Timestamps ---

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    private LocalDateTime resolvedAt;

    // When the 48h UNASSESSED window started
    private LocalDateTime unassessedAt;

    // --- Community voting ---

    @Column(nullable = false)
    @Builder.Default
    private int stillVotes = 0;

    @Column(nullable = false)
    @Builder.Default
    private int fixedVotes = 0;

    // --- AI analysis fields ---
    // Populated by the real AI service in future.
    // The stub fills them with static values for now.

    @Column(nullable = false)
    @Builder.Default
    private double validationScore = 0.0;

    private String validationReason;

    @Column(nullable = false)
    @Builder.Default
    private int revalidationCount = 0;



    // --- Images ---
    // URLs pointing to Cloudinary (uploaded by backend on report creation)
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "report_image_urls",
            joinColumns = @JoinColumn(name = "report_id"))
    @Column(name = "image_url", length = 1000)
    @Builder.Default
    private List<String> imageUrls = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = ReportStatus.UNASSESSED;
        }
    }
}
