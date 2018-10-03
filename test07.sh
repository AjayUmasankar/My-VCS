# different file status

./legit.pl init
touch a
legit.pl add a
legit.pl status
legit.pl commit -m 'commit-0'
#same as repo
legit.pl status

#changes unstaged
echo line1 > a
legit.pl status

#changes staged 
legit.pl add a
legit.pl status

#different changes staged for commit
legit.pl commit -m 'commit-1'
echo line2 >>a
legit.pl status
legit.pl add a
legit.pl status
echo line3 >>a
legit.pl status
