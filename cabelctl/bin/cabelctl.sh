#! /bin/sh

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/deployer.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "file di configurazione [$FILE_CONFIG] non trovato"
	exit 1
fi

source "$FILE_CONFIG"


# ---------------------------------------------------------
# setup
# ---------------------------------------------------------

DIRS="$DIR_LOG"

for dir in $DIRS
do
	if ! [ -d "$dir" ]
	then
		mkdir $dir
	fi
done



# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

helpmsg()
{
	SCRIPT_NAME=`basename $0`
	echo ""
	echo "comandi:"
	echo ""
	echo "deploy <nome_applicazione> <path_war>"
	echo ""
	echo "		effettua il deploy del war passato come argomento nel tomcat dell'applicazione"
	echo ""
	echo "update <nome_applicazione> <path_war>"
	echo ""
	echo "		effettua l'undeploy dell'applicazione e il deploy del nuovo war passato come argomento"
	echo ""
	echo "list"
	echo ""
	echo "		lista delle applicazioni disponibili contenute nel file [$FILE_PROGETTI]"
	echo ""
	echo "clean"
	echo ""
	echo "		elimina file temporanei"
	echo ""
	echo "tomcat"
	echo ""
	echo "		wrapper per il controllo di tomcat"
	echo ""
}

builder_getlastbuild()
{
	# su linux funziona, su mobaxterm no perche` e` un busybox e il find non ha l'azione "printf"
	#find "$DIR_DIST" -type f -printf "%A@ %p\n" | sort -n | tail -n1 | awk '{print $2}'
	
	NEWER=""
	
	for file in `find "$DIR_DIST" -type f`
	do
		if [ -z "$NEWER" ]
		then
			NEWER="$file"
		fi
		if [ `stat -c %Y $file` -gt `stat -c %Y $NEWER` ]
		then
			NEWER="$file"
		fi
	done
	
	echo "$NEWER"
}

builder_clean()
{
	echolog "eliminazione del contenuto della directory [$DIR_DIST]"
	
	if ! [ -d "$DIR_DIST" ]
	then
		echolog "la directory [$DIR_DIST] non esiste"
		return 1
	fi
	
	rm -rf $DIR_DIST/*
	if [ $? -ne 0 ]
	then
		echolog "impossibile eliminare il contenuto della directory [$DIR_DIST]"
		return 1
	fi
	
	DIR_IVY_CACHE="$DIR_IVY/cache"
	echolog "eliminazione del contenuto della directory [$DIR_IVY_CACHE]"
	
	if ! [ -d "$DIR_IVY_CACHE" ]
	then
		echolog "la directory [$DIR_IVY_CACHE] non esiste"
		return 1
	fi
	
	rm -rf $DIR_IVY_CACHE/*
	if [ $? -ne 0 ]
	then
		echolog "impossibile eliminare il contenuto della directory [$DIR_IVY_CACHE]"
		return 1
	fi
	
	echolog "eliminazione dei vecchi file di log"
	
	for logfile in `ls "$DIR_LOG"`
	do
		if ! [ "$DIR_LOG/$logfile" = "$FILE_LOG" ]
		then
			echolog "eliminazione file [$DIR_LOG/$logfile]"
			rm -f "$DIR_LOG/$logfile"
			if [ $? -ne 0 ]
			then
				echolog "impossibile eliminare il file [$DIR_LOG/$logfile]"
				return 1
			fi
		fi
	done
}


builder_build()
{
	if [ -f "$FILE_PID" ]
	then
		PID=`cat $FILE_PID`
		if ps -p $PID > /dev/null
		then
			echolog "processo gia' in esecuzione con pid [$PID]"
			return 2
		fi
	fi
	
	echo $$ > "$FILE_PID"
	
	if [ -z "$1" ]
	then
		helpmsg
		rm "$FILE_PID"; return 1
	fi
	
	revision=$2
	
	if [ -z "$2" ]
	then
		revision="head"
	fi
	
	progetto=$1
	
	
	if ! grep "^$progetto" "$FILE_PROGETTI" > /dev/null
	then
		echolog "il progetto [$progetto] non esiste"
		rm "$FILE_PID"; return 1
	fi
	
	URL_REPO=`grep "^$progetto[\s\t]*" "$FILE_PROGETTI" | head -n1 | awk '{print $2}'`
	
	if ! [ -d "$DIR_REPO/$progetto" ]
	then	
		echolog "checkout repository [$URL_REPO] alla revision [$revision]"
		$DIR_BIN/svnwrapper.sh get "$DIR_REPO/$progetto" $URL_REPO@$revision
		if [ $? -ne 0 ]
		then
			echolog "checkout fallito: repository [$URL_REPO], revision [$revision]"
			echolog "rimuovere eventualmente la directory del progetto con [rm -rf $DIR_REPO/$progetto]"
			rm "$FILE_PID"; return 1
		fi
	else
		echolog "update progetto [$progetto] con url [$URL_REPO] alla revision [$revision]"
		cd "$DIR_REPO/$progetto"
		$DIR_BIN/svnwrapper.sh get "$DIR_REPO/$progetto" $revision
		if [ $? -ne 0 ]; then echolog "update fallito: progetto [$progetto], repository [$URL_REPO], revision [$revision]"; rm "$FILE_PID"; return 1; fi
	fi
	
	vcsrevision=`$DIR_BIN/svnwrapper.sh rev "$DIR_REPO/$progetto"`
	$DIR_BIN/antwrapper.sh "$DIR_REPO/$progetto" "dist" "$vcsrevision"
	
	if [ $? -ne 0 ]; then echolog "build fallito: progetto [$progetto], repository [$URL_REPO], revision [$revision]"; rm "$FILE_PID"; return 1; fi
	
	if ! [ -z "$3" ]
	then
		OUTPUT=`builder_getlastbuild`
		echolog "esecuzione copia di [$OUTPUT] in [$3]"
		cp "$OUTPUT" "$3"
	fi
	
	rm "$FILE_PID"
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "auto" ]
then

	if [ ! -z "$DIR_DIST_AUTO" ] && [ -d "$DIR_DIST_AUTO" ]
	then
		rm -fr "$DIR_DIST_AUTO"
	fi
	
	mkdir "$DIR_DIST_AUTO"
	
	for progetto in `cat "$FILE_PROGETTI" | awk '{print $1}'`
	do
		echo "building [$progetto]"
		builder_build "$progetto" head "$DIR_DIST_AUTO/"
	done
	exit 0
fi

if [ "$1" = "build" ]
then
	shift
	builder_build $1 $2 $3
	RET=$?
	if [ $RET -eq 0 ]
	then
		echo ""
		builder_getlastbuild
		echo ""
	fi
	exit $RET
fi

if [ "$1" = "list" ]
then
	echo ""
	echolog "progetti disponibili:"
	echo ""
	cat "$FILE_PROGETTI"
	echo ""
	exit $?
fi

if [ "$1" = "clean" ]
then
	builder_clean
	exit $?
fi

if [ "$1" = "last" ]
then
	builder_getlastbuild
	exit $?
fi

if [ "$1" = "svn" ]
then
	shift
	$DIR_BIN/svnwrapper.sh $@
	exit $?
fi

if [ "$1" = "ant" ]
then
	shift
	$DIR_BIN/antwrapper.sh $@
	exit $?
fi

helpmsg
exit 0