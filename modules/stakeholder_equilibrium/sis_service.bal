
// Function to calculate Systemic Influence Score (SIS)
# Description.
#
# + stakeholders - parameter description
# + return - return value description
public function calculateSystemicInfluenceScore(Stakeholder[] stakeholders) returns float[] {
    float[][] SIM = buildStakeholderInfluenceMatrix(stakeholders);
    int n = SIM.length();
    float[] SIS = [];

    foreach int i in 0 ..< n {
        float directInfluence = 0;
        float indirectInfluence = 0;

        // Direct influence
        foreach int j in 0 ..< n {
            directInfluence += SIM[i][j];
        }

        // Indirect influence
        foreach int k in 0 ..< n {
            foreach int j in 0 ..< n {
                indirectInfluence += SIM[i][k] * SIM[k][j];
            }
        }

        SIS.push(directInfluence + indirectInfluence);
    }

    return SIS;
}


// Enhanced SIS output with detailed analysis
public function calculateSystemicInfluenceScoreDetailed(Stakeholder[] stakeholders) returns json {
    float[] SIS = calculateSystemicInfluenceScore(stakeholders);
    json[] detailedSIS = [];

    foreach int i in 0 ..< stakeholders.length() {
        detailedSIS.push({
            "stakeholder": stakeholders[i].name,
            "systemic_influence_score": SIS[i],
            "description": string `Total systemic influence of '${stakeholders[i].name}': ${SIS[i]} (Direct + Indirect)`
        });
    }

    json response = {
        "Systemic Influence Score (SIS)": detailedSIS,
        "analysis": "This score reflects both direct and indirect influence of stakeholders within the network, with higher scores indicating more systemic influence."
    };
    return response;
}