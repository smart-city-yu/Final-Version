package com.smartcity.backend.service;

import com.smartcity.backend.model.EmailVerificationToken;
import com.smartcity.backend.model.User;
import com.smartcity.backend.repository.EmailVerificationTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.mail.internet.MimeMessage;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;
    private final EmailVerificationTokenRepository tokenRepository;

    @Value("${app.base-url}")
    private String baseUrl;

    @Value("${spring.mail.username}")
    private String fromEmail;

    public void sendVerificationEmail(User user) {
        tokenRepository.deleteByUserId(user.getId());

        String token = UUID.randomUUID().toString();
        EmailVerificationToken verificationToken = EmailVerificationToken.builder()
                .token(token)
                .userId(user.getId())
                .expiresAt(LocalDateTime.now().plusHours(24))
                .build();
        tokenRepository.save(verificationToken);

        String verifyUrl = baseUrl + "/api/auth/verify?token=" + token;
        String html = buildEmailHtml(user.getFullName(), verifyUrl);

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(user.getEmail());
            helper.setSubject("Verify your SmartCity account");
            helper.setText(html, true);
            mailSender.send(message);
        } catch (Exception e) {
            throw new RuntimeException("Failed to send verification email: " + e.getMessage(), e);
        }
    }

    public void sendPasswordResetEmail(User user, String code) {
        String html = buildPasswordResetHtml(user.getFullName(), code);
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(user.getEmail());
            helper.setSubject("Reset your SmartCity password");
            helper.setText(html, true);
            mailSender.send(message);
        } catch (Exception e) {
            throw new RuntimeException("Failed to send password reset email: " + e.getMessage(), e);
        }
    }

    private String buildPasswordResetHtml(String fullName, String code) {
        return """
                <!DOCTYPE html>
                <html>
                <body style="font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px;">
                  <div style="max-width: 520px; margin: auto; background: #ffffff; border-radius: 12px; padding: 40px;">
                    <h2 style="color: #2e7d32; margin-bottom: 8px;">Reset Your Password</h2>
                    <p style="color: #333;">Hi %s,</p>
                    <p style="color: #555;">We received a request to reset your RoadNa password.
                       Enter the code below in the app to set a new password.
                       This code expires in <strong>30 minutes</strong>.</p>
                    <div style="text-align: center; margin: 32px 0;">
                      <div style="display: inline-block; background: #f0f7f0; border: 2px solid #2e7d32;
                                  border-radius: 12px; padding: 20px 40px;">
                        <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #2e7d32;">%s</span>
                      </div>
                    </div>
                    <p style="color: #999; font-size: 12px;">If you did not request a password reset, you can safely ignore this email. Your password will not change.</p>
                  </div>
                </body>
                </html>
                """.formatted(fullName, code);
    }

    private String buildEmailHtml(String fullName, String verifyUrl) {
        return """
                <!DOCTYPE html>
                <html>
                <body style="font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px;">
                  <div style="max-width: 520px; margin: auto; background: #ffffff; border-radius: 12px; padding: 40px;">
                    <h2 style="color: #2e7d32; margin-bottom: 8px;">Welcome to SmartCity!</h2>
                    <p style="color: #333;">Hi %s,</p>
                    <p style="color: #555;">Click the button below to verify your email address. This link expires in 24 hours.</p>
                    <div style="text-align: center; margin: 32px 0;">
                      <a href="%s"
                         style="background: #2e7d32; color: #fff; padding: 14px 32px;
                                border-radius: 8px; text-decoration: none; font-size: 16px;">
                        Verify Email
                      </a>
                    </div>
                    <p style="color: #999; font-size: 12px;">If you did not create an account, you can safely ignore this email.</p>
                  </div>
                </body>
                </html>
                """.formatted(fullName, verifyUrl);
    }
}
