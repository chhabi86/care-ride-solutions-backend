package com.care.ride.web;

import com.care.ride.domain.*;
import com.care.ride.dto.BookingRequest;
import com.care.ride.dto.ContactRequest;
import com.care.ride.domain.Contact;
import com.care.ride.repo.ContactRepo;
import com.care.ride.service.EmailService;
import com.care.ride.repo.*;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins={
	"http://localhost:4200",
	"http://127.0.0.1:4201",
	"http://careridesolutionspa.com",
	"https://careridesolutionspa.com",
	"http://www.careridesolutionspa.com",
	"https://www.careridesolutionspa.com"
})
public class PublicController {
	private final ServiceTypeRepo sRepo;
	private final BookingRepo bRepo;
	private final EmailService emailService;
	private final ContactRepo contactRepo;
	@Value("${mail.notify:${MAIL_NOTIFY:${MAIL_FROM:${MAIL_USERNAME:info@careridesolutionspa.com}}}}")
	private String notifyRecipient;

	public PublicController(ServiceTypeRepo sRepo, BookingRepo bRepo, EmailService emailService, ContactRepo contactRepo){
		this.sRepo = sRepo;
		this.bRepo = bRepo;
		this.emailService = emailService;
		this.contactRepo = contactRepo;
	}
	@PostMapping("/contact")
	public ResponseEntity<?> contact(@RequestBody @Valid ContactRequest req) {
		long start = System.currentTimeMillis();
		try {
			System.out.println("[contact] inbound payload email="+req.getEmail()+" reason="+req.getReason()+" notifyRecipient="+notifyRecipient);
			int approxSize = (req.getMessage() != null ? req.getMessage().length() : 0) +
					(req.getName() != null ? req.getName().length() : 0);
			// Persist contact to DB
			Contact c = new Contact();
			c.setName(req.getName());
			c.setEmail(req.getEmail());
			c.setPhone(req.getPhone());
			c.setReason(req.getReason());
			c.setMessage(req.getMessage());
			var saved = contactRepo.save(c);
			System.out.println("[contact] saved id="+saved.getId()+" size="+approxSize);

			// Compose email body
			String subject = "New Contact Form Submission: " + req.getReason();
			String text = "Name: " + req.getName() + "\n"
					+ "Email: " + req.getEmail() + "\n"
					+ "Phone: " + req.getPhone() + "\n"
					+ "Reason: " + req.getReason() + "\n"
					+ "Message: " + req.getMessage();

			// Send email asynchronously
			java.util.concurrent.CompletableFuture.runAsync(() -> {
				try {
					boolean emailOk = emailService.sendContactEmail(notifyRecipient, subject, text);
					System.out.println("[contact] async email result id="+saved.getId()+" ok="+emailOk);
				} catch (Exception e) {
					System.err.println("[contact] async email failure id="+saved.getId()+" msg="+e.getMessage());
				}
			});

			long dur = System.currentTimeMillis() - start;
			return ResponseEntity.ok(java.util.Map.of(
					"status","sent",
					"id", saved.getId(),
					"emailStatus", true,
					"durationMs", dur));
		} catch (Exception ex) {
			long dur = System.currentTimeMillis() - start;
			System.err.println("[contact] ERROR durationMs="+dur+" type="+ex.getClass().getSimpleName()+" msg="+ex.getMessage());
			ex.printStackTrace();
			return ResponseEntity.status(500).body(java.util.Map.of(
					"error","CONTACT_SAVE_FAILED",
					"type", ex.getClass().getSimpleName(),
					"message", ex.getMessage(),
					"durationMs", dur));
		}
	}

	@GetMapping("/ping")
	public java.util.Map<String,Object> ping() {
		return java.util.Map.of("status","ok","ts",System.currentTimeMillis());
	}

	@GetMapping("/services")
	public List<ServiceType> services(){
		return sRepo.findAll();
	}

	@PostMapping("/bookings")
	public ResponseEntity<?> create(@RequestBody @Valid BookingRequest req){
		var maybeSt = sRepo.findById(req.serviceTypeId());
		if (maybeSt.isEmpty()){
			return ResponseEntity.badRequest().body(java.util.Map.of("error","serviceTypeId not found"));
		}
		var st = maybeSt.get();
		var b = new Booking();
		b.setFullName(req.fullName());
		b.setPhone(req.phone());
		b.setEmail(req.email());
		b.setPickupAddress(req.pickupAddress());
		b.setDropoffAddress(req.dropoffAddress());
		b.setPickupTime(req.pickupTime());
		b.setNotes(req.notes());
		b.setServiceType(st);
		var saved = bRepo.save(b);

		// Compose booking email
		String subject = "New Ride Booking: " + req.fullName();
		StringBuilder text = new StringBuilder();
		text.append("A new ride booking has been submitted.\n\n");
		text.append("Full Name: ").append(req.fullName()).append("\n");
		text.append("Phone: ").append(req.phone()).append("\n");
		if (req.email() != null && !req.email().isEmpty()) text.append("Email: ").append(req.email()).append("\n");
		text.append("Pickup Address: ").append(req.pickupAddress()).append("\n");
		text.append("Drop-off Address: ").append(req.dropoffAddress()).append("\n");
		text.append("Pickup Time: ").append(req.pickupTime()).append("\n");
		text.append("Service Type ID: ").append(req.serviceTypeId()).append("\n");
		if (req.notes() != null && !req.notes().isEmpty()) text.append("Notes: ").append(req.notes()).append("\n");

		boolean emailOk = emailService.sendContactEmail(notifyRecipient, subject, text.toString());
		if (!emailOk) {
			System.err.println("Warning: email send failed for booking id=" + saved.getId());
		}

		// include emailStatus so UI can show helpful message
		return ResponseEntity.created(URI.create("/api/bookings/"+saved.getId())).body(java.util.Map.of("booking", saved, "emailStatus", emailOk));
	}

	@GetMapping("/debug/smtp")
	public ResponseEntity<?> debugSmtp() {
		try {
			java.util.Map<String, Object> result = emailService.testSmtpConnection();
			return ResponseEntity.ok(result);
		} catch (Exception e) {
			return ResponseEntity.status(500).body(java.util.Map.of(
					"error", "SMTP_DEBUG_FAILED",
					"message", e.getMessage(),
					"type", e.getClass().getSimpleName()
			));
		}
	}
}