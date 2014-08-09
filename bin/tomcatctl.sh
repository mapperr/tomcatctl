#! /bin/sh

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/tomcatctl.rc"

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
	echo "- add [template] [codice_istanza] [tag_istanza]"
	echo ""
	echo "		crea un'istanza di tomcat dal template [template] (o da quello di default se omesso)"
	echo "		e gli assegna un codice istanza non ancora utilizzato oppure [codice_istanza] se specificato"
	echo "		inoltre gli assegna un tag se specificato"
	echo ""
	echo "- rm <codice_istanza>"
	echo ""
	echo "		elimina l'istanza a cui e' stato assegnato il codice <codice_istanza>"
	echo ""
	echo "- cp <codice_istanza_originale> [codice_istanza_clonata] [tag_istanza_clonata]"
	echo ""
	echo "		clona l'istanza specificata"
	echo ""
	echo "- ls"
	echo ""
	echo "		lista dei templates e delle istanze"
	echo ""
	echo "- clean"
	echo ""
	echo "		elimina i file temporanei"
	echo ""
	echo "- start | stop | restart <codice_istanza>"
	echo ""
	echo "		controllo del tomcat"
	echo ""
	echo "- status <codice_istanza>"
	echo ""
	echo "		mostra informazioni sullo stato del tomcat"
	echo ""
	echo "- deploy <codice_istanza> <path_war> <context_path> [version]"
	echo ""
	echo "		effettua il deploy del war passato come argomento con il context path specificato"
	echo "		se il context path e' gia' utilizzato, allora viene effettuato prima l'undeploy dell'applicazione che ha quel context path"
	echo ""
	echo "- undeploy <codice_istanza> <context_path> <version>"
	echo ""
	echo "		effettua l'undeploy dell'applicazione che ha il context path passato come argomento"
	echo ""
	echo "- apps <codice_istanza>"
	echo ""
	echo "		lista delle applicazioni deployate"
	echo ""
	echo "- log <codice_istanza>"
	echo ""
	echo "		mostra il catalina.out dell'istanza <codice_istanza>"
	echo ""
}


tomcatctl_codice_istanza_is_valido()
{
	if [ -z "$1" ]
	then
		return 1
	fi
	
	if [ `expr length $1` -eq 2 ] && [ "$1" -eq "$1" ] 2>/dev/null
	then
		return 0
	fi
	
	return 1
}

tomcatctl_get_template()
{
	if [ -z "$1" ]
	then
		echo "specificare un'istanza" 1>&2
		return 1
	fi
	istanza="$1"
	
	file_template="$DIR_ISTANZE/$istanza/$FILENAME_TEMPLATE"
	
	if [ -f "$file_template" ]
	then
		cat "$file_template"
		return 0
	fi
	
	return 1
}

tomcatctl_checkup_istanza()
{
	if [ -z "$1" ]
	then
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		return 1
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:90$istanza/$TOMCAT_MANAGER_CONTEXT/text/serverinfo"
	$HTTP_BIN "$URL" > /dev/null
	RET=$?
	
	if [ $RET -ne 0 ]
	then
		return 1
	fi
}

tomcatctl_list()
{
	echo "# templates disponibili:"
	echo "#"
	for directory in `ls $DIR_TEMPLATES | sort`
	do
		if [ "$directory" = "$DEFAULT_TEMPLATE" ]
		then
			echo "# - $directory (default)"
		else
			echo "# - $directory"
		fi
	done
	
	echo "#"
	echo "# directory istanze: [$DIR_ISTANZE]"
	echo "# istanza  [stato]  (template)  {tag}"
	echo "#"
	for directory in `ls $DIR_ISTANZE | sort`
	do
		if tomcatctl_codice_istanza_is_valido "$directory"
		then
			template=`tomcatctl_get_template $directory`
			if [ $? -ne 0 ]
			then
				template="nessuno: settato il template di default [$DEFAULT_TEMPLATE]"
				echo "$DEFAULT_TEMPLATE" > "$DIR_ISTANZE/$directory/$FILENAME_TEMPLATE"
			fi
			
			tomcatctl_checkup_istanza "$directory"
			RET=$?
			stato=" up "
			if [ $RET -ne 0 ]
			then
				stato="down"
			fi
			
			tag=""
			if [ -r "$DIR_ISTANZE/$directory/$FILENAME_TAG" ]
			then
				tag=`cat $DIR_ISTANZE/$directory/$FILENAME_TAG`
			fi
			
			echo "  $directory	[$stato]  ($template)  {$tag}"
		fi
	done
}

tomcatctl_start()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! tomcatctl_codice_istanza_is_valido "$istanza"
	then
		echolog "il codice istanza deve essere composto esattamente da due cifre"
		return 3
	fi
	
	template=`cat "$DIR_ISTANZA/$FILENAME_TEMPLATE"`
	
	export CATALINA_HOME="$DIR_TEMPLATES/$template"
	export CATALINA_BASE="$DIR_ISTANZA"
	
	if [ -z "$CATALINA_USER" ] || [ "$CATALINA_USER" = "`whoami`" ]
	then
		$CATALINA_HOME/bin/startup.sh
	else
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "$CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "$CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
		fi
	fi
}

tomcatctl_stop()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! tomcatctl_codice_istanza_is_valido "$istanza"
	then
		echolog "il codice istanza deve essere composto esattamente da due cifre"
		return 3
	fi
	
	template=`cat "$DIR_ISTANZA/$FILENAME_TEMPLATE"`
	
	export CATALINA_HOME="$DIR_TEMPLATES/$template"
	export CATALINA_BASE="$DIR_ISTANZA"
	
	if [ -z "$CATALINA_USER" ] || [ "$CATALINA_USER" = "`whoami`" ]
	then
		$CATALINA_HOME/bin/shutdown.sh
	else
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "$CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "$CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER"
		fi
	fi
}

tomcatctl_log()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if hash less > /dev/null
	then
		pager="less"
	elif hash more > /dev/null
	then
		pager="more"
	fi
	
	$pager "$DIR_ISTANZA/logs/catalina.out"
}

tomcatctl_listapps()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:90$istanza/$TOMCAT_MANAGER_CONTEXT/text/list"
	$HTTP_BIN "$URL" | grep -v "^OK" | sed 's/:/  /g' | sed 's/ [A-Za-z0-9]*##//g'
}


tomcatctl_undeploy()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	if [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	context="$2"
	versione="$3"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if [ "`echo "$context" | sed 's/\///g'`" = "$TOMCAT_MANAGER_CONTEXT" ]
	then
		echo "impossibile effettuare l'undeploy del tomcat manager"
		return 4
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:90$istanza/$TOMCAT_MANAGER_CONTEXT/text/undeploy?path=$context&version=$versione"
	$HTTP_BIN "$URL"
}


tomcatctl_deploy()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	path_war="$2"
	context="$3"
	version="$4"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! [ -f "$path_war" ]
	then
		echolog "file [$path_war] inesistente"
		return 1
	fi
	
	if [ "`echo "$context" | sed 's/\///g'`" = "$TOMCAT_MANAGER_CONTEXT" ]
	then
		echo "impossibile effettuare il deploy di un'applicazione con il context path del tomcat manager"
		return 4
	fi
	
	path_war=`readlink -f "$path_war"`
	if [ "$OS" = "cygwin" ]
	then
		path_war=`cygpath -m "$path_war"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:90$istanza/$TOMCAT_MANAGER_CONTEXT/text/deploy?war=file:/$path_war&update=true"
	
	if ! [ -z "$context" ]
	then
		URL="$URL&path=$context"
	fi
	
	if ! [ -z "$version" ]
	then
		URL="$URL&version=$version"
	fi
	
	$HTTP_BIN "$URL"
}


tomcatctl_status()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	echo "istanza [$istanza] "
	echo "template: `cat $DIR_ISTANZE/$istanza/$FILENAME_TEMPLATE`"
	
	tomcatctl_checkup_istanza "$istanza"
	RUNNING=$?
	
	if [ $RUNNING -ne 0 ]
	then
		echo "server down"
		return 1
	fi
	
	echo ""
	echo "apps:"
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:90$istanza/$TOMCAT_MANAGER_CONTEXT/text/list"
	$HTTP_BIN "$URL" | grep -v "^OK" | sed 's/:/ /g' | awk '{print $1}'
}



tomcatctl_create()
{
	template="$1"
	
	if [ -z "$template" ]
	then
		template="$DEFAULT_TEMPLATE"
	fi
	
	DIR_TEMPLATE="$DIR_TEMPLATES/$template"
	if ! [ -d "$DIR_TEMPLATE" ]
	then
		echolog "il template [$template] non esiste"
		return 2
	fi
	
	istanza="$2"
	tag="$3"
	
	if [ -z "$istanza" ]
	then
		istanza="00"
		
		while [ -d "$DIR_ISTANZE/$istanza" ]
		do
			istanza=`expr $istanza + 1`
			if [ $istanza -lt 10 ]
			then
				istanza="0$istanza"
			fi
		done
	else
		if ! tomcatctl_codice_istanza_is_valido "$istanza"
		then
			echo "il codice istanza non e' un codice valido"
			echo "il codice deve essere composto esattamente da due cifre"
			return 3
		fi
		if [ -d "$DIR_ISTANZE/$istanza" ]
		then
			echolog "l'istanza [$istanza] e' gia' esistente, sceglierne un'altra"
			return 4
		fi
	fi
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	
	mkdir -p "$DIR_ISTANZA"
	if [ $? -ne 0 ]
	then
		echolog "impossibile creare la directory [$DIR_ISTANZA]"
		return 1
	fi
	
	mkdir -p "$DIR_ISTANZA/bin"
	#cp $DIR_TEMPLATE/bin/setenv.* "$DIR_ISTANZA/bin/"
	cp -r "$DIR_TEMPLATE/conf" "$DIR_ISTANZA/"
	mkdir -p "$DIR_ISTANZA/lib"
	mkdir -p "$DIR_ISTANZA/logs"
	mkdir -p "$DIR_ISTANZA/webapps"
	#cp -r "$DIR_TEMPLATE/webapps" "$DIR_ISTANZA/"
	mkdir -p "$DIR_ISTANZA/work"
	mkdir -p "$DIR_ISTANZA/temp"
	
	echo "$template" > "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	
	if ! [ -z "$tag" ]
	then
		echo "$tag" > "$DIR_ISTANZA/$FILENAME_TAG"
	fi
	
	echolog "creata istanza [$istanza] con template [$template] in [$DIR_ISTANZA]"
}

tomcatctl_delete()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	
	if [ ! -d "$DIR_ISTANZA" ]
	then
		echolog "impossibile eliminare l'istanza [$istanza]: il path [$DIR_ISTANZA] non esiste"
		return 1
	fi
	
	tomcatctl_checkup_istanza "$istanza"
	RUNNING=$?
	if [ $RUNNING -eq 0 ]
	then
		echo "l'istanza e' in running, se si sceglie di eliminarla verra' prima stoppata"
	fi
	
	echo "eliminare [$DIR_ISTANZA]? (y/n)"
	read c
	if [ "$c" = "y" ]
	then
		if [ $RUNNING -eq 0 ]
		then
			tomcatctl_stop "$istanza" > /dev/null
			if [ $? -ne 0 ]
			then
				echolog "impossibile elminare l'istanza [$istanza]: impossibile effettuare lo shutdown"
				return 1
			fi
		fi
		
		rm -rf "$DIR_ISTANZA"
		if [ $? -ne 0 ]
		then
			echolog "impossibile elminare l'istanza [$istanza]"
			return 1
		else
			echolog "istanza [$istanza] eliminata"
		fi
	else
		echolog "annullata eliminazione istanza [$istanza]"
		return 1
	fi
}

tomcatctl_clona_istanza()
{
	istanza_originale="$1"
	
	if [ -z "$istanza_originale" ]
	then
		helpmsg
		return 1
	fi
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza_originale"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza_originale] inesistente"
		return 1
	fi
	
	istanza="$2"
	tag="$3"
	
	if [ -z "$istanza" ]
	then
		istanza="00"
		
		while [ -d "$DIR_ISTANZE/$istanza" ]
		do
			istanza=`expr $istanza + 1`
			if [ $istanza -lt 10 ]
			then
				istanza="0$istanza"
			fi
		done
	else
		if ! tomcatctl_codice_istanza_is_valido "$istanza"
		then
			echo "il codice istanza non e' un codice valido"
			echo "il codice deve essere composto esattamente da due cifre"
			return 3
		fi
		if [ -d "$DIR_ISTANZE/$istanza" ]
		then
			echolog "l'istanza [$istanza] e' gia' esistente, sceglierne un'altra"
			return 4
		fi
	fi
	
	DIR_ISTANZA_ORIGINALE="$DIR_ISTANZE/$istanza_originale"
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	
	mkdir -p "$DIR_ISTANZA"
	if [ $? -ne 0 ]
	then
		echolog "impossibile creare la directory [$DIR_ISTANZA]"
		return 1
	fi
	
	cp -r "$DIR_ISTANZA_ORIGINALE/bin" "$DIR_ISTANZA/"
	cp -r "$DIR_ISTANZA_ORIGINALE/conf" "$DIR_ISTANZA/"
	cp -r "$DIR_ISTANZA_ORIGINALE/lib" "$DIR_ISTANZA/lib"
	mkdir -p "$DIR_ISTANZA/logs"
	cp -r "$DIR_ISTANZA_ORIGINALE/webapps" "$DIR_ISTANZA/webapps"
	mkdir -p "$DIR_ISTANZA/work"
	mkdir -p "$DIR_ISTANZA/temp"
	
	cp -r "$DIR_ISTANZA_ORIGINALE/$FILENAME_TEMPLATE" "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	
	if ! [ -z "$tag" ]
	then
		echo "$tag" > "$DIR_ISTANZA/$FILENAME_TAG"
	fi
	
	echolog "clonata istanza [$istanza_originale] in [$DIR_ISTANZA]"
}

tomcatctl_clean()
{
	# clean di tomcatctl
	if [ -z "$1" ]
	then
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
	# clean del tomcat
	else
		istanza="$1"
		DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	
		if [ ! -d "$DIR_ISTANZA" ]
		then
			echolog "impossibile ripulire l'istanza [$istanza]: il path [$DIR_ISTANZA] non esiste"
			return 1
		fi
		
		# boh
	fi
}

# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "add" ]
then
	shift
	tomcatctl_create $@
	exit $?
fi

if [ "$1" = "rm" ]
then
	shift
	tomcatctl_delete $@
	exit $?
fi

if [ "$1" = "ls" ]
then
	tomcatctl_list
	exit $?
fi

if [ "$1" = "start" ]
then
	shift
	tomcatctl_start $@
	exit $?
fi

if [ "$1" = "stop" ]
then
	shift
	tomcatctl_stop $@
	exit $?
fi

if [ "$1" = "restart" ]
then
	shift
	tomcatctl_stop $@
	RET=$?
	if [ $RET -ne 0 ]
	then
		echo "impossibile stoppare l'istanza [$1]"
		exit $RET
	fi
	sleep 1
	tomcatctl_start $@
	exit $?
fi

if [ "$1" = "status" ]
then
	shift
	tomcatctl_status $@
	RET=$?
	if [ $RET -eq 2 ]
	then
		echo "down"
	fi
	exit $RET
fi

if [ "$1" = "log" ]
then
	shift
	tomcatctl_log $@
	exit $?
fi

if [ "$1" = "deploy" ]
then
	shift
	tomcatctl_deploy $@
	exit $?
fi

if [ "$1" = "undeploy" ]
then
	shift
	tomcatctl_undeploy $@
	exit $?
fi

if [ "$1" = "apps" ]
then
	shift
	tomcatctl_listapps $@
	exit $?
fi

if [ "$1" = "clean" ]
then
	shift
	tomcatctl_clean $@
	exit $?
fi

if [ "$1" = "cp" ]
then
	shift
	tomcatctl_clona_istanza $@
	exit $?
fi


helpmsg
exit 0