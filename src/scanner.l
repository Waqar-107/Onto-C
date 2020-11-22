%option noyywrap

%{

#include<string>
#include<cstring>
#include "SymbolTable.h"
#include "y.tab.h"

using namespace std;

int line=1;
extern int cnt_err;

extern FILE *logout;
extern FILE *error;

/* ----------------------------------------------- */
void processChar(string s){

	char ch;
	string ps;
	
	//if length==3 then normal char, if 4, then \n,\t etc.
	if(s.length()==3)
		ch=s[1];

	else
	{
		int x,y;
		int ascii=(int)yytext[2];
		
		//char chr[]={'\n','\t','\\','\"','\a','\f','\r','\b','\v','\0'};

		if(s[2]=='n') {ch='\n';}
		else if(s[2]=='t') {ch='\t';}
		else if(s[2]=='a') {ch='\a';}
		else if(s[2]=='f') {ch='\f';}
		else if(s[2]=='r') {ch='\r';}
		else if(s[2]=='b') {ch='\b';}
		else if(s[2]=='v') {ch='\v';}
		else if(s[2]=='0') {ch='\0';}

		else if(s[2]=='\\') {ch='\\';}
		else if(s[2]=='\"') {ch='\"';}
    		
	}

	ps.push_back(ch);

	SymbolInfo *x=new SymbolInfo(ps.c_str(),"CONST_CHAR");
	yylval.symbol=x;
	ps.clear();
}
/* ----------------------------------------------- */


/* ----------------------------------------------- */
void countNewlineInComment(string s){
	for(int i=1;i<s.length();i++){
		if(s[i]=='\n')
			line++;
	}
}
/* ----------------------------------------------- */


/* ----------------------------------------------- */
void processString(string s){
	
	string str="";

	for(int i=1;i<s.length()-1;i++){
		if(i+1<s.length() && s[i]=='\\' && s[i+1]=='\n')
			i++,line++;
		else
			str.push_back(s[i]);
	}

	printf("%s\n",str.c_str());

	SymbolInfo *x=new SymbolInfo(str.c_str(),"STRING");
	yylval.symbol=x;
}
/* ----------------------------------------------- */

%}


DIGIT [0-9]
DIGITS {DIGIT}+
LETTER [a-zA-Z]
NEWLINE [\n]
WHITESPACE [ \t\f\r\v]+


/* SINGLELINE-COMMENT */
/* ----------------------------------------------- */
SLASH_OR_SLASH_FOLLOWED_BY_NEWLINE ([\\]+([\n])?)?
ANYTHING_EXCEPT_NEWLINE [^\n]*
SINGLE_LINE_COMMENT2 "//"(([\\]+([\n])?)?|[^\n]*)*
SINGLE_LINE_COMMENT "//"({SLASH_OR_SLASH_FOLLOWED_BY_NEWLINE}|{ANYTHING_EXCEPT_NEWLINE})*
/* ---------------------------------------------------------------------------------------- */


/* MULTILINE-COMMENT */
/* ----------------------------------------------- */
STAR_FOLLOWED_BY_ANYTHING_EXCEPT_SLASH \*[^\/]
ANYTHING_EXCEPT_STAR [^*]

MULTILINE_COMMENT ("/*")({ANYTHING_EXCEPT_STAR}|{STAR_FOLLOWED_BY_ANYTHING_EXCEPT_SLASH})*("*/")
/* ---------------------------------------------------------------------------------------- */


/* ---------------------------------------------------------------------------------------- */
/* keywords */
BREAK "break"
CASE "case"
CHAR "char"
CONTINUE "continue"
DEFAULT "default"
DO "do"
DOUBLE "double"
ELSE "else"
FLOAT "float"
FOR "for"
IF "if"
INT "int"
RETURN "return"
SWITCH "switch"
WHILE "while"
VOID "void"
/* ---------------------------------------------------------------------------------------- */


/* ---------------------------------------------------------------------------------------- */
/* operators and punctuators */
ADDOP [+-]
MULOP [*/%]
INCOP ("++")
DECOP ("--")
RELOP (">"|">="|"<"|"<="|"=="|"!=")
ASSIGNOP ("=")
LOGICOP ("&&"|"||")
BITOP ("&"|"|"|"^"|"<<"|">>")
NOT ("!")
LPAREN ("(")
RPAREN (")")
LCURL ("{")
RCURL ("}")
LTHIRD ("[")
RTHIRD ("]")
COMMA (",")
SEMICOLON (";")
PRINTLN "println"
/* ---------------------------------------------------------------------------------------- */



/* ---------------------------------------------------------------------------------------- */

/* --------------------------------- */ 
/* INT */
INTEGER_LITERAL {DIGITS}
/* --------------------------------- */ 


/* --------------------------------- */  
/* FLOAT */ 
EXPONENTIAL ([Ee][-+]?{DIGITS})
FLOAT_VAR_ONE ({DIGITS}\.{DIGITS})({EXPONENTIAL})?
FLOAT_VAR_TWO (\.{DIGITS})({EXPONENTIAL})?
FLOAT_VAR_THREE ({DIGITS})({EXPONENTIAL})?
FLOAT_LITERAL ({FLOAT_VAR_ONE}|{FLOAT_VAR_TWO}|{FLOAT_VAR_THREE})
/* --------------------------------- */


/* --------------------------------- */
/* CHAR */
NORMAL_CHAR '([ -~]{-}['\\])'
SPECIAL_CHAR '(\\[nt\\afrbv0\"])'
CHAR_LITERAL {NORMAL_CHAR}|{SPECIAL_CHAR}
/* --------------------------------- */


/* --------------------------------- */
/* STRING */
SPC_FOR_STR (\\\n|\\\")
NORMAL_CHAR_FOR_STR [^\n\"]
STRING \"({SPC_FOR_STR}|{NORMAL_CHAR_FOR_STR})*\"
/* --------------------------------- */


/* --------------------------------- */
/* Identifiers */
IDENTIFIER [a-zA-Z_][a-zA-Z0-9_]*
/* --------------------------------- */

/* ---------------------------------------------------------------------------------------- */



/* ---------------------------------------------------------------------------------------- */
/* errors */

/*----------------------------------------*/
/*Too many decimal point error for character sequence like 1.2.345*/
FLOAT_VAR_ERR_TD1 ({DIGITS}\.{DIGITS})
FLOAT_VAR_TWO_TD2 (\.{DIGITS})
TOO_MANY_DECIMAL_POINTS_ERROR ({FLOAT_VAR_ERR_TD1}|{FLOAT_VAR_TWO_TD2})({FLOAT_VAR_ERR_TD1}|{FLOAT_VAR_TWO_TD2})*
/*----------------------------------------*/


/*----------------------------------------*/
/*invalid variable name*/
VARIABLE_NAMING_ERROR [0-9][a-zA-Z0-9_]*
/*----------------------------------------*/


/*----------------------------------------*/
/*multichar*/
NCCH ([ -~]{-}['\\])
SPCH (\\[nt\\afrbv0\"])
MULTI_CHAR_ERROR '(({NCCH}|{SPCH})*)'
/*----------------------------------------*/


/*----------------------------------------*/
/* ill formed number */
/* here exponential is a must, after E, there will be a FLOAT_LITERAL */
FLOAT_VAR_ONE_ERR ({DIGITS}\.{DIGITS})([Ee][-+]?)({FLOAT_LITERAL})
FLOAT_VAR_TWO_ERR (\.{DIGITS})([Ee][-+]?)({FLOAT_LITERAL})
FLOAT_VAR_THREE_ERR ({DIGITS})([Ee][-+]?)({FLOAT_LITERAL})
ILL_FORMED_NUM {FLOAT_VAR_ONE_ERR}|{FLOAT_VAR_TWO_ERR}|{FLOAT_VAR_THREE_ERR}
/*----------------------------------------*/


/*----------------------------------------*/
/* unfinished character */
NORMAL_CHAR_FOR_ERR ([ -~]{-}['\\])
SPECIAL_CHAR_FOR_ERR (\\[nt\\afrbv0\"])

UNFINISHED_CHAR_ERROR_ONE '({NORMAL_CHAR_FOR_ERR}|{SPECIAL_CHAR_FOR_ERR})*
SINGLE_FORWARD_SLASH_DETECTOR '[\\]'

UNFINISHED_CHAR_ERROR {UNFINISHED_CHAR_ERROR_ONE}|{SINGLE_FORWARD_SLASH_DETECTOR}
/*----------------------------------------*/


/*----------------------------------------*/
/* Unrecognized character */
UNRECOGNIZED_CHAR .
/*----------------------------------------*/


/*----------------------------------------*/
/* unfinished comment */
UNFINISHED_COMMENT ("/*")({ANYTHING_EXCEPT_STAR}|{STAR_FOLLOWED_BY_ANYTHING_EXCEPT_SLASH})*
/*----------------------------------------*/


/*----------------------------------------*/
/* unfinished string */
UNFINISHED_STRING (\"([^\"\n]|\\[\n])*)
/*----------------------------------------*/


/* rules section */
%%

{SINGLE_LINE_COMMENT} {
	countNewlineInComment(yytext);
}

{MULTILINE_COMMENT} {
	countNewlineInComment(yytext);
}

{PRINTLN} {
	return PRINTLN;
}

{BREAK} {
	return BREAK;
}

{CASE} {
	return CASE;
}

{CHAR} {
	return CHAR;
}

{CONTINUE} {
	return CONTINUE;
}

{DEFAULT} {
	return DEFAULT;
}

{DO} {
	return DO;
}

{DOUBLE} {
	return DOUBLE;
}

{ELSE} {
	return ELSE;
}

{FLOAT} {
	return FLOAT;
}

{FOR} {
	return FOR;
}

{IF} {
	return IF;
}

{INT} {
	return INT;
}

{RETURN} {
	return RETURN;
}

{SWITCH} {
	return SWITCH;
}

{WHILE} {
	return WHILE;
}

{VOID} {
	return VOID;
}

{ADDOP} {
	SymbolInfo *x=new SymbolInfo(yytext,"ADDOP");
	yylval.symbol=x;
	return ADDOP;
}

{MULOP} {
	SymbolInfo *x=new SymbolInfo(yytext,"MULOP");
	yylval.symbol=x;
	return MULOP;
}

{RELOP} {
	SymbolInfo *x=new SymbolInfo(yytext,"RELOP");
	yylval.symbol=x;
	return RELOP;
}

{INCOP} {
	return INCOP;
}

{DECOP} {
	return DECOP;
}

{LOGICOP} {
	SymbolInfo *x=new SymbolInfo(yytext,"LOGICOP");
	yylval.symbol=x;
	return LOGICOP;
}

{BITOP} {
	SymbolInfo *x=new SymbolInfo(yytext,"BITOP");
	yylval.symbol=x;
	return BITOP;
}

{ASSIGNOP} {
	return ASSIGNOP;
}

{NOT} {
	return NOT;
}

{LPAREN} {
	return LPAREN;
}

{RPAREN} {
	return RPAREN;
}

{LCURL} {
	return LCURL;
}

{RCURL} {
	return RCURL;
}

{LTHIRD} {
	return LTHIRD;
}

{RTHIRD} {
	return RTHIRD;
}

{COMMA} {
	return COMMA;
}

{SEMICOLON} {
	return SEMICOLON;
}

{INTEGER_LITERAL} {
	SymbolInfo *x=new SymbolInfo(yytext,"CONST_INT");
	yylval.symbol=x;
	return CONST_INT;
}

{FLOAT_LITERAL} {
	SymbolInfo *x=new SymbolInfo(yytext,"CONST_FLOAT");
	yylval.symbol=x;
	return CONST_FLOAT;
}

{CHAR_LITERAL} {
	processChar(yytext);
	return CONST_CHAR;
}

{STRING} {
	processString(yytext);
}

{IDENTIFIER} {
	SymbolInfo *x=new SymbolInfo(yytext,"ID");
	yylval.symbol=x;
	return ID;
}

{TOO_MANY_DECIMAL_POINTS_ERROR} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: too many decimal point error %s\n\n",line,yytext);

}

{VARIABLE_NAMING_ERROR} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: invalid prefix on ID or invalid suffix on number %s\n\n",line,yytext);
}

{MULTI_CHAR_ERROR} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: multi character constant error %s\n\n",line,yytext);
}

{ILL_FORMED_NUM} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: ill formed number: %s\n\n",line,yytext);
}

{UNFINISHED_CHAR_ERROR} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: unfinished character %s\n\n",line,yytext);
}

{UNFINISHED_COMMENT} {
	cnt_err++;
	fprintf(error,"lexical error at line. %d: unfinished comment found %s\n\n",line,yytext);
}

{UNFINISHED_STRING} {
	cnt_err++;
	fprintf(error,"lexical error at line %d: unfinished string found %s\n\n",line,yytext);
}

{NEWLINE} {
	line++;
}

{WHITESPACE} {
}


%%
