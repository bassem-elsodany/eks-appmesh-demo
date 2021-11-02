package com.epam.aws.mesh.echoserver;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.web.client.RestTemplate;

@SpringBootApplication
public class EchoServerApplication {

	private static final Logger log = LoggerFactory.getLogger(EchoServerApplication.class);
	public static void main(String[] args) {
		SpringApplication.run(EchoServerApplication.class, args);
	}


}
