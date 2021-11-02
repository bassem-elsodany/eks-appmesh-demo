package com.epam.aws.mesh.echoserver.exceptionhandler;

public class ServerNotFoundException extends Exception {
    private String serverName;

    public static ServerNotFoundException createWith(String serverName) {
        return new ServerNotFoundException(serverName);
    }

    private ServerNotFoundException(String serverName) {
        this.serverName = serverName;
    }

    @Override
    public String getMessage() {
        return "Server '" + serverName + "' not found";
    }
}