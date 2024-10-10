import ballerina/http;
import ballerina/data.jsondata;
import ballerina/log;
import ballerina/sql;
import ballerinax/java.jdbc;
import ballerinax/mysql.driver as _;
import stakeholder_management_api.engagement_metrics;
import stakeholder_management_api.relation_depth_analysis;
import stakeholder_management_api.risk_modeling;
import stakeholder_management_api.stakeholder_equilibrium;

service /stakeholder\-analytics on new http:Listener(9090) {
    final sql:Client dbClient;

    function init() returns error? {
        self.dbClient = check new jdbc:Client(jdbcUrl);
        check initDatabase(self.dbClient);
    }

    // Function to check if the provided API key is valid
    function isValidApiKey(string apiKey) returns boolean {
        stream<record {}, sql:Error?> resultStream = self.dbClient->query(ifUserExistByAPIKey(apiKey));
        do {
            record {}? existingUser = check resultStream.next();

            if existingUser is record {} {
                return true;
            }
        } on fail var e {
            log:printError("Checking user exist fail: " + e.toBalString());
        }
        return false;
    }

    resource function post register(http:Caller caller, APIReg apireg) returns error? {
        // Check if user already exists in the database
        stream<record {}, sql:Error?> resultStream = self.dbClient->query(ifKeyNameExist(apireg.keyName));
        record {}? existingKeyName = check resultStream.next();

        if existingKeyName is record {} {
            check caller->respond("Key name already exist");
            log:printError("Duplicate key name: " + apireg.keyName);
            return;
        }

        string apiKey = generateApiKey();
        sql:ExecutionResult _ = check self.dbClient->execute(insertUserApi(apireg, apiKey));

        json response = {apiKey: apiKey};
        check caller->respond(response);

        log:printInfo("New user registered: " + apireg.username);
    }

    resource function get data(http:Caller caller, http:Request req) returns error? {
        string|error apiKey = req.getHeader("x-api-key");
        if (apiKey is error || !self.isValidApiKey(apiKey)) {
            // Create a response object with a 401 Unauthorized status code
            log:printError("Check authorize fail: "+check apiKey);
            http:Response unauthorizedResponse = new;
            unauthorizedResponse.statusCode = http:STATUS_UNAUTHORIZED;
            unauthorizedResponse.setPayload("Unauthorized");
            check caller->respond(unauthorizedResponse);
            return;
        }

        json data = {message: "This is protected data!"};
        check caller->respond(data);
    }

    resource function put rotateKey(http:Caller caller, http:Request req) returns error? {
        string|error apiKey = req.getHeader("x-api-key");
        if (apiKey is error || !self.isValidApiKey(apiKey)) {
            http:Response unauthorizedResponse = new;
            unauthorizedResponse.statusCode = http:STATUS_UNAUTHORIZED;
            unauthorizedResponse.setPayload("Unauthorized");
            check caller->respond(unauthorizedResponse);
            return;
        }

        string newApiKey = generateApiKey();
        sql:ExecutionResult _ = check self.dbClient->execute(updateAPIKey(apiKey, newApiKey));

        json response = {apiKey: newApiKey};
        check caller->respond(response);
    }

    

    //engagement-metrics functions start
    //*****************************************//

    //calculate priority score
    resource function post calculate_eps(http:Caller caller, engagement_metrics:EPSInput epsInput) returns error? {
        float EPSi = engagement_metrics:calculateEngamentPriorityScore(epsInput);

        string priority = engagement_metrics:determinePriority(EPSi);

        json epsResult = {
            "EPSi": EPSi,
            "priority": priority
        };

        check caller->respond(epsResult);
    }

    //calculate balanced score metrics
    resource function post calculate_bsc(http:Caller caller, engagement_metrics:BSCInput bscInput) returns error? {
        
        float BSCi = engagement_metrics:calculateBalancedScoreMetrics(bscInput);

        string decision = engagement_metrics:makeDecisionBasedOnBSCi(BSCi);

        json bscResult = {
            "BSCi": BSCi,
            "decision": decision
        };

        check caller->respond(bscResult);
    }

    //calculate total engament score
    resource function post calculate_tes(http:Caller caller, engagement_metrics:TESInput tesInput) returns error? {
        float TESi = engagement_metrics:calculateTotalEngagementScore(tesInput);

        string priority = engagement_metrics:makeDecisionBasedOnTES(TESi);

        json tesResult = {
            "TESi": TESi,
            "priority": priority
        };

        check caller->respond(tesResult);
    }
    //engagement-metrics functions end
    //*****************************************//

    //relation-depth-analysis functions start
    //*****************************************//
    resource function post analytics(http:Caller caller, relation_depth_analysis:SEmetrics se_metrics) returns error? {

        relation_depth_analysis:stakeholderType? stakeholderEnumType = null;
        if (se_metrics.stakeholder_type is string) {
            match se_metrics.stakeholder_type.toString().toUpperAscii() {
                "EMPLOYEE" => {
                    stakeholderEnumType = relation_depth_analysis:EMPLOYEE;
                }
                "INVESTOR" => {
                    stakeholderEnumType = relation_depth_analysis:INVESTOR;
                }
                "DIRECTOR" => {
                    stakeholderEnumType = relation_depth_analysis:DIRECTOR;
                }
                "CLIENT" => {
                    stakeholderEnumType = relation_depth_analysis:CLIENT;
                }
                "COMPETITOR" => {
                    stakeholderEnumType = relation_depth_analysis:COMPETITOR;
                }
                "AUDITOR" => {
                    stakeholderEnumType = relation_depth_analysis:AUDITOR;
                }
                "GOVERMENT_AGENT" => {
                    stakeholderEnumType = relation_depth_analysis:GOVERMENT_AGENT;
                }
                "" => {
                    stakeholderEnumType = relation_depth_analysis:GOVERMENT_AGENT;
                }
                _ => {
                    // return error relation_depth_analysis:InvalidTypeException("Invalid stakeholder type");
                }
            }
        }

        relation_depth_analysis:InfluenceIndexResult|error result = 
        relation_depth_analysis:stakeholder_influence_index(se_metrics.power, se_metrics.legitimacy, se_metrics.urgency, stakeholderEnumType);
        
        check caller->respond(result);
    }

    resource function post gt_analytics(http:Caller caller, relation_depth_analysis:CustomTable customTable) returns error? {
        relation_depth_analysis:GameTheoryResult|error result = relation_depth_analysis:game_theory_cal(customTable);
        check caller->respond(result);
    }

     resource function post relationshipValue(http:Caller caller, http:Request req) returns error? {
        json inputJson = check req.getJsonPayload();
        relation_depth_analysis:StakeholderRelation relation = check 
        inputJson.cloneWithType(relation_depth_analysis:StakeholderRelation);

        // Call the relationshipValueCal function and handle errors
        relation_depth_analysis:RelationResult|error result = relation_depth_analysis:relationshipValueCal(relation);

        if (result is error) {
            // Handle the error case and respond with a meaningful message
            json errorResponse = {
                "status": "error",
                "message": "Invalid input values",
                "details": {
                    "benefit": relation.benefit,
                    "cost": relation.cost,
                    "hint": "Benefit must be positive and cost cannot be negative."
                }
            };
            check caller->respond(errorResponse);
        } else {
            // Handle the success case and respond with the result
            check caller->respond(result.toJson());
        }
    }
    //relation-depth-analysis functions end
    //*****************************************//

    //risk-modeling functions start
    //*****************************************//
    //Risk Score
    resource function post calculate_risk_score(http:Caller caller, risk_modeling:RiskInput riskInput) returns error? {
        // Validation
        if (riskInput.Si < 0.0 || riskInput.Si > 1.0 || riskInput.Ei < 0.0 || riskInput.Ei > 1.0) {
            json errorResponse = {"error": "Satisfaction and Engagement levels must be between 0 and 1"};
            check caller->respond(errorResponse);
            return;
        }

        float riskScore = risk_modeling:calculate(riskInput);

        string riskLevel = risk_modeling:pretendRiskLevel(riskScore);

        json response = {
            "riskScore": riskScore,
            "riskLevel": riskLevel
        };

        check caller->respond(response);
    }

    //Total Project Risk
    resource function post calculate_project_risk(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();

        risk_modeling:RiskInput[] riskInputs = check jsondata:parseAsType(check payload.riskInputs);
        float[] influences = check jsondata:parseAsType(check payload.influences);

        float|error totalRisk = risk_modeling:calculateProjectRisk(riskInputs, influences);

        if (totalRisk is float) {
            string riskLevel = risk_modeling:pretendProjectRiskLevel(totalRisk);
          
            json response = {
                "totalProjectRisk": totalRisk,
                "riskLevel": riskLevel,
                "action": risk_modeling:determineAction(riskLevel)
            };

            check caller->respond(response);
        } else {
            json errorResponse = {"error": totalRisk.message()};
            check caller->respond(errorResponse);
        }
    }

    //Engagement Drop Alert
    resource function post engagement_drop_alert(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();

        risk_modeling:RiskInput[] riskInputs = check jsondata:parseAsType(check payload.riskInputs);
        float engamenetTreshold = check payload.Te;

        json[] edaResults = [];

        foreach var riskInput in riskInputs {
            json stakeholderResult = risk_modeling:calculateEDA(riskInput, engamenetTreshold);
            edaResults.push(stakeholderResult);
        }

        json response = {
            "engagementDropAlerts": edaResults
        };

        check caller->respond(response);
    }
    //risk-modeling functions end
    //*****************************************//

    //stakeholder-equilibrium functions start
    //*****************************************//
    // Calculate SIM
    resource function post calculate_sim(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();

        // Ensure the 'stakeholders' field is present and is of type json
        json stakeholdersJson = check payload.stakeholders;

        // Parse the 'stakeholders' field in the JSON payload
        stakeholder_equilibrium:Stakeholder[] stakeholders = check jsondata:parseAsType(stakeholdersJson);

        // float[][] SIM = stakeholder_equilibrium:buildStakeholderInfluenceMatrix(stakeholders);
        json detailedSIM = stakeholder_equilibrium:buildStakeholderInfluenceMatrixDetailed(stakeholders);

        // json response = { "Stakeholder Influence Matrix (SIM)": SIM };
        // check caller->respond(response);
        check caller->respond(detailedSIM);
    }

    // Calculate DSI
    resource function post calculate_dsi(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();
        stakeholder_equilibrium:Stakeholder[] stakeholders = check jsondata:parseAsType(check payload.stakeholders);
        float[] deltaBehavior = check jsondata:parseAsType(check payload.deltaBehavior);

        // float[] DSI = stakeholder_equilibrium:calculateDynamicStakeholderImpact(stakeholders, deltaBehavior);

        // json response = {
        //     "Dynamic Stakeholder Impact (DSI)": DSI
        // };

        // check caller->respond(response);

        json detailedDSI = stakeholder_equilibrium:calculateDynamicStakeholderImpactDetailed(stakeholders, deltaBehavior);

        check caller->respond(detailedDSI);
    }

    // Calculate SNS
    resource function post calculate_sns(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();
        stakeholder_equilibrium:Stakeholder[] stakeholders = check jsondata:parseAsType(check payload.stakeholders);
        float[] deltaBehavior = check jsondata:parseAsType(check payload.deltaBehavior);

        // float SNS = stakeholder_equilibrium:calculateStakeholderNetworkStability(stakeholders, deltaBehavior);

        // json response = {
        //     "Stakeholder Network Stability (SNS)": SNS
        // };

        // check caller->respond(response);

        json detailedSNS = stakeholder_equilibrium:calculateStakeholderNetworkStabilityDetailed(stakeholders, deltaBehavior);

        check caller->respond(detailedSNS);
    }

    // Calculate SIS
    resource function post calculate_sis(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();

        // Ensure the 'stakeholders' field is present and is of type json
        json stakeholdersJson = check payload.stakeholders;

        // Parse the 'stakeholders' field in the JSON payload
        stakeholder_equilibrium:Stakeholder[] stakeholders = check jsondata:parseAsType(stakeholdersJson);

        // float[] SIS = stakeholder_equilibrium:calculateSystemicInfluenceScore(stakeholders);

        // json response = {
        //     "Systemic Influence Score (SIS)": SIS
        // };

        // check caller->respond(response); //end

        json detailedSIS = stakeholder_equilibrium:calculateSystemicInfluenceScoreDetailed(stakeholders);

        check caller->respond(detailedSIS);
    }
    //stakeholder-equilibrium functions end
    //*****************************************//
}
