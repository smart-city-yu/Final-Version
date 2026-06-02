package com.smartcity.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class CloudinaryService {

    private final Cloudinary cloudinary;

    public CloudinaryService(
            @Value("${cloudinary.cloud-name}") String cloudName,
            @Value("${cloudinary.api-key}")    String apiKey,
            @Value("${cloudinary.api-secret}") String apiSecret) {
        this.cloudinary = new Cloudinary(ObjectUtils.asMap(
                "cloud_name", cloudName,
                "api_key",    apiKey,
                "api_secret", apiSecret,
                "secure",     true
        ));
    }

    /**
     * Uploads a single image to Cloudinary and returns its HTTPS URL.
     */
    public String uploadImage(byte[] imageBytes, String folder) throws Exception {
        Map<?, ?> result = cloudinary.uploader().upload(imageBytes, ObjectUtils.asMap(
                "folder",        folder,
                "resource_type", "image"
        ));
        return (String) result.get("secure_url");
    }

    /**
     * Uploads a list of MultipartFiles to Cloudinary.
     * Silently skips any file that fails to upload.
     */
    public List<String> uploadImages(List<MultipartFile> files, String folder) {
        List<String> urls = new ArrayList<>();
        if (files == null) return urls;

        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) continue;
            try {
                String url = uploadImage(file.getBytes(), folder);
                urls.add(url);
                log.info("Uploaded image to Cloudinary: {}", url);
            } catch (Exception e) {
                log.warn("Failed to upload image '{}': {}", file.getOriginalFilename(), e.getMessage());
            }
        }
        return urls;
    }
}
