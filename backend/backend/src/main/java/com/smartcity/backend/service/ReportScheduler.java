package com.smartcity.backend.service;

import com.smartcity.backend.enums.ReportStatus;
import com.smartcity.backend.model.Report;
import com.smartcity.backend.model.User;
import com.smartcity.backend.repository.PasswordResetTokenRepository;
import com.smartcity.backend.repository.ReportRepository;
import com.smartcity.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class ReportScheduler {

    private static final int WINDOW_HOURS = 48;

    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final PasswordResetTokenRepository resetTokenRepository;

    /**
     * Runs every hour.
     * Finds all UNASSESSED reports whose 48h window has expired and marks
     * them as REJECTED.
     */
    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void expireUnassessedReports() {
        LocalDateTime cutoff = LocalDateTime.now().minusHours(WINDOW_HOURS);
        List<Report> expired = reportRepository.findUnassessedOlderThan(cutoff);

        if (expired.isEmpty()) return;

        log.info("Expiry job: rejecting {} UNASSESSED report(s) past 48h window", expired.size());

        for (Report report : expired) {
            report.setStatus(ReportStatus.REJECTED);
            report.setValidationReason("Closed — not enough community confirmation within 48 hours");
        }

        reportRepository.saveAll(expired);
    }

    /**
     * Runs every hour.
     * Deletes unverified accounts that are older than 48 hours.
     * Also cleans up their reset tokens to avoid orphaned rows.
     */
    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void deleteUnverifiedAccounts() {
        LocalDateTime cutoff = LocalDateTime.now().minusHours(48);
        List<User> unverified = userRepository.findAllByEnabledFalseAndCreatedAtBefore(cutoff);

        if (unverified.isEmpty()) return;

        log.info("Account cleanup: deleting {} unverified account(s) older than 48h", unverified.size());

        for (User user : unverified) {
            resetTokenRepository.deleteByUserId(user.getId());
        }

        userRepository.deleteAll(unverified);
    }
}
