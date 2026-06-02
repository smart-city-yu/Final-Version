package com.smartcity.backend.exception;

public class NationalIdAlreadyExistsException extends RuntimeException {
    public NationalIdAlreadyExistsException(String message) {
        super(message);
    }
}