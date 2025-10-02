package com.care.ride.web;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

@RestController
@CrossOrigin(origins={
	"http://localhost:4200",
	"http://127.0.0.1:4201",
	"http://careridesolutionspa.com",
	"https://careridesolutionspa.com",
	"http://www.careridesolutionspa.com",
	"https://www.careridesolutionspa.com"
})
public class RootController {

	// Handle root domain access (api.careridesolutionspa.com)
	@GetMapping("/")
	public ResponseEntity<java.util.Map<String, Object>> root() {
		return ResponseEntity.ok(java.util.Map.of(
			"service", "Care Ride Solutions API",
			"version", "1.0.0",
			"status", "operational",
			"timestamp", System.currentTimeMillis(),
			"documentation", java.util.Map.of(
				"endpoints", java.util.List.of(
					java.util.Map.of("path", "/api/ping", "method", "GET", "description", "Health check"),
					java.util.Map.of("path", "/api/services", "method", "GET", "description", "Get available services"),
					java.util.Map.of("path", "/api/contact", "method", "POST", "description", "Submit contact form"),
					java.util.Map.of("path", "/api/bookings", "method", "POST", "description", "Create booking")
				),
				"baseUrl", "https://api.careridesolutionspa.com"
			)
		));
	}

	// Global health check
	@GetMapping("/health")
	public ResponseEntity<java.util.Map<String, Object>> health() {
		return ResponseEntity.ok(java.util.Map.of(
			"status", "healthy",
			"timestamp", System.currentTimeMillis(),
			"service", "care-ride-api"
		));
	}

	// API info endpoint
	@GetMapping("/info")
	public ResponseEntity<java.util.Map<String, Object>> info() {
		return ResponseEntity.ok(java.util.Map.of(
			"name", "Care Ride Solutions API",
			"description", "Medical transportation booking and contact API",
			"version", "1.0.0",
			"environment", "production",
			"contact", java.util.Map.of(
				"website", "https://careridesolutionspa.com",
				"email", "contact@careridesolutionspa.com"
			)
		));
	}
}
