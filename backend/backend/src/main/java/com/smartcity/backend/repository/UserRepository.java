package com.smartcity.backend.repository;

import com.smartcity.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    boolean existsByNationalId(String nationalId);

    // Used by scheduler to auto-delete unverified accounts older than 48h
    List<User> findAllByEnabledFalseAndCreatedAtBefore(LocalDateTime cutoff);
}
