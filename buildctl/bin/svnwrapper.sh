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

# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

helpmsg()
{
	SCRIPT_NAME=`basename $0`
	echo "utilizzo:"
	echo "$SCRIPT_NAME get <path_root_progetto> <url_http(s)> | <revision>"
	echo "$SCRIPT_NAME co <path_root_progetto> <url_http(s)>"
	echo "$SCRIPT_NAME up <path_root_progetto> <revision>"
	echo "$SCRIPT_NAME rev <path_root_progetto>"
}


svn_co()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	DIR_ROOT_PROGETTO=$1

	URL="$2"

	if ! [ -d "$DIR_ROOT_PROGETTO" ]
	then
		mkdir "$DIR_ROOT_PROGETTO"
		if [ $? -ne 0 ]; then echolog "impossibile creare la directory [$DIR_ROOT_PROGETTO]"; return 1; fi
	fi
	
	cd "$DIR_ROOT_PROGETTO"

	echolog "checkout di [$URL]"
	$SVN_BIN checkout $URL ./ --non-interactive --trust-server-cert --username "$SVN_USER" --password "$SVN_PASS"	
	RETURN=$?
	
	cd "$SCRIPT_DIR"
	return $RETURN
}

svn_up()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi

	DIR_ROOT_PROGETTO=$1

	REVISION="$2"

	if [ -d "$DIR_ROOT_PROGETTO" ]
	then
		cd "$DIR_ROOT_PROGETTO"
	else
		echo "$SCRIPT_NAME: la directory [$DIR_ROOT_PROGETTO] non esiste"
		return 1
	fi


	echolog "update alla revision [$REVISION]"
	$SVN_BIN update -r $REVISION --non-interactive --trust-server-cert --username "$SVN_USER" --password "$SVN_PASS"
	RETURN=$?
	
	cd "$SCRIPT_DIR"
	return $RETURN
}

svn_get()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	DIR_ROOT_PROGETTO=$1

	if echo "$2" | grep "^http[s]://" > /dev/null
	then
		URL="$2"
	else
		REVISION="$2"
	fi

	if [ "$URL" ]
	then
		svn_co "$DIR_ROOT_PROGETTO" "$URL"
		RETURN=$?
	else
		svn_up "$DIR_ROOT_PROGETTO" "$REVISION"
		RETURN=$?
	fi

	cd "$SCRIPT_DIR"
	return $RETURN
}

svn_get_revision()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	DIR_ROOT_PROGETTO=$1
	
	if [ -d "$DIR_ROOT_PROGETTO" ]
	then
		cd "$DIR_ROOT_PROGETTO"
	else
		echo "$SCRIPT_NAME: la directory [$DIR_ROOT_PROGETTO] non esiste"
		return 1
	fi
	
	REVISION=`$SVN_BIN info | grep Revision: | awk '{print $2}'`
	
	if [ -z "$REVISION" ]
	then
		# il client sara` in italiano...
		REVISION=`$SVN_BIN info | grep Revisione: | awk '{print $2}'`
	fi
	
	cd "$SCRIPT_DIR"
	echo "$REVISION"
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ -z "$1" ]
then
	helpmsg
	exit 1
fi

if [ "$1" = "get" ]
then
	shift
	svn_get "$1" "$2"
	exit $?
fi

if [ "$1" = "up" ]
then
	shift
	svn_up "$1" "$2"
	exit $?
fi

if [ "$1" = "co" ]
then
	shift
	svn_co "$1" "$2"
	exit $?
fi

if [ "$1" = "rev" ]
then
	shift
	svn_get_revision "$1"
	exit $?
fi
