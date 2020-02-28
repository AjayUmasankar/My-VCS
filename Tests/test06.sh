
./legit.pl init

# testing if file in index is updated with commit -a when the file no longer exists
# and when the file is changed
touch a
legit.pl add a
legit.pl commit -m 'commit-0'
rm a
legit.pl commit -m 'commit-1'
legit.pl show 0:a
legit.pl show 1:a
legit.pl status
legit.pl commit -a -m 'commit-1'
legit.pl show 0:a
legit.pl show 1:a
legit.pl status


./legit.pl init
touch b
legit.pl add b
legit.pl commit -m 'commit-0'
echo line1 >b
legit.pl commit -m 'commit-1'
legit.pl show 0:b
legit.pl show 1:b
legit.pl status
legit.pl commit -a -m 'commit-1'
legit.pl show 0:b
legit.pl show 1:b
legit.pl status
