package com.care.ride.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/debug")
public class DebugController {

    @Value("${spring.mail.host:NOT_SET}")
    private String mailHost;

    @Value("${spring.mail.port:NOT_SET}")
    private String mailPort;

    @Value("${spring.mail.username:NOT_SET}")
    private String mailUsername;

    @Value("${spring.mail.password:NOT_SET}")
    private String mailPassword;

    @GetMapping("/mail-config")
    public Map<String, Object> getMailConfig() {
        Map<String, Object> config = new HashMap<>();
        config.put("mailHost", mailHost);
        config.put("mailPort", mailPort);
        config.put("mailUsername", mailUsername);
        config.put("mailPasswordLength", mailPassword != null ? mailPassword.length() : 0);
        config.put("mailPasswordSet", !mailPassword.equals("NOT_SET") && !mailPassword.isEmpty());
        config.put("mailPasswordFirst3", mailPassword.length() >= 3 ? mailPassword.substring(0, 3) : "");
        config.put("mailPasswordLast3", mailPassword.length() >= 3 ? mailPassword.substring(mailPassword.length() - 3) : "");
        return config;
    }
}
