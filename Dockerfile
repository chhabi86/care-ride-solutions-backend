## Multi-stage Dockerfile for care-ride backend
# Stage 1: build with Maven
FROM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /build
# Copy pom first to leverage layer caching for dependencies
COPY pom.xml ./
RUN mvn -B -q dependency:go-offline
# Now copy sources
COPY src ./src
RUN mvn -B -DskipTests package

# Stage 2: runtime image
FROM eclipse-temurin:17-jre
WORKDIR /app
# copy jar produced by maven (uses wildcard to match versioned jar)
COPY --from=builder /build/target/*-backend-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
