#include<string>
#include<vector>
#include<map>

using namespace std;

string toString(int n)
{
	string temp;

	if(!n){
		return "0";
	}

	while(n){
		int r=n%10;
		n/=10;
		temp.push_back(r+48);
	}

	reverse(temp.begin(),temp.end());
	return temp;
}

class globalStore {
    // relationship + invidiual name
    vector<string> globals;
public:
    void add(string s) {
        globals.push_back(s);
    }

    string globalKnowledgeGraph() {
        string ret = "";
        for(string s : globals) {
            ret += "Global " + s + "\n";
        }

        return ret;
    }
};

struct variableDescription{
    string var_name, var_type, var_scope;
    int arraySz;

    variableDescription(){}
    variableDescription(string var_name, string var_type, string var_scope, int arraySz) {
        this->var_name = var_name;
        this->var_type = var_type;
        this->var_scope = var_scope;
        this->arraySz = arraySz;
    }
};

class variableStore
{
public:
    vector<variableDescription> variables;
    map<string, int> mapping;

    variableStore(){}

    void addVariable(string var_name, string var_type, string var_scope, int arraySz) {
        this->variables.push_back(variableDescription(var_name, var_type, var_scope, arraySz));
        this->mapping[var_name] = variables.size() - 1;
    }

    void makeParameter(string var_name) {
        this->variables[this->mapping[var_name]].var_scope = "Parameter";
    }

    string variableRDF() 
    {
        string ret = "";
        for(int i = 0; i < this->variables.size(); i++) {
            ret += "\t<owl:NamedIndividual rdf:about=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->variables[i].var_name + "\">\n";
            ret += "\t\t<rdf:type rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->variables[i].var_scope + "\"/>\n";
            ret += "\t\t<rdf:type>\n";
            ret += "\t\t\t<owl:Restriction>\n";
            ret += "\t\t\t\t<owl:onProperty rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#hasVariableType\"/>\n";
            ret += "\t\t\t\t<owl:allValuesFrom rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->variables[i].var_scope + "\"/>\n";
            ret += "\t\t\t</owl:Restriction>\n";
            ret += "\t\t</rdf:type>\n";
            ret += "\t\t<hasType rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->variables[i].var_type + "\"/>\n";
            
            if(this->variables[i].arraySz)
                ret += "\t\t<Dimension rdf:datatype=\"http://www.w3.org/2001/XMLSchema#integer\">" + toString(this->variables[i].arraySz) + "</Dimension>\n";
            
            ret += "\t\t<Name rdf:datatype=\"http://www.w3.org/2001/XMLSchema#string\">" + this->variables[i].var_name + "</Name>\n";
            ret += "\t</owl:NamedIndividual>\n\n";
        }

        return ret;
    }

    string variableKnowledgeGraph()
    {
        string ret = "";
        for(int i = 0; i < this->variables.size(); i++) {
            string name = this->variables[i].var_name;
            ret += name + " hasIdentity Variable\n";
            ret += name + " hasScope " +  this->variables[i].var_scope + "\n";
            ret += name + " hasType " + this->variables[i].var_type + "\n";
            
            if(this->variables[i].arraySz)
                ret += name + " hasDimension " + toString(this->variables[i].arraySz) + "\n";
            
            ret += "\n";
        }

        return ret;
    }
};

struct functionDescription{
    string function_name, return_type;
    vector<string> parameters;

    functionDescription(){}
    functionDescription(string function_name, string return_type) {
        this->function_name = function_name;
        this->return_type = return_type;
    }
};

class functionStore
{
public:
    vector<functionDescription> functions;
    map<string, int> mapping;

    functionStore(){}

    void addFunction(string function_name, string return_type) {
        this->functions.push_back(functionDescription(function_name, return_type));
        this->mapping[function_name] = functions.size() - 1;
    }

    void addParameter(string function_name, string param) {
        this->functions[this->mapping[function_name]].parameters.push_back(param);
    }

    string functionRDF() 
    {
        string ret = "";
        for(int i = 0; i < this->functions.size(); i++) {
            ret += "\t<owl:NamedIndividual rdf:about=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->functions[i].function_name + "\">\n";
            ret += "\t\t<rdf:type rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#Function\"/>\n";
            
	        for(string s : this->functions[i].parameters)
    	        ret += "\t\t<hasArgument rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + s + "\"/>\n";

            ret += "\t\t<hasReturnType rdf:resource=\"http://www.semanticweb.org/acer/ontologies/2020/10/Onto-C#" + this->functions[i].return_type + "\"/>\n";
            ret += "\t</owl:NamedIndividual>\n";
        }

        return ret;
    }

    string functionKnowledgeGraph()
    {
        string ret = "";
        for(int i = 0; i < this->functions.size(); i++) {
            string name = this->functions[i].function_name;
            ret += name + " hasIdentity Function\n";
            ret += name + " hasReturnType " + this->functions[i].return_type + " \n";
            
	        for(string s : this->functions[i].parameters)
    	        ret += name + " hasParameter " + s + "\n";
            
            ret += "\n";
        }

        return ret;
    }
};

struct loopDescription {
    int start, end, increment, scopeId, loopId;
    string scope, type; // type is For or While

    loopDescription(){}
    loopDescription(int loopId, int scopeId, string type) {
        this->loopId = loopId;
        this->scopeId = scopeId;
        this->type = type;
    }
};

class loopStore
{
public:
    vector<loopDescription> loops;
    map<string, int> mapping;
    map<int, int> loopNumbering;

    loopStore(){}
    
    // returns the loops unique identity
    string addLoop(int scopeId, string type) {
        int loopId = loopNumbering[scopeId] + 1;
        loopNumbering[scopeId] = loopId;

        loops.push_back(loopDescription(loopId, scopeId, type));

        string id = toString(scopeId) + "_" + toString(loopId);
        mapping[id] = loops.size() - 1;

        return id;
    }

    void addScopeNames(map<int, string> scopeMap) {
        for(int i = 0; i < this->loops.size(); i++) {
            this->loops[i].scope = scopeMap[this->loops[i].scopeId];
        }
    }

    string loopKnowledgeGraph() {
        string ret = "";
        for(int i = 0; i < this->loops.size(); i++) {
            string id = toString(this->loops[i].scopeId) + "_" + toString(this->loops[i].loopId);
            string name = this->loops[i].type + "_" + id;

            ret += name + " hasScopeId " + toString(this->loops[i].scopeId) + "\n";
            ret += name + " hasLoopId " + toString(this->loops[i].loopId) + "\n";
            ret += name + " hasIdentity Loop\n";
            ret += name + " hasScope " + this->loops[i].scope + "\n";
            ret += name + " hasLoopType " + this->loops[i].type + "\n";

            ret += "\n";
        }

        return ret;
    }
};