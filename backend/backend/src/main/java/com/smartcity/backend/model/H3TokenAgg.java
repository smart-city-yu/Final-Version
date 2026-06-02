package com.smartcity.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "h3_token_agg")
@Setter
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class H3TokenAgg {

    @Id
    private Long h3TokenId;

    @Column(nullable = false)
    private double x = 0.0;

    @Column(nullable = false)
    private double y = 0.0;

    @Column(nullable = false)
    private double z = 0.0;

    @Column(nullable = false)
    private Long count = 0L;
}
