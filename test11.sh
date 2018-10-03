#test if add does all or nothing
legit.pl init
touch a
touch b
legit.pl add a
legit.pl commit -m 'hi'

touch c
touch d
legit.pl add e c d
legit.pl show :c
legit.pl show :d
legit.pl show :e
legit.pl show :a
legit.pl status
