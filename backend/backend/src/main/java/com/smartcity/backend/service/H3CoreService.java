package com.smartcity.backend.service;

import com.uber.h3core.H3Core;
import com.uber.h3core.util.LatLng;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Slf4j
@Service
public class H3CoreService {

    @Autowired
    private  H3Core h3Core;


    public Long getCell(double lat , double lon , int res){
        return h3Core.latLngToCell(lat,lon , res);
    }

    public List<Long> getCellsInViewport(
            double northLat,
            double northLng,
            double southLat,
            double southLng,
            int zoom
    ) {
        int resolution = zoomToResolution(zoom);

        // Build rectangle polygon
        List<LatLng> polygon = List.of(
                new LatLng(southLat, southLng),
                new LatLng(northLat, southLng),
                new LatLng(northLat, northLng),
                new LatLng(southLat, northLng),
                new LatLng(southLat, southLng) // close loop
        );

        // H3 polyfill (core function)
        return getKRings(h3Core.polygonToCells(polygon,null, resolution));
    }

    private List<Long> getKRings(List<Long> h3Ids){
        Set<Long> st = new HashSet<>();
        for (Long id : h3Ids){
            st.addAll(h3Core.gridDisk(id , 1));
        }
        return st.stream().toList();
    }
    private int zoomToResolution(int zoom) {
        System.out.println("Zoom Level:" + zoom);
        if (zoom <=6) return 3;
        if (zoom <=7) return 4;// continent view
        if (zoom <= 8) return 5;   // country
        if (zoom <= 9) return 6;   // region
        if (zoom <= 12) return 7;  // city
        if (zoom <= 15) return 8;  // district
        if (zoom <= 16) return 9;
        return 12;
    }
//
//    public LatLng getCenter(Long h3Index){
//        return h3Core.cellToLatLng(h3Index);
//    }

}


//private int zoomToResolution(int zoom) {
//    System.out.println("Zoom Level:" + zoom);
//    if (zoom <=6) return 3;   // continent view
//    if (zoom <= 8) return 4;   // country
//    if (zoom <= 9) return 5;   // region
//    if (zoom <= 12) return 7;  // city
//    if (zoom <= 15) return 8;  // district
//    return 8;
//}
