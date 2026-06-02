-- SmartCity backend schema

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id           BIGSERIAL    PRIMARY KEY,
    full_name    VARCHAR(255) NOT NULL,
    email        VARCHAR(255) NOT NULL UNIQUE,
    password     VARCHAR(255) NOT NULL,
    phone_number VARCHAR(255) NOT NULL,
    national_id  VARCHAR(255) NOT NULL UNIQUE,
    role         VARCHAR(50)  NOT NULL,
    enabled      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP    NOT NULL
);

CREATE TABLE IF NOT EXISTS report (
    report_id          VARCHAR(36)       PRIMARY KEY,
    user_id            BIGINT            NOT NULL,
    description        VARCHAR(2000)     NOT NULL,
    sub_problem        VARCHAR(500),
    note               VARCHAR(2000),
    lat                DOUBLE PRECISION  NOT NULL,
    lon                DOUBLE PRECISION  NOT NULL,
    category           VARCHAR(50)       NOT NULL,
    metadata           JSONB,
    status             VARCHAR(50)       NOT NULL,
    priority           VARCHAR(50),
    priority_set_by    VARCHAR(255)      NOT NULL DEFAULT 'AI',
    created_at         TIMESTAMP         NOT NULL,
    resolved_at        TIMESTAMP,
    unassessed_at      TIMESTAMP,
    still_votes        INTEGER           NOT NULL DEFAULT 0,
    fixed_votes        INTEGER           NOT NULL DEFAULT 0,
    validation_score   DOUBLE PRECISION  NOT NULL DEFAULT 0.0,
    validation_reason  TEXT,
    revalidation_count INTEGER           NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS report_image_urls (
    report_id VARCHAR(36)   NOT NULL REFERENCES report(report_id),
    image_url VARCHAR(1000)
);

CREATE SEQUENCE IF NOT EXISTS report_h3_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS report_h3 (
    id      BIGINT      PRIMARY KEY DEFAULT nextval('report_h3_seq'),
    rep_id  VARCHAR(36) NOT NULL REFERENCES report(report_id),
    h3token BIGINT      NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_h3token ON report_h3 (h3token);

CREATE TABLE IF NOT EXISTS h3_token_agg (
    h3token_id  BIGINT           PRIMARY KEY,
    x           DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    y           DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    z           DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    count       BIGINT           NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_vote (
    id        BIGSERIAL   PRIMARY KEY,
    user_id   BIGINT      NOT NULL,
    report_id VARCHAR(36) NOT NULL,
    vote_type VARCHAR(50) NOT NULL,
    voted_at  TIMESTAMP   NOT NULL,
    CONSTRAINT uk_user_vote UNIQUE (user_id, report_id)
);

CREATE TABLE IF NOT EXISTS ai_analysis_log (
    id         VARCHAR(36)      PRIMARY KEY,
    report_id  VARCHAR(255)     NOT NULL,
    ran_at     TIMESTAMP        NOT NULL,
    valid      BOOLEAN          NOT NULL,
    confidence DOUBLE PRECISION NOT NULL,
    reason     VARCHAR(2000),
    priority   VARCHAR(50),
    "trigger"  VARCHAR(30)
);
CREATE INDEX IF NOT EXISTS idx_ai_log_report_id ON ai_analysis_log (report_id);

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id         BIGSERIAL    PRIMARY KEY,
    token      VARCHAR(255) NOT NULL UNIQUE,
    user_id    BIGINT       NOT NULL,
    expires_at TIMESTAMP    NOT NULL
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         VARCHAR(36)  PRIMARY KEY,
    token      VARCHAR(255) NOT NULL,
    user_id    BIGINT       NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    used       BOOLEAN      NOT NULL DEFAULT FALSE
);
