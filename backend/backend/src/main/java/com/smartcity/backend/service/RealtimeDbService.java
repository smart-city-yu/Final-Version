package com.smartcity.backend.service;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/**
 * Pushes live report updates to Firebase Realtime Database.
 *
 * Structure:
 *   reports/{reportId}/stillVotes → int
 *   reports/{reportId}/fixedVotes → int
 *   reports/{reportId}/status     → String  e.g. "PENDING"
 *
 * Flutter listens to reports/{reportId} and updates the UI instantly.
 * Admin SDK bypasses security rules — Flutter clients are read-only.
 */
@Slf4j
@Service
public class RealtimeDbService {

    public void pushReportUpdate(String reportId, int stillVotes, int fixedVotes, String status, String priority) {
        try {
            DatabaseReference ref = FirebaseDatabase.getInstance()
                    .getReference("reports")
                    .child(reportId);

            Map<String, Object> updates = new HashMap<>();
            updates.put("stillVotes", stillVotes);
            updates.put("fixedVotes", fixedVotes);
            updates.put("status", status);
            if (priority != null) updates.put("priority", priority);

            ref.setValueAsync(updates);
            log.debug("Firebase RT pushed → report={} still={} fixed={} status={} priority={}",
                    reportId, stillVotes, fixedVotes, status, priority);

        } catch (Exception e) {
            // Never crash the main request — RT DB push is best-effort
            log.warn("Firebase RT push failed for report {}: {}", reportId, e.getMessage());
        }
    }
}
