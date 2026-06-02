package com.smartcity.backend.config;


import org.example.RoutingEngine;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RoutingEngineConfig {

    @Bean
    public RoutingEngine engine() throws Exception {
        RoutingEngine engine = new RoutingEngine();
        engine.start();
        return engine;

    }
}
