package com.smartcity.backend.repository;

import com.smartcity.backend.model.UserVote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserVoteRepository extends JpaRepository<UserVote, Long> {

    Optional<UserVote> findByUserIdAndReportId(Long userId, String reportId);
}
