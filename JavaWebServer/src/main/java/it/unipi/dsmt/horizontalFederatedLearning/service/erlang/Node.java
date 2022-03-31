package it.unipi.dsmt.horizontalFederatedLearning.service.erlang;

import com.ericsson.otp.erlang.*;
import java.io.IOException;

public class Node {
    private static volatile Node instance;
    private OtpNode otpNode;
    private OtpSelf caller;

    private Node(){
        try{
            otpNode = new OtpNode("server@127.0.0.1", "COOKIE");
            caller = new OtpSelf("caller", "COOKIE");
        } catch (IOException e){
            e.printStackTrace();
        }
    }

    //Singleton Pattern
    public static Node getNode() {
        if (instance == null) {
            synchronized (Node.class) {
                if (instance == null) {
                    instance = new Node();
                }
            }
        }
        return instance;
    }

    public OtpNode getOtpNode() {
        return otpNode;
    }

    public OtpSelf getCaller(){
        return caller;
    }

}


