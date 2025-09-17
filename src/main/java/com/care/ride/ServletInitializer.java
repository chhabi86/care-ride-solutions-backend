package com.care.ride;

import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * Servlet initializer to support deployment of the application as a traditional WAR
 * file inside an external servlet container (e.g., standalone Tomcat).
 */
public class ServletInitializer extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(CareRideApplication.class);
    }
}
