# tests checkout to same branch and creating duplicate branches
legit.pl init
touch b
legit.pl add b
legit.pl branch a 
legit.pl commit -m 'commit-0'
legit.pl checkout a 
legit.pl branch a 
legit.pl checkout a 
legit.pl branch a
legit.pl checkout a 
legit.pl checkout a 
