#! /bin/bash

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/buildctl.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "file di configurazione [$FILE_CONFIG] non trovato"
	exit 1
fi

source "$FILE_CONFIG"

SCRIPT_NAME=`basename $0`

# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

helpmsg()
{
	echo "utilizzo:"
	echo "$SCRIPT_NAME <path_root_progetto> [nome_target] [revision]"
}

# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ -z "$1" ]
then
	helpmsg
	exit 1
fi

DIR_ROOT_PROGETTO=$1
TARGET=$2
REVISION=$3

if ! [ -z "$REVISION" ]
then
	REVISION_OPT="-Dvcs.revision=$REVISION"
fi
	
FILE_IVYSETTINGS="$DIR_CONF/ivysettings.xml"
FILE_BUILDFILE="$DIR_CONF/build.xml"
ANT_DIR_IVY="$DIR_IVY"
ANT_DIR_DIST="$DIR_DIST"

if [ "$OS" = "cygwin" ]
then
	FILE_BUILDFILE=`cygpath -m $FILE_BUILDFILE`
	FILE_IVYSETTINGS=`cygpath -m $FILE_IVYSETTINGS`
	DIR_ROOT_PROGETTO=`cygpath -m $DIR_ROOT_PROGETTO`
	ANT_DIR_IVY=`cygpath -m $DIR_IVY`
	ANT_DIR_DIST=`cygpath -m $DIR_DIST`
fi

echolog "esecuzione antwrapper per [$DIR_ROOT_PROGETTO] con target [$TARGET]"
$DIR_ANT/bin/ant -lib "$ANT_DIR_IVY" -lib "$ANT_DIR_IVY/lib" -Dbuilder.ivy.settings="$FILE_IVYSETTINGS" -Divy.default.ivy.user.dir="$ANT_DIR_IVY" \
	-Dbuilder.dir.dist="$ANT_DIR_DIST" -Dbasedir="$DIR_ROOT_PROGETTO" $REVISION_OPT -f "$FILE_BUILDFILE" $TARGET
exit $?