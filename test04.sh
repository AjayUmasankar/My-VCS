#testing error messages for show

./legit.pl init
touch c
legit.pl add c
legit.pl commit -m 'commit-0'
legit.pl show 0:c

#invalid commitnumbers
legit.pl show a:c
legit.pl show a:0
legit.pl show /:0
legit.pl show c:0
legit.pl show :0
legit.pl show .:

#invalid filenames
legit.pl show 0:
legit.pl show 0
legit.pl show 0:>c
legit.pl show 0:.c
legit.pl show 0:(c
legit.pl show 0:/c

#random tests
legit.pl show .:?
legit.pl show :::0:c
legit.pl show 0:c:::::
legit.pl show :
legit.pl show c
legit.pl show 0c
legit.pl show
legit.pl show 0:c a a
legit.pl show 0:c 0:c
