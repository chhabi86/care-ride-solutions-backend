package com.care.ride.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.EnvironmentVariableCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;

/**
 * Service for sending emails via Amazon SES HTTP API.
 * This bypasses SMTP port restrictions that may be imposed by cloud providers.
 */
@Service
public class SesApiService {
    private static final Logger log = LoggerFactory.getLogger(SesApiService.class);
    
    @Value("${aws.ses.region:us-east-1}")
    private String awsRegion;
    
    @Value("${aws.ses.from-email:info@careridesolutionspa.com}")
    private String fromEmail;

    /**
     * Send email using AWS SES HTTP API instead of SMTP.
     * This works over standard HTTP/HTTPS ports and bypasses SMTP port blocking.
     */
    public boolean sendEmail(String to, String subject, String textContent) {
        log.info("=== SES API EMAIL SEND ATTEMPT ===");
        log.info("From: {}", fromEmail);
        log.info("To: {}", to);
        log.info("Subject: {}", subject);
        log.info("AWS Region: {}", awsRegion);
        
        try {
            // Create SES client using environment credentials
            SesClient sesClient = SesClient.builder()
                .region(Region.of(awsRegion))
                .credentialsProvider(EnvironmentVariableCredentialsProvider.create())
                .build();
            
            // Build the email message
            Message message = Message.builder()
                .subject(Content.builder()
                    .charset("UTF-8")
                    .data(subject)
                    .build())
                .body(Body.builder()
                    .text(Content.builder()
                        .charset("UTF-8")
                        .data(textContent)
                        .build())
                    .build())
                .build();
            
            // Create the send email request
            SendEmailRequest emailRequest = SendEmailRequest.builder()
                .destination(Destination.builder()
                    .toAddresses(to)
                    .build())
                .message(message)
                .source(fromEmail)
                .build();
            
            // Send the email
            SendEmailResponse response = sesClient.sendEmail(emailRequest);
            
            log.info("✅ Email sent successfully via SES API!");
            log.info("Message ID: {}", response.messageId());
            
            sesClient.close();
            return true;
            
        } catch (SesException e) {
            log.error("❌ SES API error: {} - {}", e.awsErrorDetails().errorCode(), e.awsErrorDetails().errorMessage());
            log.error("💡 Common SES issues:");
            log.error("   1. Verify email address is verified in SES console");
            log.error("   2. Check if AWS credentials are properly configured");
            log.error("   3. Ensure account is out of SES sandbox for sending to unverified emails");
            log.error("   4. Verify IAM permissions include ses:SendEmail");
            return false;
            
        } catch (Exception e) {
            log.error("❌ Unexpected error sending email via SES API: {}", e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * Test SES API connectivity and configuration
     */
    public java.util.Map<String, Object> testSesConnection() {
        java.util.Map<String, Object> result = new java.util.HashMap<>();
        result.put("service", "Amazon SES HTTP API");
        result.put("region", awsRegion);
        result.put("fromEmail", fromEmail);
        
        try {
            // Create SES client
            SesClient sesClient = SesClient.builder()
                .region(Region.of(awsRegion))
                .credentialsProvider(EnvironmentVariableCredentialsProvider.create())
                .build();
            
            // Try to get account send quota (requires minimal permissions)
            GetSendQuotaRequest quotaRequest = GetSendQuotaRequest.builder().build();
            GetSendQuotaResponse quotaResponse = sesClient.getSendQuota(quotaRequest);
            
            result.put("status", "SUCCESS");
            result.put("sendQuota", quotaResponse.max24HourSend());
            result.put("sendUsed", quotaResponse.sentLast24Hours());
            result.put("sendRate", quotaResponse.maxSendRate());
            
            sesClient.close();
            
        } catch (SesException e) {
            result.put("status", "SES_ERROR");
            result.put("errorCode", e.awsErrorDetails().errorCode());
            result.put("errorMessage", e.awsErrorDetails().errorMessage());
            
        } catch (Exception e) {
            result.put("status", "CONNECTION_ERROR");
            result.put("error", e.getClass().getSimpleName());
            result.put("message", e.getMessage());
        }
        
        result.put("timestamp", java.time.Instant.now().toString());
        return result;
    }
}
