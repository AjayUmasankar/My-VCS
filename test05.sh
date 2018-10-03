#testing filename criteria for commit and add 

./legit.pl init

touch a-dr_i.an
legit.pl add a-dr_i.an

#filename not starting with alphanumeric 

touch _bsa
legit.pl add _bsa

touch -bsa
legit.pl add -bsa

touch .bsa
legit.pl add .bsa

touch ?a
legit.pl add ?a

touch @a
legit.pl add @a

touch \a
legit.pl add \a

#filename that shouldnt work
touch sala,}{]}
legit.pl add sala,}{]}

touch adri&n
legit.pl add adri&n

touch 9=;
legit.pl add 9=;

touch 9|\/?><":{})_+"
legit.pl add 9|\/?><":{})_+"

#touch adri@n
#legit.pl add adri@n 			 why does this work in 2041 legit?


#filename that should be allowed (alphanumeric + '.' or '-' or '_' are allowed)

touch A
legit.pl add A

touch a
legit.pl add a

touch a-dr_i.an
legit.pl add a-dr_i.an

touch APPLe_.-__._
legit.pl add APPLe_.-__._


# commit message starting with special char
touch c
legit.pl add c

legit.pl commit -m '-commit-0'

touch c
legit.pl add c
legit.pl commit -m '?commit-0'

touch d
legit.pl add d
legit.pl commit -m '/commit-0'

touch e
legit.pl add e
legit.pl commit -m '_-commit-0'

touch f
legit.pl add f
legit.pl commit -m '.-commit-0'

touch g
legit.pl add g
legit.pl commit -m 'a-commit-0'
# log to check if commits are accurate
legit.pl log