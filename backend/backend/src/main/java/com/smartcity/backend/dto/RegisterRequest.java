package com.smartcity.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "Full name is required")
    @Size(min = 2, message = "Full name must be at least 2 characters")
    private String fullName;

    @NotBlank(message = "Email is required")
    @Email(message = "Email must be valid")
    private String email;

    @NotBlank(message = "Phone number is required")
    @Pattern(
            regexp = "^(\\+962|0)(7[0-9]{8})$",
            message = "Phone number must be a valid Jordanian number"
    )

    private String phoneNumber;

    @NotBlank(message = "National ID is required")
    @Pattern(
            regexp = "^[0-9]{10}$",
            message = "National ID must be exactly 10 digits"
    )
    // Jordanian National ID = exactly 10 digits.
    // Example: 9876543210
    private String nationalId;

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    private String password;
}