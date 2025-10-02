package com.care.ride.service;

import com.sendgrid.*;
import com.sendgrid.helpers.mail.Mail;
import com.sendgrid.helpers.mail.objects.Content;
import com.sendgrid.helpers.mail.objects.Email;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.Map;
import java.util.HashMap;

@Service
public class SendGridService {
    
    private static final Logger logger = LoggerFactory.getLogger(SendGridService.class);
    
    @Value("${sendgrid.api.key:}")
    private String sendGridApiKey;
    
    @Value("${spring.mail.from:contact@careridesolutionspa.com}")
    private String fromEmail;
    
    public boolean sendEmail(String to, String subject, String text) {
        if (sendGridApiKey == null || sendGridApiKey.trim().isEmpty()) {
            logger.error("SendGrid API key not configured");
            return false;
        }
        
        try {
            logger.info("Attempting to send email via SendGrid from {} to {}", fromEmail, to);
            
            Email from = new Email(fromEmail);
            Email toEmail = new Email(to);
            Content content = new Content("text/plain", text);
            Mail mail = new Mail(from, subject, toEmail, content);
            
            SendGrid sg = new SendGrid(sendGridApiKey);
            Request request = new Request();
            
            request.setMethod(Method.POST);
            request.setEndpoint("mail/send");
            request.setBody(mail.build());
            
            Response response = sg.api(request);
            
            logger.info("SendGrid response - Status: {}, Body: {}, Headers: {}", 
                       response.getStatusCode(), response.getBody(), response.getHeaders());
            
            // SendGrid returns 202 for successful email acceptance
            if (response.getStatusCode() == 202) {
                logger.info("Email sent successfully via SendGrid");
                return true;
            } else {
                logger.error("SendGrid failed with status code: {}, body: {}", 
                           response.getStatusCode(), response.getBody());
                return false;
            }
            
        } catch (IOException e) {
            logger.error("SendGrid IOException: {}", e.getMessage(), e);
            return false;
        } catch (Exception e) {
            logger.error("Unexpected error sending email via SendGrid: {}", e.getMessage(), e);
            return false;
        }
    }
    
    public Map<String, Object> testSendGridConnection() {
        Map<String, Object> result = new HashMap<>();
        result.put("service", "SendGrid HTTP API");
        result.put("apiKeyConfigured", sendGridApiKey != null && !sendGridApiKey.trim().isEmpty());
        result.put("apiKeyLength", sendGridApiKey != null ? sendGridApiKey.length() : 0);
        result.put("fromEmail", fromEmail);
        
        if (sendGridApiKey == null || sendGridApiKey.trim().isEmpty()) {
            result.put("status", "API_KEY_MISSING");
            result.put("errorMessage", "SendGrid API key not configured");
            return result;
        }
        
        try {
            // Test connection by creating SendGrid client
            SendGrid sg = new SendGrid(sendGridApiKey);
            
            // We can't easily test the connection without sending an email,
            // but we can verify the API key format
            if (sendGridApiKey.startsWith("SG.") && sendGridApiKey.length() > 50) {
                result.put("status", "CONNECTION_OK");
                result.put("message", "SendGrid API key appears valid");
            } else {
                result.put("status", "INVALID_API_KEY");
                result.put("errorMessage", "API key format appears invalid (should start with 'SG.')");
            }
            
        } catch (Exception e) {
            result.put("status", "CONNECTION_ERROR");
            result.put("errorMessage", e.getMessage());
            logger.error("SendGrid connection test failed: {}", e.getMessage(), e);
        }
        
        return result;
    }
}
