# Checking unknown command error messages before and after .legit is initialized
./legit.pl he
./legit.pl adda
./legit.pl inita

# all commands with 0 args
./legit.pl init
./legit.pl rm
./legit.pl log
./legit.pl show
#./legit.pl add
./legit.pl commit
./legit.pl status
./legit.pl branch
./legit.pl checkout
./legit.pl merge

#all commands with 1 args
./legit.pl init
./legit.pl init a 
./legit.pl rm a 
./legit.pl log a 
./legit.pl show a 
#./legit.pl add
./legit.pl commit a 
./legit.pl status a 
./legit.pl branch a 
./legit.pl checkout a 
./legit.pl merge a 

#all commands with 2 args
./legit.pl init
./legit.pl init a a 
./legit.pl rm a a 
./legit.pl log a a 
./legit.pl show a a 
#./legit.pl add
./legit.pl commit a a 
./legit.pl status a a 
./legit.pl branch a a 
./legit.pl checkout a a 
./legit.pl merge a a 

#all commands with 3 args
./legit.pl init
./legit.pl init a a a 
./legit.pl rm a a a 
./legit.pl log a a a 
./legit.pl show a a a 
#./legit.pl add
./legit.pl commit a a a 
./legit.pl status a a a 
./legit.pl branch a a a 
./legit.pl checkout a a a 
./legit.pl merge a a a 

#all commands with 4 args
./legit.pl init
./legit.pl init a a a a 
./legit.pl rm a a a a 
./legit.pl log a a a a 
./legit.pl show a a a a 
#./legit.pl add
./legit.pl commit a a a a 
./legit.pl status a a a a 
./legit.pl branch a a a a 
./legit.pl checkout a a a a 
./legit.pl merge a a a a 

#all commands with 5 args
./legit.pl init
./legit.pl init a a a a a 
./legit.pl rm a a a a a 
./legit.pl log a a a a a 
./legit.pl show a a a a a 
#./legit.pl add
./legit.pl commit a a a a a 
./legit.pl status a a a a a 
./legit.pl branch a a a a a 
./legit.pl checkout a a a a a 
./legit.pl merge a a a a a 

#all commands with 5 args with '-'
./legit.pl init
./legit.pl init a a a a a -a
./legit.pl rm a a a a a -a
./legit.pl log a a a a a -a
./legit.pl show a a a a a -a
#./legit.pl add
./legit.pl commit a a a a a -a
./legit.pl status a a a a a -a
./legit.pl branch a a a a a -a
./legit.pl checkout a a a a a -a
./legit.pl merge a a a a a -a
