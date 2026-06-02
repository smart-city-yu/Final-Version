package com.smartcity.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.io.InputStream;

@Slf4j
@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initialize() {
        try {
            if (!FirebaseApp.getApps().isEmpty()) return;

            InputStream serviceAccount =
                    new ClassPathResource("roadna-ce6a0-firebase-adminsdk-fbsvc-bfa3e5fb4c.json")
                            .getInputStream();

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .setDatabaseUrl("https://roadna-ce6a0-default-rtdb.europe-west1.firebasedatabase.app")
                    .build();

            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK initialised successfully.");

        } catch (IOException e) {
            log.error("Failed to initialise Firebase Admin SDK: {}", e.getMessage());
        }
    }
}
