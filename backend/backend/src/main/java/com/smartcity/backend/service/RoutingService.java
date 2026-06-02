package com.smartcity.backend.service;

import com.uber.h3core.H3Core;
import org.example.Graph.Element.Node;
import org.example.Graph.Element.PlaceCategory;

import org.example.PlacesService.H3.H3PlaceWrapper;
import org.example.RoutingEngine;
import org.example.ServiceRequest.MapMatchingResult;
import org.example.ServiceResponse.RoutingPath;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class RoutingService {
    @Autowired
    private RoutingEngine routingEngine;

    public List<H3PlaceWrapper> getNearby(double lat, double lon , PlaceCategory category) {
        return routingEngine.getNearby(lat, lon, category);
    }

    public RoutingPath shortestRoute(double startLat, double startLon , double endLat, double endLon) {
        return routingEngine.shortestRoute(startLat, startLon, endLat, endLon);
    }
    public Node nearestNode(double lat , double lon) {
        return routingEngine.MatchToNode(lat ,lon);
    }
    public MapMatchingResult MatchToEdge(double lat , double lon) {
        return routingEngine.MatchToEdge(lat , lon);
    }
}
