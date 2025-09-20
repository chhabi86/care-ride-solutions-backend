package com.care.ride.web;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/debug")
public class DebugMailController {

    @Value("${spring.mail.host:NOT_SET}")
    private String host;
    @Value("${spring.mail.port:0}")
    private String port;
    @Value("${spring.mail.username:NOT_SET}")
    private String user;
    @Value("${spring.mail.password:}")
    private String pass;

    @GetMapping("/mail")
    public ResponseEntity<Map<String,Object>> mail() {
        String masked = pass == null ? "null" : (pass.isEmpty()? "empty" : pass.charAt(0)+"***"+pass.charAt(pass.length()-1));
        return ResponseEntity.ok(Map.of(
                "host", host,
                "port", port,
                "username", user,
                "passwordLength", pass==null?0:pass.length(),
                "passwordMasked", masked,
                "envHint", System.getenv().containsKey("MAIL_PASSWORD")
        ));
    }
}