%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cgen.h"
#include "lambdalib.h"

#define MAX_STRING_LENGTH 1024 


int yylex(void);
extern int line_num;

//Arrays for composite types
char** comp_function_output = NULL;
char** comp_function_names = NULL;
char** cfnames = NULL;
char** comp_names = NULL;

//Counters
int num_functions = 0;
int num_comps = 0;
int total_functions = 0;

//flag
int cflag = 0; //Flag to know when -> is needed

//Buffers
char* buffer;
char* namebuffer;
%}



%union
{
  char* crepr;
}

%define parse.error verbose



%token <crepr> TK_IDENTIFIER
%token <crepr> TK_INTEGER
%token <crepr> TK_FLOAT
%token <crepr> TK_STRING



//Keywords
%token KW_INTEGER
%token KW_SCALAR
%token KW_STR
%token KW_BOOL
%token KW_TRUE
%token KW_FALSE
%token KW_CONST
%token KW_IF
%token KW_ELSE
%token KW_ENDIF
%token KW_FOR
%token KW_IN
%token KW_ENDFOR
%token KW_WHILE
%token KW_ENDWHILE
%token KW_BREAK
%token KW_CONTINUE
%left KW_NOT
%left KW_AND
%left KW_OR
%token KW_DEF
%token KW_ENDDEF
%token KW_MAIN
%token KW_RETURN
%token KW_COMP
%token KW_ENDCOMP
%token KW_OF




//Arithmetic operators
%left OP_PLUS
%left OP_MINUS
%left OP_MULT
%left OP_DIV
%left OP_MOD
%right OP_POWER

//Relational operators
%left REL_EQUALS
%left REL_NOTEQUALS
%left REL_LESS
%left REL_LESSEQUALS
%left REL_MORE
%left REL_MOREEQUALS

//Assignment operators
%right ASGN_ASSIGN
%right ASGN_HASHASSIGN
%right ASGN_PLUSASSIGN 
%right ASGN_MINASSIGN
%right ASGN_MULASSIGN
%right ASGN_DIVASSIGN
%right ASGN_MODASSIGN
%right ASGN_COLONASSIGN
%right ASGN_ARROWASSIGN


//Delimiters
%token DEL_SEMICOLON
%left DEL_LPAR
%left DEL_RPAR
%token DEL_COMMA
%left DEL_LARR
%left DEL_RARR
%token DEL_COLON
%left DEL_DOT



//Main
%type <crepr> main
%type <crepr> main_body
%type <crepr> body
%type <crepr> declarations
%type <crepr> decl_body


//Declarations
%type <crepr> types
%type <crepr> basic_types
%type <crepr> composite_type_declarations
%type <crepr> comp_variable_declarations
%type <crepr> constant_declarations
%type <crepr> variable_declarations
%type <crepr> parameter_declarations
%type <crepr> comp_functions
%type <crepr> comp_body
%type <crepr> comp_identifiers
%type <crepr> comp_variables

%type <crepr> program
%type <crepr> identifiers
%type <crepr> expressions
%type <crepr> identifier_expressions
%type <crepr> arithmetic_expressions
%type <crepr> relational_expressions
%type <crepr> comp_expressions
%type <crepr> assign_expressions 
%type <crepr> functions
%type <crepr> function_arg
%type <crepr> empty_function_body

%type <crepr> statements
%type <crepr> command_statements
%type <crepr> if_statement
%type <crepr> for_statement
%type <crepr> array_statement
%type <crepr> while_statement
%type <crepr> return_statement
%type <crepr> integral_array
%type <crepr> other_array
%type <crepr> function_statement



%start program

%%

//The prologue for the generated C code, helps for visualisation in terminal too
program:
      main_body                  
      {   
       
          $$ = template("%s",$1); 
          if (yyerror_count == 0) 
          {     
                FILE *fp = fopen("bisonout.c","w");

                printf("\n\t\t\tGENERATED C CODE\n");
                printf("========================================================== \n");
                printf("\n%s\n", $1);
                printf("\n========================================================== \n");
                printf("\t\t\tC CODE END\n");
                fputs("#include <stdio.h>\n",fp);
                fputs("#include <math.h>\n",fp);
                fputs("#include <stdlib.h>\n",fp);
                fputs("#include <string.h>\n",fp);
                fputs("#include <stdbool.h>\n",fp);
                fputs(c_prologue,fp);
                fprintf(fp,"%s\n", $1);
                
                fclose(fp);               
          }
      };


//The body of the main function
main_body: 
  decl_body main { $$ = template("%s\n%s\n",$1,$2); }
  | main { $$ = $1; };


//The main function
main: 
  KW_DEF KW_MAIN DEL_LPAR DEL_RPAR DEL_COLON body KW_ENDDEF DEL_SEMICOLON {$$ = template("int main(){\n%s\n}", $6);};



//Types
types:
  DEL_LARR DEL_RARR basic_types { $$ = template("%s*", $3); }
  | basic_types { $$ = $1; }
  | TK_IDENTIFIER {
    //Checking if there is a composite type with the name
    int found = 0;
      for (int i = 0; i < num_comps; i++) {
        if (strcmp(comp_names[i], $1) == 0) {
          found = 1;
          $$ = $1;
          break;
        }
      }
      if (found == 0) {
      }
  }

//The basic types
basic_types:
	KW_INTEGER {$$ = template("%s", "int");}
|	KW_BOOL {$$ = template("%s", "int");}	//Using ints to represent booleans
|	KW_SCALAR {$$ = template("%s","double");}
|	KW_STR {$$ = template("%s", "char*");};


//One or more identifiers
identifiers:
	TK_IDENTIFIER  {$$ = $1;}
	| identifiers DEL_COMMA TK_IDENTIFIER {$$ = template("%s, %s", $1,$3);};



//Declaration body, recursive to tackle multiple declarations
decl_body:
  decl_body declarations { $$ = template("%s\n%s", $1, $2); }
  | declarations { $$ = $1; };


//Declarations
declarations:
  variable_declarations { $$ = $1; }
  | composite_type_declarations { $$ = $1; } 
  | constant_declarations { $$ = $1; }
  | functions { $$ = $1; };

//Variable declarations
variable_declarations:
	identifiers DEL_COLON basic_types DEL_SEMICOLON {$$ = template("%s %s; ", $3, $1); }
  | TK_IDENTIFIER DEL_LARR TK_INTEGER DEL_RARR DEL_COLON basic_types DEL_SEMICOLON {$$ = template("%s %s[%s]; ", $6, $1, $3); }

//Composite type variables
comp_variables:
  identifiers DEL_COLON TK_IDENTIFIER DEL_SEMICOLON {$$ = template("%s %s = ctor_%s; ", $3, $1, $3); }

//Constant declarations
constant_declarations:
	KW_CONST identifiers ASGN_ASSIGN expressions DEL_COLON types DEL_SEMICOLON {$$ = template("const %s %s = %s;", $6, $2, $4);};




//Cases for functions
functions: 
  KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR DEL_COLON body KW_ENDDEF DEL_SEMICOLON {$$ = template("\nvoid %s(%s) {\n%s\n}\n", $2, $4, $7);}
  | KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR ASGN_ARROWASSIGN types DEL_COLON body KW_ENDDEF DEL_SEMICOLON {$$ = template("\n%s %s(%s) {\n%s\n\n}\n", $7, $2, $4, $9);};
  | KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR DEL_COLON empty_function_body KW_ENDDEF DEL_SEMICOLON {$$ = template("\nvoid %s(%s) {\n\n}\n", $2, $4);}

//Empty function body
empty_function_body:
  %empty { $$ = ""; };

//Parameter declarations
parameter_declarations: 
  %empty { $$ = "" ;}
  | TK_IDENTIFIER DEL_COLON types {$$ = template("%s %s", $3, $1);}
  | TK_IDENTIFIER DEL_LARR DEL_RARR DEL_COLON types {$$ = template("%s *%s", $5, $1);}
  | TK_IDENTIFIER DEL_LARR DEL_RARR DEL_COLON types DEL_COMMA parameter_declarations {$$ = template("%s *%s, %s", $5, $1, $7);}
  | TK_IDENTIFIER DEL_COLON types DEL_COMMA parameter_declarations {$$ = template("%s %s, %s", $3, $1, $5);};




//Composite type declarations
composite_type_declarations:
  KW_COMP TK_IDENTIFIER DEL_COLON comp_body KW_ENDCOMP DEL_SEMICOLON { 
    cflag = 0; //Reset the composite flag, so that we dont use -> in the functions
    
    //Use buffers to get the names and the functions, initializing them to empty strings
    buffer = malloc(1);
    buffer[0] = '\0';
    namebuffer = malloc(1);
    namebuffer[0] = '\0';


    //Allocating the memory for the comp_function_output and comp_function_names
    for (int i = 0; i < num_functions; i++) {
      char* curr_string = comp_function_output[i];
      char* name_string = comp_function_names[i];

      buffer = realloc(buffer,  strlen(buffer) + strlen(curr_string) + 3); //The +3 is for 2 new lines and the null terminator

      namebuffer = realloc(namebuffer, strlen(namebuffer) + strlen(name_string) + 3); //The +3 is for a comma, a space and the null terminator


      //Append the current string to the buffer
      strcat(buffer, curr_string);
      strcat(namebuffer, name_string);

      if (i != num_functions -1) { //Appending the delimiters
        strcat(buffer, "\n\n");
        strcat(namebuffer, ", ");
      }


    }

    //Counter update
    num_comps = num_comps + 1;

    //Allocating the memory for the comp_names
    comp_names = realloc(comp_names, num_comps * sizeof(char*));

    //Allocating the memory for the comp_names
    comp_names[num_comps - 1] = malloc(MAX_STRING_LENGTH * sizeof(char));

    //Copying the name to the comp_names
    comp_names[num_comps - 1] = strdup(template("%s", $2)); 

    //The final output
    $$ = template("\n#define SELF struct %s *self\ntypedef struct %s {\n%s\n} %s;\n\n%s\n\nconst %s ctor_%s = { %s };\n#undef SELF", $2, $2, $4, $2, buffer, $2, $2, namebuffer); 

   
    num_functions = 0;
    };


//Composite type body
comp_body:
  comp_variable_declarations { $$ = $1; }
  | comp_variable_declarations comp_body {$$ = template("%s\n%s", $1, $2);}
  | comp_functions { $$ = $1; }
  | comp_functions comp_body {$$ = template("%s\n%s", $1, $2);};

//Composite type variable declarations
comp_variable_declarations:
  comp_identifiers DEL_COLON types DEL_SEMICOLON {
  //Raise the flag, so that we use ->
  cflag = 1;
  $$ = template("%s %s;", $3, $1);};
  

//Composite type identifiers
comp_identifiers:
  ASGN_HASHASSIGN TK_IDENTIFIER { $$ = $2; }
  | ASGN_HASHASSIGN TK_IDENTIFIER DEL_LARR TK_INTEGER DEL_RARR {$$ = template("%s[%s]", $2, $4);};
  | ASGN_HASHASSIGN TK_IDENTIFIER DEL_COMMA comp_identifiers {$$ = template("%s, %s", $2, $4);};
  
//Composite type functions
comp_functions:
  KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR DEL_COLON body KW_ENDDEF DEL_SEMICOLON 
  {
    //Add our function to the comp_function_output and comp_function_names
    //Counter update
    num_functions = num_functions + 1;
    total_functions = total_functions + 1;

    //Allocating the memory for the comp_function_output and comp_function_names
    comp_function_output = realloc(comp_function_output, num_functions * sizeof(char*));

    comp_function_names = realloc(comp_function_names, num_functions * sizeof(char*));

    cfnames = realloc(cfnames, total_functions * sizeof(char*));


    //Allocating the memory for the comp_function_output and comp_function_names
    comp_function_output[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char));

    comp_function_names[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));

    cfnames[total_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));
    
    //Copying the name,body and the function to the comp_function_output and comp_function_names and cf_names 
    comp_function_output[num_functions - 1] = strdup(template("void %s(SELF%s%s) {\n%s\n} ", $2, strlen($4) != 0  ? ", " : "", $4, $7)); 

    comp_function_names[num_functions - 1] = strdup(template(".%s=%s", $2, $2));

    cfnames[total_functions - 1] = strdup(template("%s", $2));

    //Returns the function signature, void (*function_name)(SELF, parameters)
    $$ = template("\nvoid (*%s)(SELF%s%s);", $2, ($4[0] != '\0') ? ", " : "", $4);
    } 

  | KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR ASGN_ARROWASSIGN types DEL_COLON body KW_ENDDEF DEL_SEMICOLON 
  { 
    //Add our function to the comp_function_output and comp_function_names
    //Counter update
    num_functions = num_functions +1;
    total_functions = total_functions + 1;

    //Allocating the memory for the comp_function_output and comp_function_names
    comp_function_output = realloc(comp_function_output, num_functions * sizeof(char*));

    comp_function_names = realloc(comp_function_names, num_functions * sizeof(char*));

    cfnames = realloc(cfnames, total_functions * sizeof(char*));


    //Allocating the memory for the comp_function_output and comp_function_names
    comp_function_output[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char));

    comp_function_names[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));

    cfnames[total_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));

    //Copying the name,body and the function to the comp_function_output and comp_function_names and cf_names 
    cfnames[total_functions - 1] = strdup(template("%s", $2));

    comp_function_output[num_functions - 1] = strdup(template("%s %s(SELF%s%s) {\n%s\n} ", $7, $2, ($4[0] != '\0') ? ", " : "", $4 ,$9));

    comp_function_names[num_functions - 1] = strdup(template(".%s=%s", $2, $2));

    //Returns the function signature, type (*function_name)(SELF, parameters)
    $$ = template("\n%s (*%s)(SELF%s%s);", $7, $2, ($4[0] != '\0') ? ", " : "", $4);
    }
    | KW_DEF TK_IDENTIFIER DEL_LPAR parameter_declarations DEL_RPAR DEL_COLON empty_function_body KW_ENDDEF DEL_SEMICOLON 
    { 
      num_functions = num_functions + 1;
      total_functions = total_functions + 1;

      // allocate space
      comp_function_output = realloc(comp_function_output, num_functions * sizeof(char*));
      comp_function_names = realloc(comp_function_names, num_functions * sizeof(char*));
      cfnames = realloc(cfnames, total_functions * sizeof(char*));
      
      comp_function_output[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char));
      comp_function_names[num_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));
      cfnames[total_functions - 1] = malloc(MAX_STRING_LENGTH * sizeof(char*));
      
      cfnames[total_functions - 1] = strdup(template("%s", $2));
      comp_function_output[num_functions - 1] = strdup(template("void %s(SELF%s%s) {\n\n} ", $2, ($4[0] != '\0') ? ", " : "", $4));
      comp_function_names[num_functions - 1] = strdup(template(".%s=%s", $2, $2));

      //Returns the function signature, void (*function_name)(SELF, parameters)
      $$ = template("\nvoid (*%s)(SELF%s%s);", $2, ($4[0] != '\0') ? ", " : "", $4);
    }




//Expressions
expressions:
  identifier_expressions { $$ = $1; }
  | TK_STRING {$$ = $1;}
  | KW_TRUE {$$ = template("%s", "1");}
  | KW_FALSE {$$ = template("%s", "0");}
  | function_statement { $$ = $1; }
  | arithmetic_expressions { $$ = $1; }
  | relational_expressions { $$ = $1; }
  | KW_NOT expressions {$$ = template("! %s", $2);}
  | expressions KW_AND expressions {$$ = template("%s && %s", $1, $3);}
  | expressions KW_OR expressions {$$ = template("%s || %s", $1, $3);}
  | DEL_LPAR expressions DEL_RPAR {$$ = template("(%s)", $2);};


//Composite expressions
comp_expressions:
  expressions DEL_DOT expressions { 
    //Change the output string so that it includes the &
    //We put '&chz' in the function and when we find it we change it with &expr1
    //If we dont find find 'a' it means the secnd arg is not a fun arg so we change nothing

    char* old_str = $3; // expr
    char* new_str = NULL; // new expr
    const char* search_str = "&chz"; // elm in expression
    char* replace_str = NULL; // a[a_i]

    // Create a[a_i]
    // supress a warning
    #pragma GCC diagnostic ignored "-Wimplicit-function-declaration"
    asprintf(&replace_str, "&%s", $1);

    // Find the first occurrence of elm in expr
    char* pos = strstr(old_str, search_str);

    if (pos != NULL) {
        // Find the possition of occurance in expr
        int index = pos - old_str;

        // Allocate memory
        new_str = (char*) malloc(strlen(old_str) - strlen(search_str) + strlen(replace_str) + 1);

        // Copy the part of the old expr
        strncpy(new_str, old_str, index);

        // Append the new expr to expr
        strcat(new_str, replace_str);

        // Copy the rest of the expr
        strcat(new_str, old_str + index + strlen(search_str));
    } else {
        new_str = old_str;
    }

    $$ = template("%s.%s", $1, new_str); };
  
//Identifier expressions
identifier_expressions:
  TK_IDENTIFIER { $$ = $1; }
  | ASGN_HASHASSIGN TK_IDENTIFIER { 
    //printf("\nflag: %d\n", cflag);
    if (cflag == 1) {$$ = template("self->%s", $2);}
    else {$$ = template("%s", $2);} }
  | ASGN_HASHASSIGN TK_IDENTIFIER DEL_LARR identifier_expressions DEL_RARR { 
    if (cflag == 1) {$$ = template("self->%s[%s]", $2, $4);}
    else {$$ = template("%s[%s]", $2, $4);} }
  | TK_IDENTIFIER DEL_LARR TK_INTEGER DEL_RARR { $$ = template("%s[%s]", $1, $3); }
  | TK_IDENTIFIER DEL_LARR TK_IDENTIFIER DEL_RARR { $$ = template("%s[%s]", $1, $3); }
  | comp_expressions { $$ = $1; };

//Arithmetic expressions
arithmetic_expressions:
  TK_INTEGER {$$ = $1;}
  | TK_FLOAT {$$ = $1;}
  | expressions OP_POWER expressions {$$ = template("pow(%s, %s)", $1, $3);}
  | expressions OP_MULT expressions {$$ = template("%s * %s",$1, $3);}
  | expressions OP_DIV expressions {$$ = template("%s / %s", $1, $3);}
  | expressions OP_MOD expressions {$$ = template("%s %% %s", $1, $3);}
  | expressions OP_PLUS expressions {$$ = template("%s + %s", $1, $3);}
  | expressions OP_MINUS expressions {$$ = template("%s - %s", $1, $3);}
  | OP_PLUS expressions {$$ = template("+%s", $2);}
  | OP_MINUS expressions {$$ = template("-%s", $2);};

//Relational expressions
relational_expressions:
  expressions REL_LESS expressions {$$ = template("%s < %s",$1, $3);}
  | expressions REL_LESSEQUALS expressions {$$ = template("%s <= %s", $1, $3);}
  | expressions REL_MORE expressions {$$ = template("%s > %s", $1, $3);}
  | expressions REL_MOREEQUALS expressions {$$ = template("%s >= %s", $1, $3);}
  | expressions REL_EQUALS expressions {$$ = template("%s == %s", $1, $3);}
  | expressions REL_NOTEQUALS expressions {$$ = template("%s != %s", $1, $3);};

//Assignment expressions
assign_expressions:
  identifier_expressions ASGN_ASSIGN expressions {$$ = template("%s = %s", $1, $3);}
  | identifier_expressions ASGN_PLUSASSIGN expressions {$$ = template("%s += %s", $1, $3);}
  | identifier_expressions ASGN_MINASSIGN expressions {$$ = template("%s -= %s" , $1, $3);}
  | identifier_expressions ASGN_MULASSIGN expressions {$$ = template("%s *= %s", $1, $3);}
  | identifier_expressions ASGN_DIVASSIGN expressions {$$ = template("%s /= %s", $1, $3);}
  | identifier_expressions ASGN_MODASSIGN expressions {$$ = template("%s %= %s", $1, $3);}; 


//Statements
statements:
  if_statement DEL_SEMICOLON { $$ = template("%s", $1); }
  | for_statement DEL_SEMICOLON { $$ = template("%s", $1); }
  | array_statement DEL_SEMICOLON { $$ = template("%s;", $1); }
  | while_statement DEL_SEMICOLON { $$ = template("%s", $1); }
  | KW_BREAK DEL_SEMICOLON {$$ = template("break;");}
  | KW_CONTINUE DEL_SEMICOLON {$$ = template("continue;");}
  | assign_expressions DEL_SEMICOLON {$$ = template("%s;", $1);}; 
  | return_statement DEL_SEMICOLON { $$ = template("%s;", $1); }
  | function_statement DEL_SEMICOLON { $$ = template("%s;", $1); };
  | comp_expressions DEL_SEMICOLON { $$ = template("%s;", $1); };

//Command statements
command_statements:
  statements { $$ = template("%s", $1); }
  | command_statements statements { $$ = template("%s\n%s", $1, $2); }
  | command_statements variable_declarations { $$ = template("%s\n%s", $1, $2); }
  | variable_declarations { $$ = $1; }
  | command_statements constant_declarations { $$ = template("%s\n%s", $1, $2); }
  | constant_declarations { $$ = template("%s", $1); };


//IF statements
if_statement:
  KW_IF DEL_LPAR expressions DEL_RPAR DEL_COLON command_statements KW_ENDIF {$$ = template("if (%s) {\n%s\n}", $3, $6);}
  | KW_IF DEL_LPAR expressions DEL_RPAR DEL_COLON command_statements KW_ELSE DEL_COLON command_statements KW_ENDIF {$$ = template("if (%s) {\n%s\n} else {\n%s\n}", $3, $6, $9);};


//FOR statements
for_statement:
  KW_FOR identifiers KW_IN DEL_LARR expressions DEL_COLON expressions DEL_RARR DEL_COLON command_statements KW_ENDFOR  {$$ = template("for (int %s = %s; %s < %s; %s++) {\n%s\n}", $2, $5, $2, $7, $2, $10);}
  | KW_FOR identifiers KW_IN DEL_LARR expressions DEL_COLON expressions DEL_COLON expressions DEL_RARR DEL_COLON command_statements KW_ENDFOR {$$ = template("for (int %s = %s; %s < %s; %s = %s + %s) {\n%s\n}", $2, $5, $2, $7, $2, $2, $9, $12);};


//Array statements
array_statement:
  integral_array { $$ = $1; }
  | other_array { $$ = $1; };

//Integral array
integral_array:
  TK_IDENTIFIER ASGN_COLONASSIGN DEL_LARR expressions KW_FOR TK_IDENTIFIER DEL_COLON TK_INTEGER DEL_RARR DEL_COLON types {$$ = template("%s* %s = (%s*)malloc(%s*sizeof(%s));\nfor(%s %s = 0; %s < %s; ++%s) {\n %s[%s] = %s;\n}", $11, $1, $11, $8, $11, $11, $6, $6, $8, $6, $1, $6, $4);};

//Handling other arrays
other_array:
  TK_IDENTIFIER ASGN_COLONASSIGN DEL_LARR expressions KW_FOR TK_IDENTIFIER DEL_COLON types KW_IN TK_IDENTIFIER KW_OF TK_INTEGER DEL_RARR DEL_COLON types {  
    char* old_str = $4; // expr
    char* new_str = NULL; // new expr
    const char* search_str = $6; // elm in expression
    char* replace_str = NULL; // a[a_i]

    // Create a[a_i]
    // supress a warning
    #pragma GCC diagnostic ignored "-Wimplicit-function-declaration"
    asprintf(&replace_str, "%s[%s_i]", $10, $10);

    // Find the first occurrence of elm in expr
    char* pos = strstr(old_str, search_str);

    if (pos != NULL) {
        // Find the possition of occurance in expr
        int index = pos - old_str;

        // Allocate memory
        new_str = (char*) malloc(strlen(old_str) - strlen(search_str) + strlen(replace_str) + 1);

        // Copy the part of the old expr
        strncpy(new_str, old_str, index);

        // Append the new expr to expr
        strcat(new_str, replace_str);

        // Copy the rest of the expr
        strcat(new_str, old_str + index + strlen(search_str));
    } else {
        // If search_str is not found, copy the old_str to the new_str
        yyerror("No element %s found in expression %s", $6, $4);
        YYERROR;
    }

    
    $$ = template("%s* %s = (%s*)malloc(%s*sizeof(%s));\nfor(int %s_i = 0; %s_i < %s; ++%s_i) {\n\t%s[%s_i] = %s;\n}", $15, $1, $15, $12, $15, $10, $10, $12, $10, $1, $10, new_str);

    // Free the memory allocated
    free(new_str); 
    free(replace_str);
    free(old_str);};


//WHILE statements
while_statement:
  KW_WHILE DEL_LPAR expressions DEL_RPAR DEL_COLON command_statements KW_ENDWHILE {$$ = template("while (%s) {\n%s\n}", $3, $6);};
  
 
//RETURN statements
return_statement:
  KW_RETURN {$$ = template("return");}
  | KW_RETURN expressions {$$ = template("return %s", $2);};


//Function statements
function_statement:
  TK_IDENTIFIER DEL_LPAR DEL_RPAR {
  //Check if there exists a composite function declared with that name
  int found = 0;
  char* a = "&chz";
  for (int i=0; i < total_functions; i++) {
    if (strcmp(cfnames[i], $1) == 0){
      $$ = template("%s(%s)", $1, a);
      found = 1;
      break;       
    }
  } 
  if (found == 0) {
    $$ = template("%s()", $1);
    }
  }
  | TK_IDENTIFIER DEL_LPAR function_arg DEL_RPAR {
 
  //Check if there exists a composite function declared with that name
  int found = 0;
  char* a = "&chz";
  for (int i=0; i < total_functions; i++) {
    if (strcmp(cfnames[i], $1) == 0){
      $$ = template("%s(%s, %s)", $1, a, $3);
      found = 1;
      break;       
    }
  } 
  if (found == 0) {
    $$ = template("%s(%s)", $1, $3);
    }
  };
  
//Function arguments
function_arg:
  expressions { $$ = template("%s", $1);}
  | expressions DEL_COMMA function_arg { $$ = template("%s, %s", $1, $3); }

//The body of the program
body: 
  statements { $$ = $1; }
  | variable_declarations { $$ = $1; }
  | constant_declarations { $$ = $1; }
  | comp_variables { $$ = $1; }
  | body statements { $$ = template("%s\n%s", $1, $2); }
  | body variable_declarations { $$ = template("%s\n%s", $1, $2); }
  | body constant_declarations { $$ = template("%s\n%s", $1, $2); }
  | body comp_variables { $$ = template("%s\n%s", $1, $2); };

%%

//Our main
int main(void) {
  if ( yyparse() != 0 )
  printf("\nRejected!\n");
}