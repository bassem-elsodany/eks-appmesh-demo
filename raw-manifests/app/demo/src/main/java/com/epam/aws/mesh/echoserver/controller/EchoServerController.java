package com.epam.aws.mesh.echoserver.controller;


import com.epam.aws.mesh.echoserver.exceptionhandler.ServerNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.RequestEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.net.UnknownHostException;

@RestController
public class EchoServerController {

    private static final Logger LOGGER = LoggerFactory.getLogger(EchoServerController.class);

    private final RestTemplate restTemplate;

    @Value("${country}")
    private String country;

    @Value("${server.port}")
    private String port;

    public EchoServerController(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @GetMapping("/")
    public String getMessage() {
        String message="ECHO server is: "+country +System.getProperty("line.separator");
        LOGGER.info(message);
        return message;
    }

    @GetMapping("/servers/{destinationEcho}")
    public String getMessageFromDestination(@PathVariable String destinationEcho) throws ServerNotFoundException {
        String destinationHostResponse=fetchHostResponseById(destinationEcho);
        LOGGER.info("destination message: "+destinationHostResponse);
        String message=country+" Echo server invoked "+destinationEcho+", and the output is "+destinationHostResponse+System.getProperty("line.separator");
        LOGGER.info("returned message: "+message);
        return message;
    }

    private String fetchHostResponseById(String hostId) throws ServerNotFoundException {

        try {
            URI uri = UriComponentsBuilder
                    .fromUriString("http://{hostId}:{port}/")
                    .build(hostId,port);
            RequestEntity<Void> requestEntity = RequestEntity
                    .get(uri)
                    .build();
            return restTemplate.exchange(requestEntity, String.class).getBody();
        }catch (RestClientException restClientException){
            LOGGER.error("Error while invoking the endpoint",restClientException);
            throw ServerNotFoundException.createWith(hostId+":"+port);
        }
    }

    @GetMapping("/ping")
    public String ping() {
        return country+" ECHO service is up and running";
    }

}
