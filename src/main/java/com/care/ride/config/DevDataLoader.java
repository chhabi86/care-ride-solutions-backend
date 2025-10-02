package com.care.ride.config;

import com.care.ride.domain.ServiceType;
import com.care.ride.repo.ServiceTypeRepo;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
// @Profile("default") // Remove profile restriction to run in all environments
public class DevDataLoader implements CommandLineRunner {
    private final ServiceTypeRepo serviceTypeRepo;

    public DevDataLoader(ServiceTypeRepo serviceTypeRepo) {
        this.serviceTypeRepo = serviceTypeRepo;
    }

    @Override
    public void run(String... args) throws Exception {
        if (serviceTypeRepo.count() == 0) {
            // Create comprehensive service types matching frontend
            String[][] services = {
                {"Doctor's Appointments", "Safe, timely rides for medical appointments"},
                {"Hospital Visits", "Reliable transportation for emergency and scheduled hospital visits"},
                {"Physical Therapy Sessions", "Comfortable rides to and from physical therapy sessions"},
                {"Dialysis Treatment", "Dependable service for regular dialysis appointments"},
                {"Chemotherapy Sessions", "Supportive rides to chemotherapy treatments"},
                {"Radiation Therapy", "Safe transport for ongoing radiation therapy sessions"},
                {"Medical Testing", "Easy access to labs and testing appointments"},
                {"Surgery or Procedures", "Pre- and post-surgery transportation for procedures"},
                {"Follow-Up Appointments", "Reliable rides for all post-surgery follow-ups"},
                {"Hospital Discharge", "Safe rides home after hospital or rehab stays"},
                {"Specialized Care", "Transportation to/from nursing or specialized care facilities"},
                {"Ongoing Therapy", "Consistent rides for ongoing therapy and treatment"}
            };
            
            for (String[] service : services) {
                var st = new ServiceType();
                st.setName(service[0]);
                st.setDescription(service[1]);
                serviceTypeRepo.save(st);
                System.out.println("DevDataLoader: inserted ServiceType '" + service[0] + "' id=" + st.getId());
            }
            
            System.out.println("DevDataLoader: Created " + services.length + " service types");
        } else {
            System.out.println("DevDataLoader: service types exist: " + serviceTypeRepo.count());
        }
    }
}
