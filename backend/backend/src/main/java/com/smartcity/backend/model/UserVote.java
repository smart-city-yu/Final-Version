package com.smartcity.backend.model;

import com.smartcity.backend.enums.VoteType;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "user_vote", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"user_id", "report_id"})
})
public class UserVote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "report_id", nullable = false)
    private String reportId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VoteType voteType;

    @Column(nullable = false)
    private LocalDateTime votedAt;
}
