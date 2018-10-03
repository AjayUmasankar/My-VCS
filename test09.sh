#testing remove
./legit.pl init
touch a
legit.pl add a
legit.pl commit -m 'commit-0'

#remove random error messages
legit.pl rm --force --cached b
legit.pl rm --force --cached --brother
legit.pl rm --force --XD --12


#remove a from cache
legit.pl add a
echo line1 > a
legit.pl status
legit.pl rm --forced a
legit.pl rm --force a-1
legit.pl show :a
legit.pl rm a
legit.pl rm --cached a
legit.pl show :a


#testing remove multiple files
./legit.pl init
touch a
legit.pl add a
legit.pl commit -m 'commit-0'

touch b
legit.pl add a
touch c
legit.pl add b
touch d
legit.pl add d
legit.pl rm a b c
legit.pl rm --cached d
legit.pl status
