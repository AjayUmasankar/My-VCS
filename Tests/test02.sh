legit.pl init
touch a
legit.pl add a
#adding non existing file check
legit.pl add b
# Double commit check
legit.pl commit -m 'commit1'
legit.pl commit -m 'commit2'
