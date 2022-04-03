#!/bin/bash
set +x

# homepage: https://github.com/skramm/jautocorrect

# Required filename for the assignments (without added assignment index)
FILE=Test

# Required filename extension
EXT=java

# autorized assignment indexes: array of arbitrary integer digits
INDEXES=(1 2)

# output log file
OUTFILE=log.csv

# number of tests for each assignement (must be the same for all the assignments)
NBTESTS=4

# compiler (only javac at present)
COMPILER=javac

# interpreter (only java at present)
INTERPRETER=java



# ============================================
# argument 1: index of the assignment
# Loop on all the generated output files, and
# compare then to the expected output
function compare
{
	echo "* step 3: compare to expected"
	sum1=0
	for i in $(ls exec/stdout$1*.txt)
	do
		fn2=$(basename "$i")
		# separate filename and extension
		cn1=${fn2%.*}
		cn2=${fn2#*.}
		isGood=0
		echo " -checking result using $fn2"
		if [[ $verbose = 1 ]];
		then
			echo " -generated output:"
			cat exec/$fn2
		fi
		for j in $(ls expected/$cn1*.txt)
		do
			if [[ $verbose = 1 ]];
			then
				echo " -comparing with required output:"
				cat $j
			fi
			cmp -s $j exec/$fn2 	
			retval=$?
			if [[ $retval = 0 ]]; then isGood=1; echo " -result: success"; break; fi
		done
		
#		if [[ $verbose = 1 ]];
#		then
			if [[ $isGood = 0 ]]; then echo " -result: failure"; fi
#		fi				
		
		sum1=$(($sum1+$retval))
		printf ",%d" $isGood >>$OUTFILE
	done
	echo "compare score: $sum1"
	printf ",T,%d" $sum1 >>$OUTFILE
}

# ============================================
# This function will read argument file line by line and run the program
# with the given arguments. The program output is stored for further comparison
# with expected output, and the return value is checked: if 0, then the output
# csv file will store '1' for the given test, and '0' if not.
function run_tests
{
	echo "* step 2: run_tests, $name, index: $index"
	input="input_args/args$index.txt"
	itest=0
	while IFS= read -r line
	do
	#	echo "line=$line, char1=${line:0:1}"
		IFS=' ' read -ra ADDR <<< "$line"
		nb=${ADDR[0]}
		
		if [[ ${#line} != 0 ]] && [[ "${line:0:1}" != "#" ]] # only if line is not empty
		then
			args=""
			if [ $nb != 0 ]
			then				
				for (( n=1; n<=$nb; n++ ))
				do
					args="$args${ADDR[$n]} "
				done
				printf " -runnning with args='$args': "
			else
				printf " -runnning with no arguments: "
			fi
			cd exec/
			rm *.class 2>/dev/null
			$INTERPRETER $FILE$index.$EXT $args > stdout$index$itest.txt 2>/dev/null			
			rv=$?
			cd ..
			if [[ $rv = 0 ]];
			then
				printf ",1">>$OUTFILE
				echo "ok"
			else
				printf ",0">>$OUTFILE
				echo "fail"
			fi			
		fi
	itest=$((itest+1))
	done < "$input"
#	printf ",X" >>$OUTFILE
}

# ============================================
function build_tests
{
	echo "* step 1: build_tests, $name, index: $index"
	cd exec/;

# compile attempt
	$COMPILER *.$EXT 2>/dev/null
	r2=$?
	cd ..
	rm *.class 2>/dev/null
	if [ $r2 = 0 ] # if compile is successful
	then
		echo " -compile: success"
		nbcompile=$(($nbcompile+1))
		printf ",1,X" >>$OUTFILE
		if [ $indexok = 1 ]
		then
			run_tests
			if [ $noCheck = 0 ]
			then
				printf ",">>$OUTFILE
				compare $index
			fi
		else
			echo "-Stop, unable to determine tests, invalid index"
		fi
	else
		echo " -compile: failure"
		printf ",0," >>$OUTFILE
	fi
}

# ============================================
# START
# ============================================

# 1 - GENERAL CHECKING
if [[ "$1" == "" ]]
then
	echo "usage: ./jautograde [flags] input_file.zip"
	exit 1
fi

# last arg
inputfn=${!#}

if [[ ! -e "$inputfn" ]]
then
	echo "Error: input file '$inputfn' not present!"
	exit 2
fi

# FLAGS
noCheck=0
stopOnEach=0
verbose=0
for ((i=1;i<$#;i++))
do
	echo "arg $i: ${@:$i:1}"
	if [[ ${@:$i:1} = "-s" ]]; then stopOnEach=1; fi
	if [[ ${@:$i:1} = "-n" ]]; then noCheck=1; fi
	if [[ ${@:$i:1} = "-v" ]]; then verbose=1; fi
done


# 2- cleanout previous run and unzip input file
rm src/* 2>/dev/null
rm exec/* 2>/dev/null
unzip -q "$inputfn" -d src/
nbfiles=$(ls -1| wc -l)
echo "-processing $nbfiles input files"
nbcompile=0

# 3 - CHECKING REQUIRED FILES

for f in ${INDEXES[@]}
do
	argf=input_args/args$f.txt
	if [[ ! -e $argf ]]
	then	
		echo "Error: missing arguments file '$argf', see manual"
		exit 3
	fi

	if [ $noCheck = 0 ]
	then
		for (( n=0; n<$NBTESTS; n++ ))
		do
			expected=expected/stdout$f$n.txt
			nbef=$(ls -1 expected/stdout$f$n*.txt | wc -l)
			if [[ $nbef = 0 ]]
				then	
					echo "Error: missing expected results file matching expected/stdout$f$n, see manual"
					exit 5
			fi		
		done
	fi
done


echo "# Results" >$OUTFILE
printf "# student name,student number,filename ok,extension ok,exercice index ok,compile success, run_status:">>$OUTFILE
for ((n=0;n<$NBTESTS; n++))
do
	printf ",$n">>$OUTFILE
done
printf ",compare_status:">>$OUTFILE

for ((n=0;n<$NBTESTS; n++))
do
	printf ",$n">>$OUTFILE
done

printf "\n">>$OUTFILE

# 4 - LOOP START
for a in src/*.$EXT
do
	bn=$(basename "$a")
	IFS='_' read -ra ADDR <<< "$bn"
	name=${ADDR[0]}
	num=${ADDR[1]}
	na=${ADDR[4]}
	echo "*** Processing student '$name', filename=$na"
	printf "%s,%s" "$name" $num >> $OUTFILE
# separate filename and extension
	na1=${na%.*}
	na2=${na#*.}
# get assignment name and index
	sna=$((${#na1}-1))
	an=${na1:0:sna}
	index=${na1:sna:1}
#	echo "bn=$bn na=$na na1=$na1 na2=$na2 sna=$sna an=$an, index=$index"

# check that filename and extension are correct (if not good, go on anyway)
	if [ "$an" = "$FILE" ]
	then
		printf ",1" >> $OUTFILE
	else
		printf ",0" >> $OUTFILE
	fi

	if [ "$na2" = "$EXT" ]
	then
		printf ",1" >> $OUTFILE
	else
		printf ",0" >> $OUTFILE
	fi

# check that index is correct (if not good, try to compile anyway)
	indexok=0
	for i in "${INDEXES[@]}"
	do
		if [ $i = $index ];	then indexok=1; fi
	done

	if [ $indexok = 1 ]
	then
		printf ",1" >> $OUTFILE	
	else
		printf ",0" >> $OUTFILE
		echo "-Failure: incorrect assignment index!"
	fi
	rm exec/* 2>/dev/null
	cp "src/$bn" exec/$na1.$EXT
	build_tests
	printf "\n" >> $OUTFILE
	
	if [ $stopOnEach = 1 ]
	then
		echo "Hit enter to switch to next file"
		read
	fi
done

echo "-end, nb of successful builds: $nbcompile/$nbfiles"

