package com.care.ride.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Service;


@Service
public class EmailService {
    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

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

        // candidate transports to try: primary configured port/protocol first, then common alternates
        class Attempt { String host; int port; boolean ssl; boolean startTls; }

        java.util.List<Attempt> attempts = new java.util.ArrayList<>();
        Attempt primary = new Attempt(); primary.host = configuredHost; primary.port = configuredPort;
        // assume SSL on 465, otherwise try STARTTLS on 587 and plain on 25
        primary.ssl = (configuredPort == 465);
        primary.startTls = (configuredPort == 587);
        attempts.add(primary);

        Attempt alt1 = new Attempt(); alt1.host = configuredHost; alt1.port = 587; alt1.ssl = false; alt1.startTls = true; attempts.add(alt1);
        Attempt alt2 = new Attempt(); alt2.host = configuredHost; alt2.port = 25; alt2.ssl = false; alt2.startTls = false; attempts.add(alt2);

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
            props.put("mail.debug", "false");

            log.info("Trying mail send using host={}, port={}, ssl={}, starttls={}", a.host, a.port, a.ssl, a.startTls);
            try {
                impl.send(message);
                log.info("Email sent to {} (subject={}) via {}:{}", to, subject, a.host, a.port);
                return true;
            } catch (org.springframework.mail.MailAuthenticationException mex) {
                log.error("Authentication failed when sending email via {}:{} - {}", a.host, a.port, mex.toString());
                // try next transport
            } catch (Exception ex) {
                log.error("Failed to send email via {}:{} - {}", a.host, a.port, ex.toString(), ex);
            }
        }

        log.error("All mail send attempts failed for subject={}", subject);
        return false;
    }
}
