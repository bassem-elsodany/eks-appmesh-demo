FROM openjdk:11-jdk-slim
MAINTAINER epam.com

# Install prerequisites
RUN apt-get update && apt-get install -y curl


COPY target/echo-server-1.0.0.jar echo-server.jar
ENTRYPOINT ["java","-jar","/echo-server.jar"]