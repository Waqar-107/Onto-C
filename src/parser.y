%{
#include<iostream>
#include<cstdio>
#include<cstdlib>
#include<cstring>
#include<cmath>
#include<string>
#include<vector>
#include<algorithm>
#include<map>
#include "SymbolTable.h"
#include "RDF_Utils.h"

using namespace std;

int yyparse(void);
int yylex(void);

int cnt_err, semanticErr = 0;
extern int line;

string variable_type;
string codes, assemblyCodes;
string returnType_curr;
string isReturningType;
string expressionRaw;

extern FILE *yyin;
FILE *error,*asmCode;

SymbolTable table(10);
SymbolInfo *currentFunction;
map<int, string> scopeMapping;

vector<string> statement_list;

vector<SymbolInfo*> params;
vector<SymbolInfo*> var_list;
vector<SymbolInfo*> arg_list;
vector<pair<string,string>> variableListForInit;

bool isReturning;
variableStore vstore;
functionStore fstore;
globalStore gstore;
loopStore lstore;

void yyerror(const char *s)
{
	cnt_err++;
	fprintf(error,"syntax error \"%s\" Found on Line %d (Error no.%d)\n",s,line,cnt_err);
}


string stoi(int n)
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

void fillScopeWithParams()
{	
	for(int i=0;i<params.size();i++)
	{
		if(!table.Insert(params[i]->getName(),"ID")){
			semanticErr++;
			fprintf(error,"semantic error found on line %d: variable '%s' already declared before\n\n",line,params[i]->getName().c_str());
		}

		else{
			SymbolInfo *temp=table.lookUp(params[i]->getName());
			temp->setVariableType(params[i]->getVariableType());
			temp->sz=params[i]->sz;

			variableListForInit.push_back({params[i]->getName()+stoi(table.getCurrentID()),"0"});
		}
	}
}


int labelCount = 1, tempCount = 1; 
string newLabel()
{
	string temp = "L" + stoi(labelCount);
	labelCount++;
	return temp;
}

string newTemp()
{
	string temp = "T" + stoi(tempCount);
	tempCount++;

	variableListForInit.push_back({temp,"0"});
	return temp;
}


%}

%union{
	SymbolInfo *symbol;
}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE ASSIGNOP INCOP DECOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON COMMENT PRINTLN
%token<symbol>CONST_INT
%token<symbol>CONST_FLOAT
%token<symbol>CONST_CHAR 
%token<symbol>STRING
%token<symbol>ID
%token<symbol>ADDOP
%token<symbol>MULOP
%token<symbol>RELOP
%token<symbol>LOGICOP
%token<symbol>BITOP

%type<symbol>start program compound_statement type_specifier parameter_list declaration_list var_declaration unit func_declaration statement statements variable expression factor arguments argument_list expression_statement unary_expression simple_expression logic_expression rel_expression term func_definition
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%define parse.error verbose

%%

start : program {
		 	$$=$1;

		 	if(!semanticErr && !cnt_err)
		 	{
		 		
		 	}
		}
	;

program : program unit {
			$$=$1;
			$$->setCode($$->getCode()+$2->getCode());
		} 
	| unit {
			$$=$1;
		}
	;
	
unit : var_declaration {
		   	$$=$1;
   	   	}
     | func_declaration {
		   	$$=$1;
   	   	}
     | func_definition {
		   	$$=$1;
   	   	}
     ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
		{
			//int foo(int a,float b);
			if(!table.Insert($2->getName(),"ID")){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: re-declaration of function \'%s\'\n\n",line,$2->getName().c_str());
			}

			else{
				SymbolInfo *x=table.lookUp($2->getName());
				x->setReturnType($1->getType());
				x->setIdentity("function_declaration");

				for(int i=0;i<$4->edge.size();i++){
					x->edge.push_back($4->edge[i]);
				}
			}
			
			SymbolInfo *newSymbol=new SymbolInfo("function - "+$2->getName(),"func_declaration");
			$$=newSymbol;

			params.clear();
		}
		| type_specifier ID LPAREN RPAREN SEMICOLON
		{
			//int foo();
			if(!table.Insert($2->getName(),"ID")){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: redeclaration of function \'%s\'\n\n",line,$2->getName().c_str());	
			}

			else{
				SymbolInfo *x=table.lookUp($2->getName());
				x->setReturnType($1->getType());
				x->setIdentity("function_declaration");
			}
			
		
			SymbolInfo *newSymbol=new SymbolInfo("function - "+$2->getName(),"func_declaration");
			$$=newSymbol;
		}
		;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN{table.EnterScope(); fillScopeWithParams();} compound_statement
		{
			//------------------------------------------
			//current scope obtained, insert the function in the global scope
			int id = table.getCurrentID();
			for(int i = 0; i < params.size(); i++)
				var_list.push_back(params[i]);

			table.ExitScope();
			//------------------------------------------


			// ----------------------------------------
			// add the function in the storage
			scopeMapping[id] = $2->getName();
			vector<string> parameters;
			gstore.add("hasFunction " + $2->getName());
            fstore.addFunction($2->getName(), $1->getType());
			for(int i = 0; i < $4->edge.size(); i++)
			{
				fstore.addParameter($2->getName(), $4->edge[i]->getName() + stoi(id));
				vstore.makeParameter($4->edge[i]->getName() + stoi(id));
			}
			//-----------------------------------------

			SymbolInfo *newSymbol=new SymbolInfo("function - "+$2->getName(),"func_definition");
			$$=newSymbol;


			//-----------------------------------------------------------------------
			//semantic error: type_specifier void and return
			if(isReturning && $1->getType()=="void"){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: type-specifier is of type void, can't return\n\n",line);
			}

			else{
				//check if function is returning the right type of variable
				if(isReturningType!=$1->getType()){
					semanticErr++;
					fprintf(error,"semantic error found in line %d: return type didn't match\n\n",line);
				}
			}

			isReturning=false;
			//-----------------------------------------------------------------------

			/*check if the function has been declared previously or not
			if yes then match the parameter_list, else insert it and also update
			current function pointer, later before exiting the scope of this function
			insert all the variables in the vector*/
			SymbolInfo *x=table.lookUp($2->getName());
			
			if(x){
				if(x->getIdentity()!="function_declaration"){
					semanticErr++;
					fprintf(error,"semantic error found on line %d: function with same name already defined\n\n",line);
				}

				else{
					//declared before
					//check parameter names and their variable types
			
					if(x->edge.size()!=$4->edge.size()){
						fprintf(error,"semantic error in line %d: parameters didn't match from the previously declared one\n\n",line);
						semanticErr++;
					}

					else{
						//first  match params
						bool f=1;
						for(int i=0;i<$4->edge.size();i++){
							if($4->edge[i]->getName()!=x->edge[i]->getName() || $4->edge[i]->getType()!=x->edge[i]->getType()){
								f=0;
								break;
							}
						}

						if(f)
						{
							//match return type
							if(x->getReturnType()==$1->getType()){
								//already inserted and parameters matched, edit it
								x->setIdentity("func_defined");
								currentFunction=x;

								for(int i=0;i<var_list.size();i++){
									x->edge.push_back(var_list[i]);
									//cout<<"in func "<<var_list[i]->getIdentity()<<endl;
								}

								x->setReturnType($1->getType());
								for(int i=0;i<params.size();i++)
									x->params.push_back(params[i]);

								x->id=id;
								currentFunction=x;//cout<<var_list.size()<<" "<<$2->getName()<<endl;
							}

							else{
								semanticErr++;
								fprintf(error,"semantic error found in line %d: return type didn't match with the previous declaration\n\n",line);
							}
						}

						else{
							semanticErr++;
							fprintf(error,"semantic error found in line %d: parameter list didn't match\n\n",line);
						}
					}
				}
			}

			else{
				table.Insert($2->getName(),"ID");
				x=table.lookUp($2->getName());
				x->setIdentity("func_defined");
				x->setVariableType($1->getType());
				x->setReturnType($1->getType());
				
				for(int i=0;i<var_list.size();i++){
					x->edge.push_back(var_list[i]);
				}

				currentFunction=x;
				//cout<<var_list.size()<<" "<<$2->getName()<<endl;
				for(int i=0;i<params.size();i++)
					x->params.push_back(params[i]);
				x->id=id;
			}

			var_list.clear();
			params.clear();
		}
		| type_specifier ID LPAREN RPAREN{table.EnterScope();} compound_statement
		{
			// ----------------------------------------
			// add function to the store for generating knowledge-graph
			scopeMapping[table.getCurrentID()] = $2->getName();
			fstore.addFunction($2->getName(), $1->getType());
			//-----------------------------------------

			SymbolInfo *newSymbol=new SymbolInfo("function - "+$2->getName(),"func_definition");
			$$=newSymbol;

			//------------------------------------------
			//current scope obtained, insert the function in the global scope
			int id=table.getCurrentID();
			var_list=table.printCurrentAndGetAll();
			table.ExitScope();
			//------------------------------------------

			//-----------------------------------------------------------------------
			//semantic error: type_specifier void and return
			if(isReturning && $1->getType()=="void"){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: type-specifier is of type void, can't return\n\n",line);
			}

			isReturning=false;
			//-----------------------------------------------------------------------

			/*check if the function has been declared previously or not
			if yes then match the parameter_list, else insert it and also update
			current function pointer, later before exiting the scope of this function
			insert all the variables in the vector*/
			SymbolInfo *x=table.lookUp($2->getName());

			if(x){
				if(x->getIdentity()!="function_declaration"){
					semanticErr++;
					fprintf(error,"semantic error found on line %d: function with same name already defined\n\n",line);
				}

				else{
					if(x->edge.size()>0){
						semanticErr++;
						fprintf(error,"semantic error found on line %d: parameter quantity does not match with declarations\n\n",line);
					}

					else{
						//match return type
						if(x->getReturnType()==$1->getType()){
							//already inserted and parameters matched, edit it
							x->setIdentity("func_defined");
							currentFunction=x;

							for(int i=0;i<var_list.size();i++){
								x->edge.push_back(var_list[i]);
							}

							currentFunction=x;
							//cout<<var_list.size()<<" "<<$2->getName()<<endl;
						}

						else{
							semanticErr++;
							fprintf(error,"semantic error found in line %d: return type didn't match with the previous declaration\n\n",line);
						}
					}
				}
			}

			else{
				table.Insert($2->getName(),"ID");
				x=table.lookUp($2->getName());
				x->setIdentity("func_defined");
				
				for(int i=0;i<var_list.size();i++){
					x->edge.push_back(var_list[i]);
				}

				currentFunction=x;
				//cout<<var_list.size()<<" "<<$2->getName()<<endl;
				x->setVariableType($1->getType());
			}

			var_list.clear();
		}
 		;				


parameter_list : parameter_list COMMA type_specifier ID
		{
			$$->edge.push_back(new SymbolInfo($4->getName(),$3->getType()));
			$$->edge[$$->edge.size()-1]->setIdentity("var");

			//--------------------------------------------------------------------
			//insert in the current scope, already a new scope has been created
			//we insert in params for now, later we will insert them in the table
			SymbolInfo *temp=new SymbolInfo($4->getName(),"ID");

			int n;
			temp->sz=$4->sz;

			temp->setVariableType($3->getType());

			n=max(1,temp->sz);
			params.push_back(temp);
			//--------------------------------------------------------------------
		}
		| parameter_list COMMA type_specifier
		{
			$$->edge.push_back(new SymbolInfo("",$3->getType()));
			$$->edge[$$->edge.size()-1]->setIdentity("param");
		}
 		| type_specifier ID
 		{
			SymbolInfo *x=new SymbolInfo("parameter_list");
			$$=x;

			//edge is the list or parameters where each parameter has id-name and type
			$$->edge.push_back(new SymbolInfo($2->getName(),$1->getType()));
			$$->edge[$$->edge.size()-1]->setIdentity("var");

			//--------------------------------------------------------------------
			//insert in the current scope, already a new scope has been created
			//we insert in params for now, later we will insert them in the table
			SymbolInfo *temp=new SymbolInfo($2->getName(),"ID");

			int n;
			temp->sz=$2->sz;

			temp->setVariableType($1->getType());
			
			n=max(1,temp->sz);
			params.push_back(temp);
			//--------------------------------------------------------------------
		}
		| type_specifier
		{
			SymbolInfo *x=new SymbolInfo("parameter_list");
			$$=x;

			//edge is the list or parameters where each parameter has id-name and type
			$$->edge.push_back(new SymbolInfo("",$1->getType()));
			$$->edge[$$->edge.size()-1]->setIdentity("param");
		}
 		;

 		
compound_statement : LCURL statements RCURL
		{
			$$=$2;
		}
 		    | LCURL RCURL
 		{
			SymbolInfo *newSymbol=new SymbolInfo("compound_statement","dummy");
			$$=newSymbol;
		}
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
		{
			$$=new SymbolInfo("var_declaration","var_declaration");

            // insert the variables in the store so that later we can generate the knowledge-base
			for(pair<string, string> p : variableListForInit)
			{
				if(table.getCurrentID() == 1) {
					vstore.addVariable(p.first, variable_type, "Global_Variable", stoi(p.second));
					gstore.add("hasVariable " + p.first);
				}

				else vstore.addVariable(p.first, variable_type, "Local_Variable", stoi(p.second));
			}
			
			$2->edge.clear();
			variableListForInit.clear();
		}
 		 ;
 		 
type_specifier : INT
		{
			variable_type = "int";

			SymbolInfo *newSymbol = new SymbolInfo("int");
			$$ = newSymbol;
		}
 		| FLOAT
 		{
			variable_type = "float";

			SymbolInfo *newSymbol = new SymbolInfo("float");
			$$ = newSymbol;
		}
 		| VOID
 		{
			variable_type = "void";

			SymbolInfo *newSymbol = new SymbolInfo("void");
			$$ = newSymbol;
		}
 		;
 		
declaration_list : declaration_list COMMA ID
		{
			//---------------------------------------------------------------------
			//code generation
 			variableListForInit.push_back({$3->getName()+stoi(table.getCurrentID()),"0"});
 			//---------------------------------------------------------------------

			$3->setIdentity("var");
			$3->setVariableType(variable_type);
			
			$$->edge.push_back($3);
			
			//---------------------------------------------------------------------------
			//semantics and insertion in the table
 			if(variable_type=="void") {
 				fprintf(error,"semantic error found at line %d: variable cannot be of type void\n\n",line);
 				semanticErr++;
 			}

 			else
 			{
 				//insert in SymbolTable directly if not declared before
 				if(!table.Insert($3->getName(),"ID")) {
 					fprintf(error,"semantic error found at line %d: variable \'%s\' declared before\n\n",line,$1->getName().c_str());
 					semanticErr++;
 				}

				else {
 					SymbolInfo *temp=table.lookUp($3->getName());
 					temp->setVariableType(variable_type);
 					temp->setIdentity("var");
 				}
 			}
 			//---------------------------------------------------------------------------

		}
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
 		{
 			//---------------------------------------------------------------------
 			//code generation
 			variableListForInit.push_back({$3->getName()+stoi(table.getCurrentID()),$5->getName()});
 			//---------------------------------------------------------------------
 			
			$3->setIdentity("arr");
			$3->setVariableType(variable_type);

			$$->edge.push_back($3);
 			

			//---------------------------------------------------------------------------
			//semantics and insertion in the table
 			if(variable_type=="void") {
 				fprintf(error,"semantic error found at line %d: variable cannot be of type void\n\n",line);
 				semanticErr++;
 			}

 			else 
 			{
 				//insert in SymbolTable directly if not declared before
 				if(!table.Insert($3->getName(),"ID")) {
 					fprintf(error,"semantic error found at line %d: variable %s declared before\n\n",line,$1->getName().c_str());
 					semanticErr++;
 				}

 				else {
 					SymbolInfo *x=table.lookUp($3->getName());
 					x=table.lookUp($3->getName());
 					x->setVariableType(variable_type);

 					int n=atoi($5->getName().c_str());
 					x->sz=n;
 					x->setIdentity("arr");
 				}
 			}
 			//---------------------------------------------------------------------------

 		}
 		  | ID
 		{
 			//---------------------------------------------------------------------
			//code generation
 			variableListForInit.push_back({$1->getName()+stoi(table.getCurrentID()),"0"});
 			//---------------------------------------------------------------------

 			SymbolInfo *newSymbol = new SymbolInfo("declaration_list");
 			$$ = newSymbol;

 			$1->setVariableType(variable_type);$1->setIdentity("var");

 			$$->setIdentity("declaration_list");
 			$$->edge.push_back($1);

 			//---------------------------------------------------------------------------
			//semantics and insertion in the table
 			if(variable_type=="void") {
 				fprintf(error,"semantic error found at line %d: variable cannot be of type void\n\n",line);
 				semanticErr++;
 			}

 			else {
 				//insert in SymbolTable directly if not declared before
 				if(!table.Insert($1->getName(),"ID")) {
 					fprintf(error,"semantic error found at line %d: variable %s declared before\n\n",line,$1->getName().c_str());
 					semanticErr++;
 				}

 				else {
 					SymbolInfo *temp=table.lookUp($1->getName());
 					temp->setVariableType(variable_type);
 					
 					temp->setIdentity("var");
 				}
 			}
 			//---------------------------------------------------------------------------
 		}
 		  | ID LTHIRD CONST_INT RTHIRD
 		{
 			//---------------------------------------------------------------------
 			//code generation
 			variableListForInit.push_back({$1->getName()+stoi(table.getCurrentID()),$3->getName()});
 			//---------------------------------------------------------------------
 			
 			SymbolInfo *x = new SymbolInfo("declaration_list");
 			$$ = x;$$->setIdentity("declaration_list");

 			$1->sz=atoi($3->getName().c_str());$1->setVariableType(variable_type);
 			$1->setIdentity("arr");

 			$$->edge.push_back($1);

 			//---------------------------------------------------------------------------
			//semantics and insertion in the table
 			if(variable_type=="void") {
 				fprintf(error,"semantic error found at line %d: variable cannot be of type void\n\n",line);
 				semanticErr++;
 			}

 			else 
 			{
 				//insert in SymbolTable directly if not declared before
 				if(!table.Insert($1->getName(),"ID")) {
 					fprintf(error,"semantic error found at line %d: variable %s declared before\n\n",line,$1->getName().c_str());
 					semanticErr++;
 				}

 				else {
 					SymbolInfo *x=table.lookUp($1->getName());
 					x=table.lookUp($1->getName());
 					x->setVariableType(variable_type);

 					int n=atoi($3->getName().c_str());
 					x->sz=n;
 					x->setIdentity("arr");
 				}
 			}
 			//---------------------------------------------------------------------------
 		}
 		  ;
 		  
statements : statement
		{
			$$=$1;
		}
	   | statements statement
	    {
			$$=$1;
			$$->setCode($$->getCode()+$2->getCode());
		}
	   ;
	   
statement : var_declaration {
			$$ = $1;
		}
	  | expression_statement {
			$$ = $1;
		}
	  | compound_statement {
			$$ = $1;
		}
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  	{
			// ----------------------------------------------
			string loopName = lstore.addLoop(table.getCurrentID(), "For");
			lstore.addEndCondition(loopName, $4->getCode());
			lstore.addInitialization(loopName, $3->getCode());
			lstore.addIncDec(loopName, $5->getCode());
			//-----------------------------------------------

			$$ = $3;
		}
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  	{
			$$=$3;
	
			string label=newLabel();
			
			assemblyCodes=$$->getCode();
			assemblyCodes+=("\tMOV AX, "+$3->getName()+"\n");

			assemblyCodes+="\tCMP AX, 0\n";
			assemblyCodes+=("\tJE "+label+"\n");
			assemblyCodes+=$5->getCode();
			assemblyCodes+=("\t"+label+":\n");
					
			$$->setCode(assemblyCodes);		
			$$->setName("statement");$$->setType("if");	//for debugging purpose
		}
	  | IF LPAREN expression RPAREN statement ELSE statement
	  	{
			$$=$3;

			string else_condition=newLabel();
			string after_else=newLabel();

			assemblyCodes=$$->getCode();
			
			assemblyCodes+=("\tMOV AX, "+$3->getName()+"\n");
			assemblyCodes+="\tCMP AX, 0\n";
			assemblyCodes+=("\tJE "+else_condition+"\n");		//false, jump to else
			
			assemblyCodes+=$5->getCode();					//true
			assemblyCodes+=("\tJMP "+after_else);

			assemblyCodes+=("\n\t"+else_condition+":\n");
			assemblyCodes+=$7->getCode();
			assemblyCodes+=("\n\t"+after_else+":\n");

			$$->setCode(assemblyCodes);
			$$->setName("statement");$$->setType("if-else if");
		}
	  | WHILE LPAREN expression RPAREN statement
		{
			// ----------------------------------------------
			string loopName = lstore.addLoop(table.getCurrentID(), "While");
			lstore.addEndCondition(loopName, $3->getCode());
			//-----------------------------------------------

			$$ = new SymbolInfo("while","loop");
		}
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  	{
	  		$$=new SymbolInfo("println","nonterminal");
	  		
			assemblyCodes=("\n\tMOV AX, "+$3->getName()+stoi(table.getCurrentID())+"\n");
			assemblyCodes+=("\tCALL PRINT_ID\n");

			$$->setCode(assemblyCodes);
		}
	  | RETURN expression SEMICOLON
	    {
			$$=new SymbolInfo("return","statement");

			isReturning=true;
			isReturningType=$2->getVariableType();

			assemblyCodes=$$->getCode();

			$$->setCode(assemblyCodes);
		}
	  ;
	  
expression_statement : SEMICOLON {
			$$ = new SymbolInfo("SEMICOLON","SEMICOLON");
		}			
		| expression SEMICOLON {
			$$ = $1;
		} 
			;
	  
variable : ID
		{
			$$=$1;

			$$->setIdentity("var");
			$$->idx=-1;

			$$->asmName=$$->getName()+stoi(table.getCurrentID());

			//--------------------------------------------------
			//#semantic: see if variable has been declared
			SymbolInfo *x=table.lookUp($1->getName());
			if(!x){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable '%s' not declared in this scope\n\n",line,$1->getName().c_str());
			}

			else{
				$$->setVariableType(x->getVariableType());
			}
			//--------------------------------------------------
		} 		
	 | ID LTHIRD expression RTHIRD 
		{
			SymbolInfo *newSymbol=new SymbolInfo($1->getName(),"variable");
			$$=newSymbol;

			$$->setVariableType($3->getVariableType());
			$$->setIdentity("arr");
			$$->sz=atoi($3->getName().c_str());
			
			$$->idx=stoi($3->getName());
			$$->asmName=$$->getName()+stoi(table.getCurrentID());

			//--------------------------------------------------------------------------
			//#semantic: type checking, expression must be int, e.g: a[5.6]
			if($3->getVariableType()!="int"){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: type mismatch, array index must be integer\n\n",line);
			}
			//--------------------------------------------------------------------------

			//--------------------------------------------------
			//#semantic: see if variable has been declared
			SymbolInfo *x=table.lookUp($1->getName());
			if(!x){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable '%s' not declared in this scope\n\n",line,$1->getName().c_str());
			}

			else{
				$$->setVariableType(x->getVariableType());
			}
			//--------------------------------------------------
		}
	 ;
	 
 expression : logic_expression
		{
			$$ = $1;
		}	
	   | variable ASSIGNOP logic_expression 	
		{
			$$ = $1;

			//---------------------------------------------------------------------------
			//#semantic: Array Index: You have to check whether there is index used with array and vice versa.
			//e.g: int a[10];a=8; or int a;a[5]=5;
			SymbolInfo *x=table.lookUp($1->getName());
			if(x)
			{	
				//type of var
				$$->setVariableType(x->getVariableType());

				if(x->getIdentity()=="arr" && $1->getIdentity()!="arr"){
					semanticErr++;
					fprintf(error,"semantic error found in line %d: array index error\n\n",line);
				}

				else if(x->getIdentity()!="arr" && $1->sz>0){
					semanticErr++;
					fprintf(error,"semantic error found in line %d: array index error\n\n",line);
				}
			}

			else{
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable '%s' not declared in this scope\n\n",line,$1->getName().c_str());
			}
			//---------------------------------------------------------------------------
			//#semantic: check if float is assigned to int or vice-versa
			if(x)
			{
				if(x->getVariableType()!=$3->getVariableType()){
					semanticErr++;
					fprintf(error,"semantic error found in line %d: type mismatch in assignment \n\n",line,$3->getVariableType().c_str(),x->getVariableType().c_str());
				}
			}
			//---------------------------------------------------------------------------
			//#semantic: expression cannot have void return type functions called
			if(returnType_curr=="void"){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: void type function can't be part of expression\n\n",line);
				returnType_curr="none";
			}
			//---------------------------------------------------------------------------
		

			//-------------------------------------------------------------
			
			string raw_codes = $1->getName() + " = " + $3->getCode();
			$$->setCode(raw_codes);
			//-------------------------------------------------------------

		}
	   ;
			
logic_expression : rel_expression
		{
			$$ = $1;
		} 	
		 | rel_expression LOGICOP rel_expression 	
		{
			$$ = $1;

			//------------------------------------------------------------------
			//#semantic: LOGICOP MUST BE INT
			$$->setVariableType("int");

			//#semantic: both sides of RELOP should be integer
			if($1->getVariableType()!="int" || $3->getVariableType()!="int"){
				semanticErr++;
				fprintf(error,"semantic error in line %d found: both operands of %s should be integers\n\n",line,$2->getName().c_str());
			}
			//------------------------------------------------------------------


			//------------------------------------------------------------------
			// raw code for loops
			string raw_codes = $$->getCode() + $2->getName() + $3->getCode();
			$$->setCode(raw_codes);
			//------------------------------------------------------------------
		}
		 ;
			
rel_expression : simple_expression 
		{
			$$ = $1;
		}
		| simple_expression RELOP simple_expression	
		{
			$$ = $1;

			//------------------------------------------------------------------
			//#semantic: RELOP MUST BE INT
			$$->setVariableType("int");

			//#semantic: both sides of RELOP should be integer
			if($1->getVariableType()!="int" || $3->getVariableType()!="int"){
				semanticErr++;
				fprintf(error,"semantic error in line %d found: both operands of %s should be integers\n\n",line,$2->getName().c_str());
			}
			//------------------------------------------------------------------


			//------------------------------------------------------------------
			// generate raw codes for loop
			string raw_codes = $$->getName() + " " + $2->getName() + " " + $3->getName();
			$$->setCode(raw_codes);

			delete $3;
			//------------------------------------------------------------------
		}
		;
				
simple_expression : term
		{
			$$ = $1;
			//cout << "just term "<<$$->getCode() << "|"<<$$->getName()<<endl;
		} 
		  | simple_expression ADDOP term
		{
			$$ = $1;

			if($1->getVariableType()=="float" || $3->getVariableType()=="float")
				$$->setVariableType("float");
			else
				$$->setVariableType("int");

			string raw_codes = $1->getName() + " " + $2->getName() + " " + $3->getName();
			$$->setCode(raw_codes);

			delete $3;
		} 
		  ;
					
term :	unary_expression
		{
			$$ = $1;
		}
     |  term MULOP unary_expression
		{
			$$=$1;
			assemblyCodes=$$->getCode();

			//------------------------------------------------------------------------
			//code generation	
			string raw_codes = $1->getName() + " " + $2->getName() + " " + $3->getName();
			$$->setCode(raw_codes);

			//------------------------------------------------------------------------


			//------------------------------------------------------------------------
			//#semantic: check 5%2.5
			if($2->getName()=="%" && ($1->getVariableType()!="int" || $3->getVariableType()!="int")){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: type mismatch, mod operation is only possible with integer operands\n\n",line);
			}
			//------------------------------------------------------------------------

			//set variable_type
			if($2->getName()=="%")
				$$->setVariableType("int");
			else
			{
				if($1->getVariableType()=="float" || $3->getVariableType()=="float")
					$$->setVariableType("float");
				else
					$$->setVariableType("int");
			}
		}
     ;

unary_expression : ADDOP unary_expression
		{
			$$=$2;
			string temp=newTemp();
			$$->setName(temp);
			$$->asmName=temp;
		}  
		 | NOT unary_expression 
		{
			$$ = $2;

			//codes like !const or !var_name

			// assemblyCodes=$$->getCode();
			// $$->setCode(assemblyCodes);
		}
		 | factor 
		{
			$$ = $1;
			//cout << "inside factor " << $$->getCode() << "|" << $$->getName() << endl;
			//$$->setCode($$->getName());
		}
		 ;
	
factor : variable
		{
			$$ = $1;

			//-------------------------------------------------------------------
			//****************************************************************************
			// this code chunk appends scope-id to the variables
			//for code generation purpose we concatenate the current id with the variable name
			$$->asmName=$$->getName()+stoi(table.getCurrentID());
			//-------------------------------------------------------------------

			//#semantic error check
			SymbolInfo *temp=table.lookUp($1->getName());
			if(!temp){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable %s not declared in this scope\n\n",line,$1->getName().c_str());
			}
		} 
	| ID LPAREN argument_list RPAREN
		{
			SymbolInfo *newSymbol=new SymbolInfo("func_call","factor");
			$$=newSymbol;

			//--------------------------------------------------------------------------
			//#semantic: calling functions, check the arguments
			SymbolInfo *func=table.lookUp($1->getName());

			//set the variable type of factor and also current return type
			if(func) 
				$$->setVariableType(func->getReturnType()), returnType_curr=func->getReturnType();
			else
				$$->setVariableType("func_not_found");

			if(func && func->getIdentity()=="func_defined")
			{
				if(func->params.size()!=arg_list.size()){
					semanticErr++;
					fprintf(error,"semantic error found in line %d: argument list didn't match, wrong number of arguments\n\n",line);
				}

				else
				{
					assemblyCodes=$$->getCode();
					for(int i=0;i<func->params.size();i++)
					{
						SymbolInfo *x=table.lookUp(arg_list[i]->getName());
						if(x)
						{
							if(x->getVariableType()!=func->edge[i]->getVariableType() || x->sz!=func->edge[i]->sz){
								semanticErr++;
								fprintf(error,"semantic error found in line %d: type mismatch, wrong type of argument given\n\n",line);
								break;
							}
							else{
								assemblyCodes+="\n\tMOV AX, "+arg_list[i]->getName()+stoi(table.getCurrentID())+"\n";
								assemblyCodes+="\tMOV "+func->params[i]->getName()+stoi(func->id)+", AX\n";
							}
						}

						else{
							semanticErr++;
							fprintf(error,"semantic error found in line %d: function not found\n\n",line);
						}
					}

					//-----------------------------------------------
					// call to a function
					assemblyCodes+="\tCALL "+func->getName()+"\n";
					//$$->setCode(assemblyCodes);
				}
			}

			else{
				semanticErr++;
				fprintf(error,"semantic error found in line %d: function named '%s' not defined\n\n",line,$1->getName().c_str());
			}
			//--------------------------------------------------------------------------

			arg_list.clear();
		}
	| LPAREN expression RPAREN
		{
			$$=$2;$$->asmName=$$->getName();
		}
	| CONST_INT
		{
			$$ = $1;
			$$->setCode($$->getName());
			$$->asmName = $$->getName();
			$$->setVariableType("int");
		} 
	| CONST_FLOAT
		{
			$$=$1;
			$$->setCode($$->getName());
			$$->asmName=$$->getName();
			$$->setVariableType("float");
		}
	| variable INCOP
		{
			//-----------------------------------------------------------------
			//#semantic error check
			SymbolInfo *temp=table.lookUp($1->getName());
			if(!temp){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable %s not declared in this scope\n\n",line,$1->getName().c_str());
			}
			//-----------------------------------------------------------------


			//-----------------------------------------------------------------
			//code generation
			else
			{
				$$=new SymbolInfo($1->getName(),$1->getType());
			
				//copy all properties
				$$->sz=$1->sz;
				$$->setVariableType($1->getVariableType());
				$$->setReturnType($1->getReturnType());
				$$->setCode($$->getCode());
				$$->setIdentity($1->getIdentity()) ;

				string raw_codes = $1->getName() + "++";
				//cout << "inc set to " << raw_codes << endl;
				$$->setCode(raw_codes);
			}
			//-----------------------------------------------------------------
		} 
	| variable DECOP
		{
			//-----------------------------------------------------------------
			//#semantic error check
			SymbolInfo *temp=table.lookUp($1->getName());
			if(!temp){
				semanticErr++;
				fprintf(error,"semantic error found in line %d: variable %s not declared in this scope\n\n",line,$1->getName().c_str());
			}
			//-----------------------------------------------------------------


			//-----------------------------------------------------------------
			//code generation
			else
			{
				$$=new SymbolInfo($1->getName(),$1->getType());
			
				//copy all properties
				$$->sz=$1->sz;
				$$->setVariableType($1->getVariableType());
				$$->setReturnType($1->getReturnType());
				$$->setCode($$->getCode());
				$$->setIdentity($1->getIdentity()) ;

				assemblyCodes=$$->getCode();
				string var_name=$1->getName()+stoi(table.getCurrentID());
				string temp_str=newTemp();

				$$->setName(var_name);

				string raw_codes = $1->getName() + "--";
				$$->setCode(raw_codes);
			}
			//-----------------------------------------------------------------
			
;		}
	;
	
argument_list : arguments
		{
			$$=$1;
			$$->setType("argument_list");
		}
	|{
		SymbolInfo *newSymbol=new SymbolInfo("","argument_list");
		$$=newSymbol;
	 }
			  ;
	
arguments : arguments COMMA logic_expression
		{
			SymbolInfo *newSymbol=new SymbolInfo($1->getName()+","+$3->getName(),"arguments");
			$$=newSymbol;

			arg_list.push_back($3);
		}
	      | logic_expression
	    {
			$$=$1;
			arg_list.push_back($$);
		}
	      ;

%%
int main(int argc,char *argv[])
{

	if((yyin=fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	error=fopen(argv[2],"w");
	fclose(error);

	asmCode=fopen(argv[3],"w");
	fclose(asmCode);
	
	error=fopen(argv[2],"a");
	asmCode=fopen(argv[3],"a");
	
	isReturning=false; currentFunction=0;
	cnt_err=0; returnType_curr="none";

	// read the base owl file and write it to the output file
	freopen("KnowledgeGraph.txt", "w", stdout);

	yyparse();

	// write the variables
	cout << gstore.globalKnowledgeGraph() << endl;
	cout << vstore.variableKnowledgeGraph() << endl;
    cout << fstore.functionKnowledgeGraph() << endl;

	lstore.addScopeNames(scopeMapping);
	cout << lstore.loopKnowledgeGraph() << endl;

	//print the SymbolTable and other credentials
	fprintf(error,"total lines read: %d\n",line-1);
	fprintf(error,"total errors encountered: %d",cnt_err+semanticErr);
	
	fclose(error);
	fclose(asmCode);

	
	
	return 0;
}

