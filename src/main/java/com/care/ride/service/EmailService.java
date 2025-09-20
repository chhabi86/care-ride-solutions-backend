package com.care.ride.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Service;


@Service
public class EmailService {
    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    // Inner class for SMTP attempt configuration
    private static class Attempt { 
        String host; 
        int port; 
        boolean ssl; 
        boolean startTls; 
        String label; 
    }

    @org.springframework.beans.factory.annotation.Value("${spring.mail.username:info@careridesolutionspa.com}")
    private String configuredSender;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.password:}")
    private String configuredPassword;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.host:smtp.mail.us-east-1.awsapps.com}")
    private String configuredHost;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.port:465}")
    private int configuredPort;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.protocol:smtp}")
    private String configuredProtocol;

    /**
     * Attempt to send an email using a few transport configurations (SSL on 465, STARTTLS on 587, plain on 25).
     * Returns true on first successful send, false otherwise. All failures are logged.
     */
    public boolean sendContactEmail(String to, String subject, String text) {
        log.info("=== EMAIL SEND ATTEMPT ===");
        log.info("From: {}", configuredSender);
        log.info("To: {}", to);
        log.info("Subject: {}", subject);
        log.info("Host: {}, Port: {}", configuredHost, configuredPort);
        log.info("Password configured: {}", (configuredPassword != null && !configuredPassword.trim().isEmpty()) ? "YES" : "NO");
        log.info("Password length: {}", configuredPassword != null ? configuredPassword.length() : 0);
        
        if (configuredPassword == null || configuredPassword.trim().isEmpty()) {
            log.error("❌ MAIL_PASSWORD is not configured! Email cannot be sent.");
            log.error("💡 To fix this:");
            log.error("   1. For Gmail: Enable 2FA, then generate App Password at https://support.google.com/accounts/answer/185833");
            log.error("   2. Set environment variables: MAIL_USERNAME=your-email@gmail.com MAIL_PASSWORD=your-app-password");
            log.error("   3. Restart the application");
            return false;
        }

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(configuredSender);
        message.setTo(to);
        message.setSubject(subject);
        message.setText(text);

        // Build candidate transports. We prioritize STARTTLS (587) for Microsoft/Office365 style hosts.
        java.util.LinkedHashMap<String, Attempt> attemptsMap = new java.util.LinkedHashMap<>();

        java.util.function.Function<Attempt, Attempt> add = a -> { attemptsMap.put(a.host+":"+a.port+":"+a.ssl+":"+a.startTls, a); return a; };

        boolean hostLooksMicrosoft = configuredHost.toLowerCase().contains("office") || configuredHost.toLowerCase().contains("outlook") || configuredHost.toLowerCase().contains("microsoft");

        // Primary derived from configured values
        Attempt cfg = new Attempt(); cfg.host = configuredHost; cfg.port = configuredPort; cfg.ssl = (configuredPort == 465); cfg.startTls = (configuredPort == 587); cfg.label = "configured"; add.apply(cfg);

        // If using Microsoft & not already 587, put 587 STARTTLS first
        if (hostLooksMicrosoft && configuredPort != 587) {
            Attempt ms = new Attempt(); ms.host = configuredHost; ms.port = 587; ms.ssl = false; ms.startTls = true; ms.label = "ms-starttls"; add.apply(ms);
        }

        // Add SSL 465 fallback (unless that's already configured)
        if (configuredPort != 465) {
            Attempt ssl465 = new Attempt(); ssl465.host = configuredHost; ssl465.port = 465; ssl465.ssl = true; ssl465.startTls = false; ssl465.label = "ssl465"; add.apply(ssl465);
        }
        // STARTTLS 587 (generic) if not already present
        if (!attemptsMap.values().stream().anyMatch(a -> a.port == 587 && a.startTls)) {
            Attempt stls = new Attempt(); stls.host = configuredHost; stls.port = 587; stls.ssl = false; stls.startTls = true; stls.label = "starttls587"; add.apply(stls);
        }
        // Plain 25 fallback
        Attempt plain25 = new Attempt(); plain25.host = configuredHost; plain25.port = 25; plain25.ssl = false; plain25.startTls = false; plain25.label = "plain25"; add.apply(plain25);

        java.util.List<Attempt> attempts = new java.util.ArrayList<>(attemptsMap.values());

        for (Attempt a : attempts) {
            JavaMailSenderImpl impl = new JavaMailSenderImpl();
            impl.setHost(a.host);
            impl.setPort(a.port);
            impl.setUsername(configuredSender);
            impl.setPassword(configuredPassword);
            impl.setProtocol(configuredProtocol);

            java.util.Properties props = impl.getJavaMailProperties();
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.from", configuredSender);
            props.put("mail.smtp.ssl.enable", String.valueOf(a.ssl));
            props.put("mail.smtp.starttls.enable", String.valueOf(a.startTls));
            if (a.startTls) {
                props.put("mail.smtp.starttls.required", "true");
            }
            props.put("mail.debug", "false");
            
            // Add timeout settings to prevent hanging
            props.put("mail.smtp.connectiontimeout", "10000"); // 10 seconds
            props.put("mail.smtp.timeout", "10000"); // 10 seconds
            props.put("mail.smtp.writetimeout", "10000"); // 10 seconds

            log.info("Trying mail send using host={}, port={}, ssl={}, starttls={}, label={}", a.host, a.port, a.ssl, a.startTls, a.label);
            try {
                impl.send(message);
                log.info("✅ SUCCESS: Email sent to {} (subject={}) via {}:{}", to, subject, a.host, a.port);
                return true;
            } catch (org.springframework.mail.MailAuthenticationException mex) {
                log.error("❌ AUTHENTICATION FAILED when sending email via {}:{} - {}", a.host, a.port, mex.getMessage());
                log.error("   Check MAIL_USERNAME and MAIL_PASSWORD are correct");
                // try next transport
            } catch (Exception ex) {
                log.error("❌ FAILED to send email via {}:{} - {}: {}", a.host, a.port, ex.getClass().getSimpleName(), ex.getMessage());
            }
        }

        log.error("❌ ALL MAIL SEND ATTEMPTS FAILED for subject={}", subject);
        log.error("💡 Possible issues:");
        log.error("   1. Incorrect MAIL_USERNAME or MAIL_PASSWORD");
        log.error("   2. AWS WorkMail account not activated");
        log.error("   3. Domain {} not verified in AWS WorkMail", configuredSender.split("@")[1]);
        log.error("   4. Sending limits exceeded");
        return false;
    }

    /**
     * Test SMTP connection without sending emails
     */
    public java.util.Map<String, Object> testSmtpConnection() {
        java.util.Map<String, Object> result = new java.util.HashMap<>();
        result.put("host", configuredHost);
        result.put("port", configuredPort);
        result.put("username", configuredSender);
        result.put("passwordConfigured", configuredPassword != null && !configuredPassword.trim().isEmpty());
        result.put("passwordLength", configuredPassword != null ? configuredPassword.length() : 0);
        
        java.util.List<java.util.Map<String, Object>> attempts = new java.util.ArrayList<>();
        
        // Test different transport configurations similar to sendContactEmail
        Attempt[] configs = {
            createAttempt(configuredHost, 587, false, true, "office365-starttls"),
            createAttempt(configuredHost, 465, true, false, "office365-ssl"),
            createAttempt(configuredHost, 25, false, false, "office365-plain")
        };
        
        for (Attempt attempt : configs) {
            java.util.Map<String, Object> attemptResult = new java.util.HashMap<>();
            attemptResult.put("host", attempt.host);
            attemptResult.put("port", attempt.port);
            attemptResult.put("ssl", attempt.ssl);
            attemptResult.put("starttls", attempt.startTls);
            attemptResult.put("label", attempt.label);
            
            try {
                JavaMailSenderImpl impl = new JavaMailSenderImpl();
                impl.setHost(attempt.host);
                impl.setPort(attempt.port);
                impl.setUsername(configuredSender);
                impl.setPassword(configuredPassword);
                impl.setProtocol(configuredProtocol);

                java.util.Properties props = impl.getJavaMailProperties();
                props.put("mail.smtp.auth", "true");
                props.put("mail.smtp.from", configuredSender);
                props.put("mail.smtp.ssl.enable", String.valueOf(attempt.ssl));
                props.put("mail.smtp.starttls.enable", String.valueOf(attempt.startTls));
                if (attempt.startTls) {
                    props.put("mail.smtp.starttls.required", "true");
                }
                props.put("mail.debug", "false");
                
                // Add timeout settings
                props.put("mail.smtp.connectiontimeout", "5000"); // 5 seconds for testing
                props.put("mail.smtp.timeout", "5000");
                props.put("mail.smtp.writetimeout", "5000");
                
                // Test connection
                impl.testConnection();
                attemptResult.put("status", "SUCCESS");
                attemptResult.put("message", "Authentication and connection successful");
                
            } catch (org.springframework.mail.MailAuthenticationException ex) {
                attemptResult.put("status", "AUTH_FAILED");
                attemptResult.put("error", "MailAuthenticationException");
                attemptResult.put("message", "Authentication failed: " + ex.getMessage());
                attemptResult.put("suggestion", "Check username/password or enable app-specific passwords");
            } catch (Exception ex) {
                attemptResult.put("status", "CONNECTION_FAILED");
                attemptResult.put("error", ex.getClass().getSimpleName());
                attemptResult.put("message", ex.getMessage());
            }
            
            attempts.add(attemptResult);
        }
        
        result.put("attempts", attempts);
        result.put("timestamp", java.time.Instant.now().toString());
        result.put("microsoftOffice365Info", getMicrosoftSmtpInfo());
        
        return result;
    }

    private Attempt createAttempt(String host, int port, boolean ssl, boolean startTls, String label) {
        Attempt a = new Attempt();
        a.host = host;
        a.port = port;
        a.ssl = ssl;
        a.startTls = startTls;
        a.label = label;
        return a;
    }

    private java.util.Map<String, Object> getMicrosoftSmtpInfo() {
        java.util.Map<String, Object> info = new java.util.HashMap<>();
        info.put("recommendedSettings", java.util.Map.of(
            "host", "smtp.office365.com",
            "port", 587,
            "encryption", "STARTTLS",
            "authentication", "OAuth2 or App Password"
        ));
        info.put("commonIssues", java.util.List.of(
            "Basic authentication may be disabled - use app-specific passwords",
            "Multi-factor authentication blocks regular passwords", 
            "Security defaults in Microsoft 365 disable basic auth",
            "SMTP AUTH may be disabled for the mailbox"
        ));
        info.put("howToCreateAppPassword", "https://support.microsoft.com/en-us/account-billing/create-app-passwords-for-apps-that-can-t-use-two-step-verification-5896ed9b-4263-e681-128a-a6f2979a7944");
        return info;
    }
}
