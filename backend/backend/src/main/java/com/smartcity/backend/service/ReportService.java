package com.smartcity.backend.service;

import com.smartcity.backend.GeoUtil;
import com.smartcity.backend.dto.*;
import com.smartcity.backend.enums.ReportCategory;
import com.smartcity.backend.enums.ReportPriority;
import com.smartcity.backend.enums.ReportStatus;
import com.smartcity.backend.enums.VoteType;
import com.smartcity.backend.exception.ReportDistanceException;
import com.smartcity.backend.exception.ReportNotFoundException;
import com.smartcity.backend.exception.TooManyRequestsException;
import com.smartcity.backend.model.*;
import com.smartcity.backend.repository.AiAnalysisLogRepository;
import com.smartcity.backend.repository.ReportRepository;
import com.smartcity.backend.repository.UserVoteRepository;
import com.uber.h3core.util.LatLng;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.example.ServiceRequest.MapMatchingResult;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.HashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class ReportService {

    private static final int    VOTE_THRESHOLD  = 5;
    private static final double VOTE_BOOST      = 0.1;
    private static final double VALID_THRESHOLD = 0.6;
    private static final double ALLOW_ERROR_MAP_MATCHING = 50.0D;


    private final ReportRepository        reportRepository;
    private final UserVoteRepository      userVoteRepository;
    private final H3ReportService         h3ReportService;
    private final H3CoreService           h3CoreService;
    private final AiAnalysisLogRepository aiLogRepository;
    private final AiService               aiService;
    private final RealtimeDbService       realtimeDbService;
    private final RoutingService          routingService;

    // =========================================================================
    // CREATE
    // =========================================================================

    @Transactional
    public ReportResponse createReport(Long userId, ReportCategory category,
                                       String subProblem, String description, String note,
                                       double lat, double lon,
                                       List<String> imageUrls) {

        // Resolve what the AI will see as the description.
        // Normal path : subProblem is a specific option text  → use it.
        // "Other" path: subProblem is null / "other"          → use user's typed description.
        String aiDescription;
        String storedSubProblem;

        boolean isOtherPath = subProblem == null
                || subProblem.trim().isEmpty()
                || subProblem.trim().equalsIgnoreCase("other");

        if (!isOtherPath) {
            aiDescription   = subProblem.trim();
            storedSubProblem = subProblem.trim();
        } else if (description != null && !description.trim().isEmpty()) {
            aiDescription   = description.trim();
            storedSubProblem = null;
        } else {
            throw new IllegalArgumentException(
                    "Please select an issue option or provide a description.");
        }

        // Enforce: at most 2 reports per user per 24 hours
        LocalDateTime cutoff = LocalDateTime.now().minusHours(24);
        if (reportRepository.countByUserIdAndCreatedAtAfter(userId, cutoff) >= 3) {
            throw new TooManyRequestsException(
                    "You can only submit 3 reports every 24 hours. Please try again later.");
        }
        MapMatchingResult mapMatchingResult = routingService.MatchToEdge(lat,lon);
        if (GeoUtil.getEdgeCost(mapMatchingResult.getRealPoint() , mapMatchingResult.getMapPoint()) > ALLOW_ERROR_MAP_MATCHING) {
            throw new ReportDistanceException(("You are too far from the road"));
        }
        lat = mapMatchingResult.getMapPoint().getLat();
        lon = mapMatchingResult.getMapPoint().getLon();

        Report report = Report.builder()
                .userId(userId)
                .category(category)
                .description(aiDescription)
                .subProblem(storedSubProblem)
                .note(note != null && !note.trim().isEmpty() ? note.trim() : null)
                .lat(lat)
                .lon(lon)
                .status(ReportStatus.UNASSESSED)
                .priority(ReportPriority.LOW)
                .prioritySetBy("AI")
                .unassessedAt(LocalDateTime.now())
                .metadata(mapMatchingResult.getWayTags())
                .imageUrls(imageUrls != null ? imageUrls : new ArrayList<>())
                .build();

        Report saved = reportRepository.save(report);
        // AI analysis runs in background (@Async) — H3 insertion happens inside
        // triggerAiAnalysis() once the report is confirmed PENDING, not here.
        triggerAiAnalysis(saved.getReportId());

        return ReportResponse.from(saved);
    }

    // =========================================================================
    // READ
    // =========================================================================
    public List<ReportSummary> getAllReportsSummaryInViewPort(double northLat, double northLng, double southLat, double southLng, int zoom) {
        List<Long> cells = h3CoreService.getCellsInViewport(northLat, northLng, southLat, southLng, zoom);
        List<H3TokenAgg> temp = h3ReportService.getReportAgg(cells);
        return temp.stream().map(e-> new ReportSummary(GeoUtil.fromXYZToLatLng(e.getX(),e.getY(),e.getZ()), e.getCount())).toList();
    }
    public List<ReportResponse> getAllReportsInViewPort(double northLat, double northLng, double southLat, double southLng, int zoom ){
        List<Long> cells = h3CoreService.getCellsInViewport(northLat, northLng, southLat, southLng, zoom);
        return h3ReportService.getAllReports(cells).stream().filter(rep -> rep.getStatus()!=ReportStatus.RESOLVED).map(ReportResponse::from).toList();
    }

    public List<ReportResponse> getAllReports() {
        return reportRepository.findAllByOrderByCreatedAtDesc()
                .stream().map(ReportResponse::from).collect(Collectors.toList());
    }

    public List<ReportResponse> getUserReports(Long userId) {
        return reportRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream().map(ReportResponse::from).collect(Collectors.toList());
    }

    public ReportResponse getReportById(String reportId) {
        return ReportResponse.from(findOrThrow(reportId));
    }

    // =========================================================================
    // VOTE
    // =========================================================================

    @Transactional
    public ReportResponse voteReport(Long userId, String reportId, VoteType voteType) {
        Report report = findOrThrow(reportId);

        // Users must not vote on their own reports
        if (report.getUserId().equals(userId)) {
            throw new IllegalArgumentException("You cannot vote on your own report.");
        }

        Optional<UserVote> existingOpt = userVoteRepository.findByUserIdAndReportId(userId, reportId);

        if (existingOpt.isPresent()) {
            UserVote existing = existingOpt.get();

            // Enforce 24-hour cooldown between vote changes
            long hoursSince = ChronoUnit.HOURS.between(existing.getVotedAt(), LocalDateTime.now());
            if (hoursSince < 24) {
                long hoursLeft = 24 - hoursSince;
                throw new TooManyRequestsException(
                        "You can change your vote in " + hoursLeft + " hour(s).");
            }

            // Same vote type — nothing to change
            if (existing.getVoteType() == voteType) {
                return ReportResponse.from(report);
            }

            // Swap the counts: undo old vote, apply new vote
            applyVoteDelta(report, existing.getVoteType(), -1);
            applyVoteDelta(report, voteType, +1);

            existing.setVoteType(voteType);
            existing.setVotedAt(LocalDateTime.now());
            userVoteRepository.save(existing);

        } else {
            // First time voting on this report
            applyVoteDelta(report, voteType, +1);
            userVoteRepository.save(UserVote.builder()
                    .userId(userId)
                    .reportId(reportId)
                    .voteType(voteType)
                    .votedAt(LocalDateTime.now())
                    .build());
        }

        // ── Vote-triggered AI logic ──────────────────────────────────────────
        int  stillVotes = report.getStillVotes();
        int  runs       = report.getRevalidationCount();

        if (report.getStatus() == ReportStatus.UNASSESSED && runs == 0) {
            // AI hasn't run yet — votes might push score over threshold
            double boostedScore = report.getValidationScore()
                    + (stillVotes * VOTE_BOOST);
            if (boostedScore >= VALID_THRESHOLD) {
                log.info("Report {} hit score threshold (stillVotes={}), triggering first AI run.",
                        reportId, stillVotes);
                triggerAiAnalysis(reportId);
            }

        } else if (voteType == VoteType.Still
                && report.getStatus() == ReportStatus.PENDING) {
            // Milestone re-analysis: feed updated vote context back to AI
            // Milestone 1 — 3 still votes (AI has run exactly once)
            // Milestone 2 — 5 still votes (AI has run exactly twice)
            boolean milestone1 = (stillVotes >= 3 && runs == 1);
            boolean milestone2 = (stillVotes >= 5 && runs == 2);

            if (milestone1 || milestone2) {
                log.info("Report {} hit vote milestone (stillVotes={}, runs={}), triggering re-analysis.",
                        reportId, stillVotes, runs);
                triggerVoteReanalysis(reportId);
            }
        }

        Report saved = reportRepository.save(report);
        realtimeDbService.pushReportUpdate(
                reportId, saved.getStillVotes(), saved.getFixedVotes(), saved.getStatus().name(),
                saved.getPriority() != null ? saved.getPriority().name() : null);
        return ReportResponse.from(saved);
    }

    /** Adjusts a vote counter by +1 or -1, clamping to zero. */
    private void applyVoteDelta(Report report, VoteType type, int delta) {
        if (type == VoteType.Still) {
            report.setStillVotes(Math.max(0, report.getStillVotes() + delta));
        } else {
            report.setFixedVotes(Math.max(0, report.getFixedVotes() + delta));
        }
    }

    // =========================================================================
    // ADMIN — update
    // =========================================================================

    @Transactional
    public ReportResponse updateReport(String reportId, UpdateReportRequest req) {
        Report report = findOrThrow(reportId);
        ReportStatus oldStatus = report.getStatus();

        if (req.isResetAiControl()) {
            // Admin hands priority ownership back to AI
            report.setPrioritySetBy("AI");
        } else {
            if (req.getStatus() != null) {
                ReportStatus newStatus = req.getStatus();
                report.setStatus(newStatus);
                if (newStatus == ReportStatus.RESOLVED && report.getResolvedAt() == null) {
                    report.setResolvedAt(LocalDateTime.now());
                }
            }
            if (req.getPriority() != null) {
                report.setPriority(req.getPriority());
                report.setPrioritySetBy("ADMIN");
            }
        }

        Report saved = reportRepository.save(report);
        realtimeDbService.pushReportUpdate(
                reportId, saved.getStillVotes(), saved.getFixedVotes(), saved.getStatus().name(),
                saved.getPriority() != null ? saved.getPriority().name() : null);
        return ReportResponse.from(saved);
    }

    // =========================================================================
    // IMAGE UPDATE (user during 48h window, or admin any time)
    // =========================================================================

    @Transactional
    public ReportResponse updateReportImages(String reportId, Long requestingUserId,
                                             boolean isAdmin, List<String> newImageUrls) {
        Report report = findOrThrow(reportId);

        if (!isAdmin) {
            if (!report.getUserId().equals(requestingUserId)) {
                throw new IllegalArgumentException("You can only update your own report's images.");
            }
            if (report.getStatus() != ReportStatus.UNASSESSED) {
                throw new IllegalArgumentException(
                        "Images can only be updated while the report is UNASSESSED.");
            }
        }

        report.getImageUrls().clear();
        report.getImageUrls().addAll(newImageUrls);
        return ReportResponse.from(reportRepository.save(report));
    }

    // =========================================================================
    // ADMIN — filter & stats
    // =========================================================================

    public List<ReportResponse> filterReports(ReportStatus status, ReportCategory category,
                                              LocalDateTime startDate, LocalDateTime endDate) {
        return reportRepository.findWithFilters(status, category, startDate, endDate)
                .stream().map(ReportResponse::from).collect(Collectors.toList());
    }

    public AdminStatsResponse getAdminStats() {
        long total = reportRepository.count();

        Map<String, Long> byCategory = new LinkedHashMap<>();
        for (ReportCategory cat : ReportCategory.values()) {
            byCategory.put(cat.name(), reportRepository.countByCategory(cat));
        }

        Map<String, Long> byStatus = new LinkedHashMap<>();
        for (ReportStatus st : ReportStatus.values()) {
            byStatus.put(st.name(), reportRepository.countByStatus(st));
        }

        long resolved = byStatus.getOrDefault(ReportStatus.RESOLVED.name(), 0L);
        double resolutionRate = total > 0 ? (resolved * 100.0) / total : 0.0;
        Double avgHours = reportRepository.findAverageResolutionHours();

        return AdminStatsResponse.builder()
                .totalReports(total)
                .reportsByCategory(byCategory)
                .reportsByStatus(byStatus)
                .resolutionRate(Math.round(resolutionRate * 10.0) / 10.0)
                .averageResolutionHours(avgHours != null ? Math.round(avgHours * 10.0) / 10.0 : 0.0)
                .build();
    }

    // =========================================================================
    // AI HISTORY
    // =========================================================================

    public List<AiAnalysisLogResponse> getAiHistory(String reportId) {
        findOrThrow(reportId); // 404 if report doesn't exist
        return aiLogRepository.findByReportIdOrderByRanAtDesc(reportId)
                .stream()
                .map(AiAnalysisLogResponse::from)
                .collect(Collectors.toList());
    }

    // =========================================================================
    // AI INTEGRATION — async trigger
    // =========================================================================

    /**
     * Runs in a background thread (@Async) so the HTTP response is never delayed.
     * @Transactional here starts a fresh transaction in the async thread —
     * self-calling applyAiResult() directly keeps everything in one transaction
     * and avoids the Spring proxy self-invocation problem.
     *
     * When the real Python service is ready, only AiService.analyzeReport() changes.
     */
    @Async
    @Transactional
    public void triggerAiAnalysis(String reportId ) {
        Report report = reportRepository.findById(reportId).orElse(null);
        if (report == null) return;

        // Skip if already past the UNASSESSED stage (admin may have acted)
        if (report.getStatus() != ReportStatus.UNASSESSED) {
            log.info("Skipping AI analysis for report {} — status is already {}",
                    reportId, report.getStatus());
            return;
        }

        try {
            // isPredefined = true when user picked a dropdown option (subProblem stored),
            // false when user typed free-text ("other" path).
            boolean isPredefined = report.getSubProblem() != null
                    && !report.getSubProblem().isBlank();

            // Pass ALL image URLs — Nemotron analyzes all of them in a single call.
            // sub_problem (dropdown text) and description (free text) are passed
            // separately so the Python prompts can distinguish them.
            AiAnalysisResult result = aiService.analyzeReport(
                    report.getCategory(),
                    report.getSubProblem(),
                    report.getDescription(),
                    report.getImageUrls(),
                    report.getLat(),
                    report.getLon(),
                    report.getStillVotes(),
                    isPredefined,
                    report.getMetadata()
            );

            // ── Persist log entry (history) ──────────────────────────────
            aiLogRepository.save(AiAnalysisLog.builder()
                    .reportId(reportId)
                    .ranAt(java.time.LocalDateTime.now())
                    .valid(result.isValid())
                    .confidence(result.getConfidence())
                    .reason(result.getReason())
                    .priority(result.getPriority())
                    .trigger("SUBMIT")
                    .build());

            // ── Update latest result on the Report row ───────────────────
            report.setValidationScore(result.getConfidence());
            report.setValidationReason(result.getReason());
            report.setRevalidationCount(report.getRevalidationCount() + 1);

            // Confidence < 0.35 → auto-reject regardless of valid flag.
            // Spam/low-quality text gets plausibility ≈ 0.05 from Pass A,
            // which the calibrator turns into confidence ≈ 0.30 — still below
            // this floor, so junk reports are reliably rejected.
            boolean autoRejected = result.getConfidence() < 0.50;

            if (autoRejected) {
                report.setStatus(ReportStatus.REJECTED);
                report.setValidationReason(
                    "Auto-rejected: AI confidence too low (" +
                    String.format("%.0f", result.getConfidence() * 100) + "%).");
                log.info("Report {} auto-rejected — confidence {} below floor.",
                        reportId, result.getConfidence());
            } else if (result.isValid()) {
                // Status: AI only moves UNASSESSED → PENDING, never overrides further
                report.setStatus(ReportStatus.PENDING);

                // Priority: only update if admin hasn't claimed ownership
                if ("AI".equals(report.getPrioritySetBy())) {
                    report.setPriority(result.getPriority());
                }
            }
            // valid=false but confidence ≥ 0.35: stays UNASSESSED — scheduler closes after 48h

            reportRepository.save(report);

            // Index in H3 so the report appears on the map — only for PENDING reports.
            // Must happen here (not in createReport) because triggerAiAnalysis is @Async:
            // by the time createReport checks the status the AI hasn't finished yet.
            if (report.getStatus() == ReportStatus.PENDING) {
                h3ReportService.InsertReportH3(report);
            }

            realtimeDbService.pushReportUpdate(
                    reportId, report.getStillVotes(), report.getFixedVotes(), report.getStatus().name(),
                    report.getPriority() != null ? report.getPriority().name() : null);
            log.info("AI applied to report {}: valid={}, confidence={}, priority={}",
                    reportId, result.isValid(), result.getConfidence(), result.getPriority());

        } catch (Exception e) {
            log.error("AI analysis failed for report {}: {}", reportId, e.getMessage());
        }
    }

    /**
     * Re-runs AI analysis on a PENDING report when community votes hit a milestone.
     *
     * Differences from triggerAiAnalysis:
     *   - Works on PENDING reports (not just UNASSESSED)
     *   - Never changes report status (stays PENDING — city workers already see it)
     *   - Respects prioritySetBy=ADMIN — skips priority update if admin owns it
     *   - Updates confidence + reason + revalidationCount so workers see fresh AI context
     */
    @Async
    @Transactional
    public void triggerVoteReanalysis(String reportId) {
        Report report = reportRepository.findById(reportId).orElse(null);
        if (report == null) return;

        if (report.getStatus() != ReportStatus.PENDING) {
            log.info("Skipping vote re-analysis for report {} — status is {}.",
                    reportId, report.getStatus());
            return;
        }

        try {
            boolean isPredefined = report.getSubProblem() != null
                    && !report.getSubProblem().isBlank();

            AiAnalysisResult result = aiService.analyzeReport(
                    report.getCategory(),
                    report.getSubProblem(),
                    report.getDescription(),
                    report.getImageUrls(),
                    report.getLat(),
                    report.getLon(),
                    report.getStillVotes(),   // ← updated vote count is the whole point
                    isPredefined,
                    report.getMetadata()
            );

            // Always log the re-analysis
            String trigger = report.getStillVotes() >= 5 ? "VOTE_MILESTONE_5" : "VOTE_MILESTONE_3";
            aiLogRepository.save(AiAnalysisLog.builder()
                    .reportId(reportId)
                    .ranAt(java.time.LocalDateTime.now())
                    .valid(result.isValid())
                    .confidence(result.getConfidence())
                    .reason(result.getReason())
                    .priority(result.getPriority())
                    .trigger(trigger)
                    .build());

            // Always update confidence + reason
            report.setValidationScore(result.getConfidence());
            report.setValidationReason(result.getReason());
            report.setRevalidationCount(report.getRevalidationCount() + 1);

            // Priority: only update if AI still owns it — never override ADMIN
            if ("AI".equals(report.getPrioritySetBy())) {
                report.setPriority(result.getPriority());
                log.info("Vote re-analysis: priority updated to {} for report {}.",
                        result.getPriority(), reportId);
            } else {
                log.info("Vote re-analysis: priority kept as ADMIN-set ({}) for report {}.",
                        report.getPriority(), reportId);
            }

            // Status intentionally NOT changed — report stays PENDING
            reportRepository.save(report);
            realtimeDbService.pushReportUpdate(
                    reportId, report.getStillVotes(), report.getFixedVotes(), report.getStatus().name(),
                    report.getPriority() != null ? report.getPriority().name() : null);
            log.info("Vote re-analysis done for report {}: confidence={}, priority={}",
                    reportId, result.getConfidence(), result.getPriority());

        } catch (Exception e) {
            log.error("Vote re-analysis failed for report {}: {}", reportId, e.getMessage());
        }
    }

    // =========================================================================
    // HELPER
    // =========================================================================

    private Report findOrThrow(String reportId) {
        return reportRepository.findById(reportId)
                .orElseThrow(() -> new ReportNotFoundException(
                        "Report not found with id: " + reportId));
    }

}
