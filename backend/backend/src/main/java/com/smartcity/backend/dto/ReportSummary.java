package com.smartcity.backend.dto;

import com.uber.h3core.util.LatLng;

public class ReportSummary {
    private double lat;
    private double lng;
    private Long count;

    public ReportSummary(LatLng latLng, Long count) {
        this.lat = latLng.lat;
        this.lng = latLng.lng;
        this.count = count;
    }

    public double getLat() {
        return lat;
    }

    public void setLat(double lat) {
        this.lat = lat;
    }

    public double getLng() {
        return lng;
    }

    public void setLng(double lng) {
        this.lng = lng;
    }

    public Long getCount() {
        return count;
    }

    public void setCount(Long count) {
        this.count = count;
    }
}
