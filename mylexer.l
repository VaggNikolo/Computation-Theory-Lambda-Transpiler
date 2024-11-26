%{
  #include <stdio.h>
  #include <string.h>
  #include <stdlib.h>
  #include "cgen.h"
  #include "myparser.tab.h"

  int line_num = 1;

  void showError();

  int macro_count = 0;
  int macro_existing = -1;
  char* macro_table[50];
  char macro_table_names[50][32];

  char* get_macro_value(const char* identifier) {
    for (int i = macro_count - 1; i >= 0; i--) {
      if (strcmp(macro_table_names[i], identifier) == 0) {
        return macro_table[i];
      }
    }
    return NULL;
  }
%}

DIGIT  [0-9]

IDENTIFIERS                 [a-zA-Z][0-9a-zA-Z_]*
INTEGER_CONSTANTS           ({DIGIT}+)
FLOATING_POINT_CONSTANTS    ([+-]?{DIGIT}*\.{DIGIT}+([Ee][+-]?{DIGIT}+)?|{DIGIT}+\.{DIGIT}*([Ee][+-]?{DIGIT}+)?)
CONSTANT_STRINGS            (\"(([^\"\\]|\\[ntr\\"'])*)\")
MACRO_VAL                   [^ \n]+

%x line_comment
%x macro_def

%%

"@defmacro"                 { BEGIN(macro_def); }

<macro_def>{IDENTIFIERS}    {
                              macro_existing = -1;
                              for (int i = 0; i < macro_count; i++) {
                                  if (!strcmp(macro_table_names[i], yytext)) {
                                      macro_existing = i;
                                  }
                              }
                              if (macro_existing == -1) {
                                  strcpy(macro_table_names[macro_count], yytext);
                              }
                            }
<macro_def>{MACRO_VAL}      {
                              if (macro_existing == -1) {
                                  macro_table[macro_count] = strdup(yytext);
                                  macro_count++;
                              } else {
                                  free(macro_table[macro_existing]);
                                  macro_table[macro_existing] = strdup(yytext);
                                  macro_existing = -1;
                              }
                              BEGIN(INITIAL);
                            }
                          
<macro_def>{CONSTANT_STRINGS} {
                              if (macro_existing == -1) {
                                  macro_table[macro_count] = strdup(yytext);
                                  macro_count++;
                              } else {
                                  free(macro_table[macro_existing]);
                                  macro_table[macro_existing] = strdup(yytext);
                                  macro_existing = -1;
                              }
                              BEGIN(INITIAL);
}
                            

"integer"                   { return KW_INTEGER; }
"scalar"                    { return KW_SCALAR; }
"str"                       { return KW_STR; }
"bool"                      { return KW_BOOL; }
"True"                      { return KW_TRUE; }
"False"                     { return KW_FALSE; }
"const"                     { return KW_CONST; }
"if"                        { return KW_IF; }
"else"                      { return KW_ELSE; }
"endif"                     { return KW_ENDIF; }
"for"                       { return KW_FOR; }
"in"                        { return KW_IN; }
"endfor"                    { return KW_ENDFOR; }
"while"                     { return KW_WHILE; }
"endwhile"                  { return KW_ENDWHILE; }
"break"                     { return KW_BREAK; }
"continue"                  { return KW_CONTINUE; }
"not"                       { return KW_NOT; }
"and"                       { return KW_AND; }
"or"                        { return KW_OR; }
"def"                       { return KW_DEF; }
"enddef"                    { return KW_ENDDEF; }
"main"                      { return KW_MAIN; }
"return"                    { return KW_RETURN; }
"comp"                      { return KW_COMP; }
"endcomp"                   { return KW_ENDCOMP; }
"of"                        { return KW_OF; }

{IDENTIFIERS}               {
                              char* macro_value = get_macro_value(yytext);
                              if (macro_value) {
                                for (int i = strlen(macro_value) - 1; i >= 0; i--) {
                                  unput(macro_value[i]);
                                }
                              } else {
                                yylval.crepr = strdup(yytext);
                                return TK_IDENTIFIER;                           
                              }
                            }
{INTEGER_CONSTANTS}         { yylval.crepr = strdup(yytext); return TK_INTEGER; }
{FLOATING_POINT_CONSTANTS}  { yylval.crepr = strdup(yytext); return TK_FLOAT; }
{CONSTANT_STRINGS}          { yylval.crepr = strdup(yytext); return TK_STRING; }

"+"                         { return OP_PLUS; }
"-"                         { return OP_MINUS; }
"*"                         { return OP_MULT; }
"/"                         { return OP_DIV; }
"%"                         { return OP_MOD; }
"**"                        { return OP_POWER; }

"=="                        { return REL_EQUALS; }
"!="                        { return REL_NOTEQUALS; }
"<"                         { return REL_LESS; }
"<="                        { return REL_LESSEQUALS; }
">"                         { return REL_MORE; }
">="                        { return REL_MOREEQUALS; }

"="                         { return ASGN_ASSIGN; }
"#"                         { return ASGN_HASHASSIGN; }
"+="                        { return ASGN_PLUSASSIGN; }
"-="                        { return ASGN_MINASSIGN; }
"*="                        { return ASGN_MULASSIGN; }
"/="                        { return ASGN_DIVASSIGN; }
"%="                        { return ASGN_MODASSIGN; }
":="                        { return ASGN_COLONASSIGN; }
"->"                        { return ASGN_ARROWASSIGN; }

";"                         { return DEL_SEMICOLON; }
"("                         { return DEL_LPAR; }
")"                         { return DEL_RPAR; }
","                         { return DEL_COMMA; }
"["                         { return DEL_LARR; }
"]"                         { return DEL_RARR; }
":"                         { return DEL_COLON; }
"."                         { return DEL_DOT; }

[ \r\t]+                    /* skip whitespace */
\n                          { ++line_num; }

"--"                        { BEGIN(line_comment); }
<line_comment>[^\n]*        /* Eat all one line comments */
<line_comment>\n            { ++line_num; BEGIN(INITIAL); }

<<EOF>>                     { return 0; /* Marks end of file */ }
.                           { showError(); }

%%

void showError() {
  printf("Unrecognized token %s in line %d\n", yytext, line_num);
  exit(-1);
}
