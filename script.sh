bison -d -v -r all myparser.y
flex mylexer.l
gcc -o mycompiler lex.yy.c myparser.tab.c cgen.c -lfl
./mycompiler < test.la
gcc -o cfilename bisonout.c
./cfilename
