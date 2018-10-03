# check if remove does all or nothing
legit.pl init
touch a
legit.pl add a
legit.pl commit -m 'hi'

rm a a
legit.pl status