package com.smartcity.backend.controller;

import com.smartcity.backend.service.RoutingService;
import org.example.Graph.Element.PlaceCategory;
import org.example.PlacesService.H3.H3PlaceWrapper;
import org.example.ServiceResponse.RoutingPath;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/routing")

public class RoutingController {
    @Autowired
    private RoutingService routingService;
    @GetMapping("/places")
    public ResponseEntity<List<H3PlaceWrapper>> getPlaces(@RequestParam("lat") double lat , @RequestParam("lon") double lon , @RequestParam("category") PlaceCategory category ){ //  places -? lat, lon  , category
        List<H3PlaceWrapper> lis =  routingService.getNearby(lat , lon , category);
        return new ResponseEntity<>(lis, HttpStatus.OK);
    }

    @PostMapping("/route")
    public RoutingPath route(@RequestParam("lat1") double lat1 , @RequestParam("lon1") double lon1 , @RequestParam("lat2") double lat2 , @RequestParam("lon2") double lon2) { // start point , end point
        return routingService.shortestRoute(lat1, lon1, lat2, lon2);
    }

}
