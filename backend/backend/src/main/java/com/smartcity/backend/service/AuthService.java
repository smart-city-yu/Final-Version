package com.smartcity.backend.service;

import com.smartcity.backend.dto.AuthResponse;
import com.smartcity.backend.dto.LoginRequest;
import com.smartcity.backend.dto.RegisterRequest;
import com.smartcity.backend.exception.*;
import com.smartcity.backend.enums.Role;
import com.smartcity.backend.model.PasswordResetToken;
import com.smartcity.backend.model.User;
import com.smartcity.backend.repository.PasswordResetTokenRepository;
import com.smartcity.backend.repository.UserRepository;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.smartcity.backend.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Random;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository               userRepository;
    private final BCryptPasswordEncoder        passwordEncoder;
    private final JwtUtil                      jwtUtil;
    private final EmailService                 emailService;
    private final PasswordResetTokenRepository resetTokenRepository;

    // -------------------------------------------------------------------------
    // Register — creates account as disabled until email is verified
    // -------------------------------------------------------------------------
    @Transactional
    public AuthResponse register(RegisterRequest request) {

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new EmailAlreadyExistsException(
                    "Email already registered: " + request.getEmail());
        }

        if (userRepository.existsByNationalId(request.getNationalId())) {
            throw new NationalIdAlreadyExistsException(
                    "An account with this National ID already exists");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .phoneNumber(request.getPhoneNumber())
                .nationalId(request.getNationalId())
                .role(Role.USER)
                .enabled(false)
                .build();

        User savedUser = userRepository.save(user);

        try {
            emailService.sendVerificationEmail(savedUser);
        } catch (Exception e) {
            // SMTP failure must not roll back the account — log and continue.
            // The token is persisted; the user can request a resend or an admin
            // can manually enable the account if email delivery keeps failing.
            log.error("Could not send verification email to {}: {}",
                    savedUser.getEmail(), e.getMessage());
        }

        return AuthResponse.builder()
                .token(null)
                .userId(savedUser.getId())
                .fullName(savedUser.getFullName())
                .email(savedUser.getEmail())
                .role(savedUser.getRole())
                .build();
    }

    // -------------------------------------------------------------------------
    // Login
    // -------------------------------------------------------------------------
    public AuthResponse login(LoginRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new UserNotFoundException(
                        "No account found with email: " + request.getEmail()));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new InvalidCredentialsException("Invalid email or password");
        }

        if (!user.isEnabled()) {
            throw new AccountNotVerifiedException(
                    "Please verify your email before logging in");
        }

        String jwt = jwtUtil.generateToken(user);

        String fireBaseToken = null;
        try {
            fireBaseToken = FirebaseAuth.getInstance()
                    .createCustomToken(String.valueOf(user.getId()));
        } catch (FirebaseAuthException e) {
            log.warn("Could not generate Firebase custom token for user {}: {}", user.getId(), e.getMessage());
        }

        return AuthResponse.builder()
                .token(jwt)
                .fireBaseToken(fireBaseToken)
                .userId(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .build();
    }

    // -------------------------------------------------------------------------
    // Forgot Password — generates a 6-digit code and emails it
    // -------------------------------------------------------------------------
    @Transactional
    public void forgotPassword(String email) {
        userRepository.findByEmail(email).ifPresent(user -> {
            if (!user.isEnabled()) return;

            resetTokenRepository.deleteByUserId(user.getId());

            String code = String.format("%06d", new Random().nextInt(1_000_000));
            resetTokenRepository.save(PasswordResetToken.builder()
                    .token(code)
                    .userId(user.getId())
                    .expiresAt(LocalDateTime.now().plusMinutes(30))
                    .used(false)
                    .build());

            emailService.sendPasswordResetEmail(user, code);
        });
        // Always void — caller sends same generic response regardless of email existence
    }

    // -------------------------------------------------------------------------
    // Verify Reset Code — checks the 6-digit code is valid (does NOT consume it)
    // -------------------------------------------------------------------------
    @Transactional(readOnly = true)
    public void verifyResetCode(String email, String code) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("INVALID_CODE"));

        PasswordResetToken resetToken = resetTokenRepository
                .findByUserIdAndToken(user.getId(), code)
                .orElseThrow(() -> new RuntimeException("INVALID_CODE"));

        if (resetToken.isUsed())
            throw new RuntimeException("USED_CODE");

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now()))
            throw new RuntimeException("EXPIRED_CODE");
    }

    // -------------------------------------------------------------------------
    // Reset Password — validates code, updates password, marks token used
    // -------------------------------------------------------------------------
    @Transactional
    public void resetPassword(String email, String code, String newPassword) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("INVALID_CODE"));

        PasswordResetToken resetToken = resetTokenRepository
                .findByUserIdAndToken(user.getId(), code)
                .orElseThrow(() -> new RuntimeException("INVALID_CODE"));

        if (resetToken.isUsed())
            throw new RuntimeException("USED_CODE");

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now()))
            throw new RuntimeException("EXPIRED_CODE");

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        resetToken.setUsed(true);
        resetTokenRepository.save(resetToken);
    }
}
