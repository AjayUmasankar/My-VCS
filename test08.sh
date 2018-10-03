
./legit.pl init
touch a
legit.pl add a
legit.pl commit -m 'commit-0'
rm a
legit.pl status

touch a
legit.pl status
legit.pl rm a
legit.pl status

touch b 
legit.pl add b
legit.pl commit -m 'commit-b'
legit.pl status
legit.pl rm b
legit.pl status

touch c
legit.pl status
