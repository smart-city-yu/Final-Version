package com.smartcity.backend.exception;

public class ReportDistanceException extends RuntimeException {
    public ReportDistanceException(String message) {
        super(message);
    }

    public ReportDistanceException(String message, Throwable cause) {
        super(message, cause);
    }

    public ReportDistanceException(Throwable cause) {
        super(cause);
    }

    public ReportDistanceException(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) {
        super(message, cause, enableSuppression, writableStackTrace);
    }

    public ReportDistanceException() {
    }
}
