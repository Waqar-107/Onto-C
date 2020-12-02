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
};