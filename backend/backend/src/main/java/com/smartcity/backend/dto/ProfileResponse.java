package com.smartcity.backend.dto;

import com.smartcity.backend.enums.Role;
import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProfileResponse {

    private Long userId;

    private String nationalId;

    private String fullName;

    private String email;

    private String phoneNumber;

    private Role role;

}