package com.care.ride.config;

import com.care.ride.domain.ServiceType;
import com.care.ride.repo.ServiceTypeRepo;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("default")
public class DevDataLoader implements CommandLineRunner {
    private final ServiceTypeRepo serviceTypeRepo;

    public DevDataLoader(ServiceTypeRepo serviceTypeRepo) {
        this.serviceTypeRepo = serviceTypeRepo;
    }

    @Override
    public void run(String... args) throws Exception {
        if (serviceTypeRepo.count() == 0) {
            var st = new ServiceType();
            st.setName("Standard");
            st.setDescription("Standard care ride service");
            serviceTypeRepo.save(st);
            System.out.println("DevDataLoader: inserted default ServiceType id=" + st.getId());
        } else {
            System.out.println("DevDataLoader: service types exist: " + serviceTypeRepo.count());
        }
    }
}
