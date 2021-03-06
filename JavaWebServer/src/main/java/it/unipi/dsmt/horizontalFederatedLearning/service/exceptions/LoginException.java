package it.unipi.dsmt.horizontalFederatedLearning.service.exceptions;

public class LoginException extends RuntimeException {

    public LoginException() {
        super("There was an error during login");
    }
    public LoginException(String message) {
        super(message);
    }
}
