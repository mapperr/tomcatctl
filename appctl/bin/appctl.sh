#! /bin/sh

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/appctl.rc"

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
	echo "deploy <nome_applicazione> [revision]"
	echo ""
	echo "		effettua il deploy dell'applicazione alla revision specificata"
	echo ""
	echo "list"
	echo ""
	echo "		lista delle applicazioni disponibili contenute nel file [$FILE_APPS]"
	echo ""
	echo "clean"
	echo ""
	echo "		elimina file temporanei"
	echo ""
}

appctl_undeploy()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	applicazione="$1"
	revision=$2
	
	if [ -z "$2" ]
	then
		revision="head"
	fi
	
	context=`cat $FILE_APPS | grep ^$applicazione | awk '{print $2}'`
	istanza_tomcat=`cat $FILE_APPS | grep ^$applicazione | awk '{print $3}'`
	
	$BIN_TOMCATCTL status "$istanza_tomcat"
	if [ $? -eq 2 ]
	then
		echo "l'istanza e' down"
		return 2
	fi
	
	$BIN_TOMCATCTL deploy "$istanza_tomcat" "$pathwar" "$context" "r$revision"
	if [ $? -ne 0 ]
	then
		echo "deploy fallito"
		return 1
	fi
}

appctl_deploy()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	applicazione="$1"
	revision=$2
	
	if [ -z "$2" ]
	then
		revision="head"
	fi
	
	context=`cat $FILE_APPS | grep ^$applicazione | awk '{print $2}'`
	istanza_tomcat=`cat $FILE_APPS | grep ^$applicazione | awk '{print $3}'`
	
	$BIN_BUILDCTL dist "$applicazione"
	if [ $? -ne 0 ]
	then
		echo "build fallito"
		return 1
	fi
	
	pathwar=`$BIN_BUILDCTL last`
	
	$BIN_TOMCATCTL deploy "$istanza_tomcat" "$pathwar" "$context" "r$revision"
	if [ $? -ne 0 ]
	then
		echo "deploy fallito"
		return 1
	fi
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "deploy" ]
then
	shift
	appctl_deploy $@
	exit 0
fi

helpmsg
exit 0