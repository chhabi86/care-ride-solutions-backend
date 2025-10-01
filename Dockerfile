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
# copy war produced by maven (Spring Boot WAR can be run with java -jar)
COPY --from=builder /build/target/*.war app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
