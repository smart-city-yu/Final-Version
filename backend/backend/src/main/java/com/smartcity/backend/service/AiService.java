package com.smartcity.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartcity.backend.dto.AiAnalysisResult;
import com.smartcity.backend.enums.ReportCategory;
import com.smartcity.backend.enums.ReportPriority;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Bridge to the Python FastAPI AI service.
 *
 *   POST /detect   — Nemotron visual analysis (called only when images are present)
 *   POST /analyze  — Pass A (Llama 3.1 8B text) + Pass C + deterministic confidence calibrator
 *
 * The Python service is authoritative for confidence. This class only forwards
 * the citizen report + image signals, parses the response defensively, and
 * falls back to a keyword-based rule heuristic if the service is unreachable.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiService {

    @Value("${ai.service.url:http://localhost:8000}")
    private String aiServiceUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    // -------------------------------------------------------------------------
    // Public entry point — called by ReportService
    // -------------------------------------------------------------------------

    public AiAnalysisResult analyzeReport(ReportCategory category,
                                          String subProblem,
                                          String description,
                                          List<String> imageUrls,
                                          double lat,
                                          double lon,
                                          int stillVotes,
                                          boolean isPredefined,
                                          Map<String, String> metadata) {
        // Extract the OSM way-tag fields that inform AI priority and severity reasoning
        String highway  = metadata != null ? metadata.get("highway")  : null;
        String maxspeed = metadata != null ? metadata.get("maxspeed") : null;
        String lanes    = metadata != null ? metadata.get("lanes")    : null;
        String roadName = metadata != null ? metadata.get("name")     : null;

        try {
            // Step 1 — Image analysis (one /detect call for ALL images)
            DetectResult detect = DetectResult.empty();
            if (imageUrls != null && !imageUrls.isEmpty()) {
                try {
                    detect = callDetect(imageUrls);
                    log.info("Image /detect ({} image(s)) → detected={} category={} confidence={} severity={} scene_type={} description='{}'",
                            imageUrls.size(), detect.detected(), detect.category(),
                            detect.confidence(), detect.severity(), detect.sceneType(),
                            truncate(detect.imageDescription(), 120));
                } catch (Exception e) {
                    log.warn("Image /detect failed ({}), proceeding without image context.", e.getMessage());
                }
            }

            // Step 2 — LLM validation with full signal context
            // imageCount is 0 when detect failed — tells Python no image evidence exists,
            // preventing it from awarding STRONG agreement on a ghost image.
            boolean detectSucceeded = detect.imageDescription() != null;
            int imageCount = detectSucceeded ? (imageUrls != null ? imageUrls.size() : 0) : 0;
            String firstImageUrl = (imageUrls != null && !imageUrls.isEmpty()) ? imageUrls.get(0) : null;

            log.info("Sending to /analyze → image_count={} scene_type={} severity={} nemotron_detected={} highway={}",
                    imageCount, detect.sceneType(), detect.severity(), detect.detected(), highway);

            AiAnalysisResult llmResult = callAnalyze(
                    category, subProblem, description, firstImageUrl,
                    lat, lon, stillVotes, isPredefined,
                    detect.imageDescription(), imageCount,
                    detect.detected(), detect.category(), detect.confidence(),
                    detect.severity(), detect.sceneType(),
                    highway, maxspeed, lanes, roadName
            );

            log.info("AI final → valid={} confidence={} priority={} agreement={}",
                    llmResult.isValid(), llmResult.getConfidence(),
                    llmResult.getPriority(), llmResult.getAgreement());
            return llmResult;

        } catch (Exception e) {
            log.warn("Python AI service unavailable ({}), using rule-based fallback.", e.getMessage());
            throw new RuntimeException("AI Service unavailable (" + e.getMessage() + ")");
        }
    }

    // -------------------------------------------------------------------------
    // /analyze — text validation + deterministic confidence calibrator
    // -------------------------------------------------------------------------

    private AiAnalysisResult callAnalyze(ReportCategory category,
                                         String subProblem,
                                         String description,
                                         String imageUrl,
                                         double lat,
                                         double lon,
                                         int stillVotes,
                                         boolean isPredefined,
                                         String imageDescription,
                                         int imageCount,
                                         boolean nemotronDetected,
                                         String nemotronCategory,
                                         double nemotronConfidence,
                                         String nemotronSeverity,
                                         String nemotronSceneType,
                                         String highway,
                                         String maxspeed,
                                         String lanes,
                                         String roadName) throws Exception {

        AnalyzeRequest payload = new AnalyzeRequest(
                category.name(),
                subProblem,
                description,
                imageUrl,
                lat, lon,
                stillVotes,
                isPredefined,
                imageDescription,
                imageCount,
                nemotronDetected,
                nemotronCategory,
                nemotronConfidence,
                nemotronSeverity,
                nemotronSceneType,
                highway,
                maxspeed,
                lanes,
                roadName
        );

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(aiServiceUrl + "/analyze"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                .timeout(Duration.ofSeconds(90))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("AI /analyze returned HTTP " + response.statusCode()
                    + " body=" + truncate(response.body(), 300));
        }

        JsonNode json = objectMapper.readTree(response.body());

        boolean valid       = json.path("valid").asBoolean(true);
        double  confidence  = clamp(json.path("confidence").asDouble(0.5), 0.0, 1.0);
        String  reason      = json.path("reason").asText("Validated by AI.");
        String  priorityStr = json.path("priority").asText("MEDIUM");
        String  agreement   = json.path("agreement").asText(null);
        String  severity    = json.path("severity").asText(null);
        Double  textPlaus   = json.has("text_plausibility") ? json.get("text_plausibility").asDouble() : null;

        ReportPriority priority;
        try {
            priority = ReportPriority.valueOf(priorityStr.toUpperCase());
        } catch (IllegalArgumentException ex) {
            log.warn("AI returned unknown priority '{}', defaulting to MEDIUM", priorityStr);
            priority = ReportPriority.MEDIUM;
        }

        log.info("LLM /analyze → valid={} confidence={} priority={} agreement={} severity={} text_plausibility={} reason='{}'",
                valid, confidence, priority, agreement, severity, textPlaus, reason);

        return AiAnalysisResult.builder()
                .valid(valid)
                .confidence(confidence)
                .reason(reason)
                .priority(priority)
                .agreement(agreement)
                .severity(severity)
                .textPlausibility(textPlaus)
                .build();
    }

    // -------------------------------------------------------------------------
    // /detect — Nemotron image analysis
    // -------------------------------------------------------------------------

    private DetectResult callDetect(List<String> imageUrls) throws Exception {

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(aiServiceUrl + "/detect"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(
                        objectMapper.writeValueAsString(new DetectRequest(imageUrls))))
                .timeout(Duration.ofSeconds(90))   // Nemotron can take 60–90s for large images
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            throw new RuntimeException("AI /detect returned HTTP " + response.statusCode()
                    + " body=" + truncate(response.body(), 300));
        }

        JsonNode json = objectMapper.readTree(response.body());

        boolean detected         = json.path("detected").asBoolean(false);
        String  detCategory      = json.path("category").asText("other");
        double  confidence       = clamp(json.path("confidence").asDouble(0.0), 0.0, 1.0);
        String  imageDescription = json.path("image_description").asText("");
        String  severity         = json.path("severity").asText("MEDIUM");
        String  sceneType        = json.path("scene_type").asText("UNCLEAR");

        return new DetectResult(detected, detCategory, confidence, imageDescription, severity, sceneType);
    }

    // -------------------------------------------------------------------------
    // Small utils
    // -------------------------------------------------------------------------

    private static double clamp(double v, double lo, double hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    private static String truncate(String s, int max) {
        if (s == null) return "";
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }

    // -------------------------------------------------------------------------
    // Wire DTOs
    // -------------------------------------------------------------------------

    private record AnalyzeRequest(
            String category,
            String sub_problem,
            String description,
            String image_url,
            double lat,
            double lon,
            int still_votes,
            boolean is_predefined,
            String image_description,
            int image_count,
            boolean nemotron_detected,
            String nemotron_category,
            double nemotron_confidence,
            String nemotron_severity,
            String nemotron_scene_type,
            String highway,
            String maxspeed,
            String lanes,
            String road_name
    ) {}

    private record DetectRequest(List<String> image_urls) {}

    private record DetectResult(
            boolean detected,
            String category,
            double confidence,
            String imageDescription,
            String severity,
            String sceneType
    ) {
        static DetectResult empty() {
            return new DetectResult(false, "other", 0.0, null, null, null);
        }
    }
}
