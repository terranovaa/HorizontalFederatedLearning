<%@ page import="it.unipi.dsmt.horizontalFederatedLearning.entities.Experiment" %>
<%@ page import="it.unipi.dsmt.horizontalFederatedLearning.entities.KMeansAlgorithm" %>
<%@ page contentType="text/html;charset=UTF-8" %>
<% Experiment experiment = (Experiment) request.getAttribute("experiment"); %>
<!DOCTYPE html>
<html>
<head>
    <title>Experiment Info Page</title>
    <style>
        <%@include file="../../style/css/style.css" %>
    </style>
</head>
<body>
<div id="menu">
    <button><a href="<%=request.getContextPath()%>/Home">Home</a></button>
    <button><a href="<%=request.getContextPath()%>/History">History</a></button>
    <button><a href="<%=request.getContextPath()%>/Settings">Settings</a></button>
    <button><a href="<%=request.getContextPath()%>/Logout">Logout</a></button>
</div>
<div id="options">
    <form action="<%=request.getContextPath()%>/History">
        <button type="submit" name="action" value="back">Back</button>
    </form>
    <form action="<%=request.getContextPath()%>/ExperimentInfo" method="post">
        <input type="hidden" id="id" name="id" value="<%=experiment.getId()%>">
        <label for="name">Name: </label><input id="name" name="name" value="<%=experiment.getName()%>"><br>
        <label for="dataset">Dataset: </label><input id="dataset" name="dataset" type="text"
                                                     value="<%=experiment.getDataset()%>"><br>
        <label for="numFeatures">Number of Features: </label><input id="numFeatures" name="numFeatures" type="number"
                                                                    value="<%=experiment.getNumFeatures()%>"><br>
        <label for="mode">Mode: </label><input id="mode" name="mode" value="<%=experiment.getMode()%>" readonly><br>
        <label for="creationDate">Creation Date: </label><input id="creationDate" name="creationDate" type="text"
                                                                value="<%=experiment.getCreationDate()%>" readonly><br>
        <label for="lastUpdateDate">Last Update Date: </label><input id="lastUpdateDate" name="lastUpdateDate"
                                                                     type="text"
                                                                     value="<%=experiment.getLastUpdateDate()%>"
                                                                     readonly><br>
        <label for="user">User: </label><input id="user" name="username" value="<%=experiment.getUser().getUsername()%>"
                                               readonly><br>
        <label for="numRounds">Number of rounds: </label><input id="numRounds" name="numRounds"
                                                                value="<%=experiment.getNumRounds()%>" readonly><br>
        <label for="maxNumRounds">Maximum number of rounds: </label><input id="maxNumRounds" name="maxNumRounds"
                                                                           type="number"
                                                                           value="<%=experiment.getMaxNumRounds()%>"><br>
        <label for="numCrashes">Number of crashes: </label><input id="numCrashes" name="numCrashes"
                                                                  value="<%=experiment.getNumCrashes()%>" readonly><br>
        <label for="numClients">Number of clients: </label><input id="numClients" name="numClients"
                                                                  value="<%=experiment.getNumClients()%>" readonly><br>
        <label for="numMinClients">Minimum number of clients: </label><input id="numMinClients" name="numMinClients"
                                                                             type="number" min="0"
                                                                             max="<%=experiment.getNumClients()%>"
                                                                             value="<%=experiment.getNumClients()%>"
                                                                             required> / <%=experiment.getNumClients()%>
        <br>
        <label for="clientsHostnames">Clients hostnames: </label><input id="clientsHostnames" name="clientsHostnames"
                                                                        value="<%=String.join(",",experiment.getClientsHostnames())%>"
                                                                        readonly><br>
        <label for="randomClients">Different clients at each round: </label>
        <select name="randomClients" id="randomClients" required>
            <option value="false"
                    <%if (experiment.getRandomClients()) {%>
                    selected
                    <%}%>
            >false
            </option>
            <option value="true"
                    <%if (experiment.getRandomClients()) {%>
                    selected
                    <%}%>
            >true
            </option>
        </select>
        <br>
        <label for="randomClientsSeed">Random clients Seed: </label><input id="randomClientsSeed"
                                                                           name="randomClientsSeed" type="number"
                                                                           value="<%=experiment.getRandomClientsSeed()%>"><br>
        <label for="timeout">Timeout: </label><input id="timeout" type="number" name="timeout"
                                                     value="<%=experiment.getTimeout()%>"><br>
        <label for="maxAttemptsClientCrash">Max Attempt Clients Crash: </label><input id="maxAttemptsClientCrash"
                                                                                      name="maxAttemptsClientCrash"
                                                                                      value="<%=experiment.getMaxAttemptsClientCrash()%>"
                                                                                      readonly><br>
        <label for="maxAttemptsServerCrash">Max Attempt Server Crash: </label><input id="maxAttemptsServerCrash"
                                                                                     name="maxAttemptsServerCrash"
                                                                                     value="<%=experiment.getMaxAttemptsServerCrash()%>"
                                                                                     readonly><br>
        <label for="maxAttemptsOverallCrash">Max Attempt Overall Crash: </label><input id="maxAttemptsOverallCrash"
                                                                                       name="maxAttemptsOverallCrash"
                                                                                       value="<%=experiment.getMaxAttemptsOverallCrash()%>"
                                                                                       readonly><br>
        <label for="algorithmName">Algorithm: </label>
        <select name="algorithmName" id="algorithmName" required>
            <option value="KMeans"
                    <%if (experiment.getAlgorithm().getName().equals("KMeans")) {%>
                    selected
                    <%}%>
            >KMeans
            </option>
        </select>
        <br>
        <% if (experiment.getAlgorithm().getName().equals("KMeans")) {
            KMeansAlgorithm algorithm = (KMeansAlgorithm) experiment.getAlgorithm();
        %>
        <label for="numClusters">Number of Clusters: </label><input id="numClusters" name="numClusters" type="number"
                                                                    value="<%=algorithm.getNumClusters()%>"><br>
        <label for="distance">Distance: </label>
        <select name="distance" id="distance" required>
            <option value="numba_norm">numba_norm</option>
        </select>
        <br>
        <label for="epsilon">Epsilon: </label><input id="epsilon" name="epsilon" type="number" min="0" max="1"
                                                     step="0.01" value="<%=algorithm.getEpsilon()%>"><br>
        <label for="seedCenters">Seed Centers: </label><input id="seedCenters" name="seedCenters" type="number"
                                                              value="<%=algorithm.getSeedCenters()%>"><br>
        <label for="normFn">Norm Fn: </label>
        <select name="normFn" id="normFn" required>
            <option value="norm_fro">norm_fro</option>
        </select>
        <br>
        <label for="FNorm">Result FNorm: </label><input id="FNorm" name="FNorm" value="<%=algorithm.getfNorm()%>"
                                                        readonly><br>
        <label for="centers">Cluster Centers: </label><br><textarea id="centers" name="centers" rows="9" cols="50"
                                                                    readonly><%=algorithm.toStringCenters()%></textarea><br>
        <% } %>
        <br>
        <% if (experiment.getUser().getId() == (int) session.getAttribute("user")) { %>
        <button type="submit" name="action" value="update">Edit Experiment</button>
        <button type="submit" name="action" value="delete">Delete Experiment</button>
        <% } %>
    </form>
</div>
</body>
</html>
