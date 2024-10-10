# Description.
#
# + name - field description  
# + connectionStrength - field description  
# + influence - field description
public type Stakeholder record {| 
    string name; 
    float connectionStrength; 
    float influence; 
|};

// Function to build the Stakeholder Influence Matrix (SIM)
public function buildStakeholderInfluenceMatrix(Stakeholder[] stakeholders) returns float[][] {
    int n = stakeholders.length();
    float[][] SIM = [];

    foreach int i in 0 ..< n {
        float[] row = [];
        foreach int j in 0 ..< n {
            float Ci = stakeholders[i].connectionStrength;
            float Ij = stakeholders[j].influence;
            float SIMij = calculateInfluence(Ci, Ij);
            row.push(SIMij);
        }
        SIM.push(row);
    }
    return SIM;
}

// Function to calculate influence
public function calculateInfluence(float Ci, float Ij) returns float {
    return Ci * Ij;
}


// Enhanced SIM output with detailed breakdown
public function buildStakeholderInfluenceMatrixDetailed(Stakeholder[] stakeholders) returns json {
    float[][] SIM = buildStakeholderInfluenceMatrix(stakeholders);
    json[] detailedSIM = [];

    foreach int i in 0 ..< stakeholders.length() {
        map<json> row = {};
        foreach int j in 0 ..< stakeholders.length() {
            row[stakeholders[j].name] = {
                "influence_score": SIM[i][j],
                "description": string `Influence of '${stakeholders[i].name}' on '${stakeholders[j].name}': ${SIM[i][j]}`
            };
        }
        detailedSIM.push(row);
    }

    json response = {
        "Stakeholder Influence Matrix (SIM)": detailedSIM,
        "analysis": "The matrix shows each stakeholder's influence on others. Higher values indicate stronger influence."
    };
    return response;
}
