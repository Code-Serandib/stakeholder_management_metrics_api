
// Function to calculate Dynamic Stakeholder Impact (DSI)
# Description.
#
# + stakeholders - parameter description  
# + deltaBehavior - parameter description
# + return - return value description
public function calculateDynamicStakeholderImpact(Stakeholder[] stakeholders, float[] deltaBehavior) returns float[] {
    float[][] SIM = buildStakeholderInfluenceMatrix(stakeholders);
    int n = SIM.length();
    float[] DSI = [];

    foreach int j in 0 ..< n {
        float totalImpact = 0;
        foreach int i in 0 ..< n {
            totalImpact += SIM[i][j] * deltaBehavior[i];
        }
        DSI.push(totalImpact);
    }
    return DSI;
}

// Enhanced DSI output with detailed analysis
public function calculateDynamicStakeholderImpactDetailed(Stakeholder[] stakeholders, float[] deltaBehavior) returns json {
    float[] DSI = calculateDynamicStakeholderImpact(stakeholders, deltaBehavior);
    json[] detailedDSI = [];
    
    foreach int i in 0 ..< stakeholders.length() {
        detailedDSI.push({
            "stakeholder": stakeholders[i].name,
            "impact_score": DSI[i],
            "description": string `Impact of '${stakeholders[i].name}' based on behavior change: ${DSI[i]}`
        });
    }

    json response = {
        "Dynamic Stakeholder Impact (DSI)": detailedDSI,
        "analysis": "This metric shows how changes in stakeholder behavior affect their overall impact on the network."
    };
    return response;
}