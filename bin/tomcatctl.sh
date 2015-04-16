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

DIRS="$DIR_LOG $DIR_ISTANZE"

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
	echo "- install <path_catalina_home> <nome_template>"
	echo "	installa un nuovo template prendendo come base <path_catalina_home>"
	echo ""
	echo "- uninstall <nome_template>"
	echo "	elimina il template <nome_template>"
	echo ""
	echo "- add [template] [codice_istanza] [tag_istanza]"
	echo "	crea un'istanza di tomcat dal template [template] (o da quello di default se omesso) e gli assegna un codice istanza non ancora utilizzato oppure [codice_istanza] se specificato inoltre gli assegna un tag se specificato"
	echo ""
	echo "- rm <codice_istanza>"
	echo "	elimina l'istanza a cui e' stato assegnato il codice <codice_istanza>"
	echo ""
	echo "- cp <codice_istanza_originale> [codice_istanza_clonata] [tag_istanza_clonata]"
	echo "	clona l'istanza specificata"
	echo ""
	echo "- attach <path_catalina_home> [codice_istanza] [tag_istanza]"
	echo "	aggancia l'istanza di tomcat <path_catalina_home> e gli assegna un codice istanza non ancora utilizzato oppure [codice_istanza] se specificato inoltre gli assegna un tag se specificato"
	echo ""
	echo "- detach <codice_istanza>"
	echo "	sgancia l'istanza virtuale a cui e' stato assegnato il codice <codice_istanza>"
	echo ""
	echo "- ls"
	echo "	lista dei templates e delle istanze"
	echo ""
	echo "- apps <codice_istanza>"
	echo "	lista delle applicazioni deployate con relativo status, context path e versione"
	echo ""
	echo "- appstart | appstop | apprestart | appreload <codice_istanza> <context_applicazione> <versione_applicazione>"
	echo "	controllo dell'applicazione"
	echo ""
	echo "- start | stop | restart <codice_istanza>"
	echo "	controllo del tomcat"
	echo ""
	echo "- info <codice_istanza>"
	echo "	mostra informazioni sullo stato dell'istanza"
	echo ""
	echo "- deploy <codice_istanza> <path_war> [context_path] [version]"
	echo "	effettua il deploy del war passato come argomento con il context path specificato se il context path e' gia' utilizzato, allora viene effettuato prima l'undeploy dell'applicazione che ha quel context path. Note: se c'e' l'autoDeploy attivo sul tomcat, allora il context path e' obbligatorio"
	echo ""
	echo "- undeploy <codice_istanza> <context_path> <version>"
	echo "	effettua l'undeploy dell'applicazione che ha il context path passato come argomento"
	echo ""
	echo "- log <codice_istanza> [tail | cat]"
	echo "	mostra il catalina.out dell'istanza <codice_istanza>"
	echo ""
	echo "- clean [istanza [logs]]"
	echo "	elimina i file temporanei di tomcatctl, oppure di un'istanza di tomcat. Con [logs] vengono eliminati anche i files di log"
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

tomcatctl_get_attached_httpport()
{
	if [ -z "$1" ]
	then
		return 1
	fi
	
	if tomcatctl_codice_istanza_is_valido "$1"
	then
		path_catalina_home="$DIR_ISTANZE/$1"
	else
		path_catalina_home="$1"
	fi
	
	cat "$path_catalina_home/conf/server.xml" | grep -i "<Connector" | grep -i "protocol=[\"\']HTTP" | grep -o "port=[\"\'][0-9]*" | grep -o "[0-9]*$"  | head -n1
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

tomcatctl_status()
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
	echo "# istanza  stato  tag  template"
	echo "#"
	SEPARATOR="######"
	STATUSROWS=""
	for directory in `ls $DIR_ISTANZE | sort`
	do
		if tomcatctl_codice_istanza_is_valido "$directory"
		then
			if [ -L "$DIR_ISTANZE/$directory" ]
			then
				template="-->`readlink $DIR_ISTANZE/$directory`:`tomcatctl_get_attached_httpport $directory`"
			else
				template=`tomcatctl_get_template $directory`
				if [ $? -ne 0 ]
				then
					template="nessuno: settato il template di default [$DEFAULT_TEMPLATE]"
					echo "$DEFAULT_TEMPLATE" > "$DIR_ISTANZE/$directory/$FILENAME_TEMPLATE"
				fi
			fi
			
			tomcatctl_status "$directory"
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
			
			STATUSROWS="$STATUSROWS$SEPARATOR$directory $stato $tag $template"
		fi
	done
	echo $STATUSROWS | sed "s/$SEPARATOR/\n/g" | column -t
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
	
	export DIR_TEMPLATE="$DIR_TEMPLATES/$template"
	export CATALINA_HOME="$DIR_TEMPLATE"
	export CATALINA_BASE="$DIR_ISTANZA"
	
	# controllo se l'istanza e` attached
	if [ -L "$DIR_ISTANZA" ]
	then
		export CATALINA_HOME="`readlink $DIR_ISTANZE/$istanza`"
		tomcatctl_attached_start
		RET=$?
		return $RET
	else
		if ! [ -z "$CATALINA_USER" ]
		then
			if ! grep "^$CATALINA_USER" "/etc/passwd" > /dev/null
			then
				echolog "l'utente [$CATALINA_USER] non esiste, impossibile avviare il tomcat"
				return 1
			fi
		fi
	fi
	
	if [ -z "$CATALINA_USER" ] || [ "$CATALINA_USER" = "`whoami`" ]
	then
		$CATALINA_HOME/bin/startup.sh
	else
		echolog "tentativo di avvio con comando su"
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" su -s /bin/sh -c "$CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			echolog "tentativo di avvio con comando sudo -u"
			sudo -u "$CATALINA_USER" CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" bash "$CATALINA_HOME/bin/startup.sh" 2> /dev/null
			RET=$?
			if [ $RET -ne 0 ]
			then
				echolog "tentativo di avvio con comando sudo su"
				sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" su -s /bin/sh -c "$CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
				RET=$?
				if [ $RET -ne 0 ]
				then
					echolog "impossibile avviare il tomcat"
					return 1
				fi
			fi
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
	
	export DIR_TEMPLATE="$DIR_TEMPLATES/$template"
	export CATALINA_HOME="$DIR_TEMPLATES/$template"
	export CATALINA_BASE="$DIR_ISTANZA"
	
	# controllo se l'istanza e` attached
	if [ -L "$DIR_ISTANZA" ]
	then
		export CATALINA_HOME="`readlink $DIR_ISTANZE/$istanza`"
		tomcatctl_attached_stop
		RET=$?
		return $RET
	else
		if ! [ -z "$CATALINA_USER" ]
		then
			if ! grep "^$CATALINA_USER" "/etc/passwd" > /dev/null
			then
				echolog "l'utente [$CATALINA_USER] non esiste, impossibile arrestare il tomcat"
				return 1
			fi
		fi
	fi
	
	if [ -z "$CATALINA_USER" ] || [ "$CATALINA_USER" = "`whoami`" ]
	then
		$CATALINA_HOME/bin/shutdown.sh
	else
		echolog "tentativo di arresto con comando su"
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" su -s /bin/sh -c "$CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			echolog "tentativo di arresto con comando sudo -u"
			sudo -u "$CATALINA_USER" CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" bash "$CATALINA_HOME/bin/shutdown.sh" 2> /dev/null
			RET=$?
			if [ $RET -ne 0 ]
			then
				echolog "tentativo di arresto con comando sudo su"
				sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" DIR_TEMPLATE="$DIR_TEMPLATES/$template" su -s /bin/sh -c "$CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
				RET=$?
				if [ $RET -ne 0 ]
				then
					echolog "impossibile arrestare il tomcat"
					return 1
				fi
			fi
		fi
	fi
}

tomcatctl_attached_start()
{
	if [ -r "$CATALINA_HOME/bin/setenv.sh" ]
	then
		source "$CATALINA_HOME/bin/setenv.sh"
	fi
	
	if ! [ -z "$CATALINA_INIT" ]
	then
		echolog "tentativo di avvio con sudo tramite script esterno: trovato CATALINA_INIT [$CATALINA_INIT]"
		sudo $CATALINA_INIT start
		return $?
	else
		if ! [ -z "$CATALINA_PID" ]
		then
			if ! [ -f "$CATALINA_PID" ]
			then
				sudo touch "$CATALINA_PID"
			fi
			GROUPFRAGMENT=""
			if ! [ -z "$CATALINA_GROUP" ]
			then
				GROUPFRAGMENT=":$CATALINA_GROUP"
			fi
			sudo chown $CATALINA_USER$GROUPFRAGMENT "$CATALINA_PID"
		fi
		
		echolog "tentativo di avvio con comando su"
		su -s /bin/sh -c "$CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			if hash sudo
			then
				echolog "tentativo di avvio con comando sudo -u"
				sudo -u "$CATALINA_USER" bash "$CATALINA_HOME/bin/startup.sh" 2> /dev/null
				RET=$?
			fi
		fi
		
		return $RET
	fi
}

tomcatctl_attached_stop()
{
	if [ -r "$CATALINA_HOME/bin/setenv.sh" ]
	then
		source "$CATALINA_HOME/bin/setenv.sh"
	fi
	
	if ! [ "$CATALINA_INIT" = "" ]
	then
		echolog "tentativo di arresto con sudo tramite script esterno: trovato CATALINA_INIT [$CATALINA_INIT]"
		sudo $CATALINA_INIT stop
		return $?
	else
		if ! [ -z "$CATALINA_PID" ]
		then
			if ! [ -f "$CATALINA_PID" ]
			then
				sudo touch "$CATALINA_PID"
			fi
			sudo chown $CATALINA_USER:$CATALINA_GROUP "$CATALINA_PID"
		fi
		
		echolog "tentativo di arresto con comando su"
		su -s /bin/sh -c "$CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			if hash sudo
			then
				echolog "tentativo di arresto con comando sudo -u"
				sudo -u "$CATALINA_USER" bash "$CATALINA_HOME/bin/shutdown.sh" 2> /dev/null
				RET=$?
			fi
		fi
		
		return $RET
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
	
	output_handler="$2"
	
	if hash less > /dev/null
	then
		pager="less"
	elif hash more > /dev/null
	then
		pager="more"
	fi
	
	if [ -z "$output_handler" ]
	then
		$pager "$DIR_ISTANZA/logs/catalina.out"
		return $?
	fi
	
	if [ "$output_handler" = "tail" ]
	then
		tail -fn40 "$DIR_ISTANZA/logs/catalina.out"
		return $?
	fi
	
	if [ "$output_handler" = "cat" ]
	then
		cat "$DIR_ISTANZA/logs/catalina.out"
		return $?
	fi
}

tomcatctl_info_apps()
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
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/list"
	APPS=`$HTTP_BIN "$URL" | grep -v "^OK"  | grep -v ^/$TOMCAT_MANAGER_CONTEXT | sed 's/:/ /g'`
	
	while IFS= read -r line
	do
		context=`echo "$line" | awk '{print $1}'`
		status=`echo "$line" | awk '{print $2}'`
		sessions=`echo "$line" | awk '{print $3}'`
		version=`echo "$line" | awk '{print $4}'`
		version=`if echo "$version" | grep "##" > /dev/null; then echo "$version" | sed 's/.*##//g'; else echo "##"; fi`
		echo "$context $version $status $sessions"
	done <<< "$APPS"
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
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	if [ "`echo "$context" | sed 's/\///g'`" = "$TOMCAT_MANAGER_CONTEXT" ]
	then
		echo "impossibile effettuare l'undeploy del tomcat manager"
		return 4
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/undeploy?path=$context&version=$versione"
	$HTTP_BIN "$URL"
}

# se c'e` l'autoDeploy attivo sul tomcat, allora il context path e` obbligatorio
# http://tomcat.apache.org/tomcat-7.0-doc/manager-howto.html#Deploy_A_New_Application_from_a_Local_Path
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
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	if ! [ -f "$path_war" ]
	then
		echolog "file [$path_war] inesistente"
		return 1
	fi
	
	if [ "`echo "$context" | sed 's/\///g'`" = "$TOMCAT_MANAGER_CONTEXT" ]
	then
		echolog "impossibile effettuare il deploy di un'applicazione con il context path del tomcat manager"
		return 4
	fi
	
	path_war=`readlink -f "$path_war"`
	if [ "$OS" = "cygwin" ]
	then
		path_war=`cygpath -m "$path_war"`
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	escaped_path_war=`echo "$path_war" | sed 's@#@%23@g'`
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/deploy?war=file:/$escaped_path_war"
	
	if ! [ -z "$context" ]
	then
		URL="$URL&update=true&path=$context"
	fi
	
	if ! [ -z "$version" ]
	then
		URL="$URL&version=$version"
	fi
	
	echolog "deploy di [$path_war] con context path [$context] alla versione [$version]"
	$HTTP_BIN "$URL"
}

tomcatctl_info_memory()
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
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/status?XML=true"
	
	TCSTAT=`$HTTP_BIN "$URL"`
	
	MFREE=`echo "$TCSTAT" | grep -o "free='[0-9]*'" | grep -o "[0-9]\{1,\}"`
	MTOT=`echo "$TCSTAT" | grep -o "total='[0-9]*'" | grep -o "[0-9]\{1,\}"`
	MMAX=`echo "$TCSTAT" | grep -o "max='[0-9]*'" | grep -o "[0-9]\{1,\}"`

	MFREE=`expr $MFREE / 1000000`
	MTOT=`expr $MTOT / 1000000`
	MMAX=`expr $MMAX / 1000000`

	MUSED=`expr $MTOT - $MFREE`
	MUNUSED=`expr $MMAX - $MUSED`

	echo "memory (MB): max=$MMAX used=$MUSED free=$MUNUSED"
}

tomcatctl_info()
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
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	echo "instance: [$istanza] "
	echo "template: (`cat $DIR_ISTANZE/$istanza/$FILENAME_TEMPLATE`)"
	echo "tag: {`if [ -r $DIR_ISTANZE/$istanza/$FILENAME_TAG ]; then cat $DIR_ISTANZE/$istanza/$FILENAME_TAG; fi`}"
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	tomcatctl_info_memory "$istanza"
	
	echo "applications:"
	tomcatctl_info_apps "$istanza"
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
	echo 'source $DIR_TEMPLATE/bin/setenv.sh' > "$DIR_ISTANZA/bin/setenv.sh"
	cp -r "$DIR_TEMPLATE/conf" "$DIR_ISTANZA/"
	sed -i "/<\/tomcat-users>/ i $TOMCAT_MANAGER_USERS_LINE" "$DIR_ISTANZA/conf/tomcat-users.xml"
	mkdir -p "$DIR_ISTANZA/lib"
	mkdir -p "$DIR_ISTANZA/logs"
	mkdir -p "$DIR_ISTANZA/webapps"
	#cp -r "$DIR_TEMPLATE/webapps" "$DIR_ISTANZA/"
	mkdir -p "$DIR_ISTANZA/work"
	mkdir -p "$DIR_ISTANZA/temp"
	
	# modifico il deployment descriptor del tomcatctlmanager in modo che punti a [$DIR_TOMCAT_MANAGER_RUNTIME]
	if [ "$OS" = "cygwin" ]
	then
		DIR_TOMCAT_MANAGER_RUNTIME=`cygpath -m "$DIR_TOMCAT_MANAGER_RUNTIME"`
	fi
	sed -i "s#$TOMCAT_MANAGER_CONTEXT_PLACEHOLDER#$DIR_TOMCAT_MANAGER_RUNTIME#g" "$DIR_ISTANZA/conf/Catalina/localhost/$TOMCAT_MANAGER_CONTEXT.xml"
	
	echo "$template" > "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	
	if ! [ -z "$tag" ]
	then
		echo "$tag" > "$DIR_ISTANZA/$FILENAME_TAG"
	fi
	
	echolog "creata istanza [$istanza] con template [$template] in [$DIR_ISTANZA] e assegnato il tag [$tag]"
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
	
	if [ -L "$DIR_ISTANZA" ]
	then
		echolog "impossibile eliminare l'istanza [$istanza]: l'istanza e' virtuale"
		return 2
	fi
	
	tomcatctl_status "$istanza"
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


tomcatctl_attach()
{
	attach_path="$1"
	
	if [ -z "$attach_path" ]
	then
		helpmsg
		return 1
	fi
	
	if ! [ -d "$attach_path" ]
	then
		echolog "il path [$attach_path] non esiste"
		return 2
	fi
	
	istanza="$2"
	tag="$3"
	
	if [ -z "$istanza" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$attach_path"`
		ISTANZA_SUGGERITA=`echo "$HTTP_PORT" | grep -o "[0-9][0-9]$"`
		
		istanza="00"
		if ! [ -d "$DIR_ISTANZE/$ISTANZA_SUGGERITA" ]
		then
			if tomcatctl_codice_istanza_is_valido "$ISTANZA_SUGGERITA"
			then
				istanza="$ISTANZA_SUGGERITA"
			fi
		fi
		
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

	ln -s `readlink -f "$attach_path"` "$DIR_ISTANZA"
	if [ $? -ne 0 ]
	then
		echolog "impossibile creare il link simbolico [$DIR_ISTANZA] --> [$attach_path]"
		return 1
	fi
		
	# copio il deployment descriptor del manager per abilitare solo le richieste da localhost
	FILE_DD_MANAGER_SKELETON="$DIR_CONF_TEMPLATE_SKELETONS/conf/Catalina/localhost/$TOMCAT_MANAGER_CONTEXT.xml"
	DIR_DD_MANAGER_ATTACHED="$attach_path/conf/Catalina/localhost/"
	FILE_DD_MANAGER_ATTACHED="$DIR_DD_MANAGER_ATTACHED/$TOMCAT_MANAGER_CONTEXT.xml"
	
	if ! [ -d "$DIR_DD_MANAGER_ATTACHED" ]
	then
		mkdir -p "$DIR_DD_MANAGER_ATTACHED"
		if [ $? -ne 0 ]
		then
			echolog "impossibile creare la cartella [$DIR_DD_MANAGER_ATTACHED] per il deploy del manager"
			return 1
		fi
	fi
	cp "$FILE_DD_MANAGER_SKELETON" "$FILE_DD_MANAGER_ATTACHED"
	if [ $? -ne 0 ]
	then
		echolog "impossibile copiare il deployment descriptor per il manager in [$DIR_DD_MANAGER_ATTACHED]"
		return 1
	fi
	chmod +r "$FILE_DD_MANAGER_ATTACHED"
	
	# modifico il deployment descriptor del tomcatctlmanager in modo che punti a [$DIR_TOMCAT_MANAGER_RUNTIME]
	if [ "$OS" = "cygwin" ]
	then
		DIR_TOMCAT_MANAGER_RUNTIME=`cygpath -m "$DIR_TOMCAT_MANAGER_RUNTIME"`
	fi
	sed -i "s#$TOMCAT_MANAGER_CONTEXT_PLACEHOLDER#$DIR_TOMCAT_MANAGER_RUNTIME#g" "$DIR_ISTANZA/conf/Catalina/localhost/$TOMCAT_MANAGER_CONTEXT.xml"
	
	# copio il file degli utenti se non esiste, lo backuppo
	# e poi aggiungo le credenziali per tomcatctl
	FILE_TUSERS_SKELETON="$DIR_CONF_TEMPLATE_SKELETONS/conf/tomcat-users.xml"
	FILE_TUSERS_ATTACHED="$attach_path/conf/tomcat-users.xml"
	if ! [ -f "$FILE_TUSERS_ATTACHED" ]
	then
		mv "$FILE_TUSERS_SKELETON" "$FILE_TUSERS_ATTACHED"
	else
		cp "$FILE_TUSERS_ATTACHED" "$FILE_TUSERS_ATTACHED~"
	fi
	sed -i "/<\/tomcat-users>/ i $TOMCAT_MANAGER_USERS_LINE" "$FILE_TUSERS_ATTACHED"
	
	chmod g+r $attach_path/conf/tomcat-users* 2> /dev/null
	if [ $? -ne 0 ]
	then
		sudo chmod g+r $attach_path/conf/tomcat-users* 2> /dev/null
		if [ $? -ne 0 ]
		then
			echolog "impossibile modificare i permessi di [$attach_path/conf/tomcat-users*], verificare che i files abbiano permessi di lettura per il gruppo di tomcat e amministratori"
		fi
	fi
	
	# set di template e tag
	echo "$attach_path" > "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	
	if ! [ -z "$tag" ]
	then
		echo "$tag" > "$DIR_ISTANZA/$FILENAME_TAG"
	fi
	
	echolog "agganciato tomcat [$attach_path] all'istanza virtuale [$DIR_ISTANZA] e assegnato il tag [$tag]"
}

tomcatctl_detach()
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
		echolog "impossibile sganciare l'istanza [$istanza]: il path [$DIR_ISTANZA] non esiste"
		return 1
	fi
	
	if [ ! -L "$DIR_ISTANZA" ]
	then
		echolog "l'istanza non e' virtuale, non puo' essere sganciata"
		return 2
	fi
	
	echo "sganciare l'istanza virtuale [$DIR_ISTANZA]? (y/n)"	
	read c
	
	if [ "$c" = "y" ]
	then
		echolog "rimuovo il deployment descriptor del manager"
		FILE_DD_MANAGER_ATTACHED="$DIR_ISTANZA/conf/Catalina/localhost/$TOMCAT_MANAGER_CONTEXT.xml"
		if [ -f "$FILE_DD_MANAGER_ATTACHED" ]
		then
			rm -f "$FILE_DD_MANAGER_ATTACHED"
		fi
		
		echolog "rimuovo le credenziali per il manager di tomcatctl"
		FILE_TUSERS_ATTACHED="$DIR_ISTANZA/conf/tomcat-users.xml"
		sed -i "s#$TOMCAT_MANAGER_USERS_LINE##g" "$FILE_TUSERS_ATTACHED"
		
		if [ -f "$DIR_ISTANZA/$FILENAME_TAG" ]; then rm -f "$DIR_ISTANZA/$FILENAME_TAG"; fi
		if [ -f "$DIR_ISTANZA/$FILENAME_TEMPLATE" ]; then rm -f "$DIR_ISTANZA/$FILENAME_TEMPLATE"; fi
		rm "$DIR_ISTANZA"
		echolog "istanza [$istanza] sganciata"
	else
		echolog "annullato lo sgancio dell'istanza virtuale [$istanza]"
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
	
	if [ -L "$DIR_ISTANZA_ORIGINALE" ]
	then
		echo "$DEFAULT_TEMPLATE" > "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	else
		cp -r "$DIR_ISTANZA_ORIGINALE/$FILENAME_TEMPLATE" "$DIR_ISTANZA/$FILENAME_TEMPLATE"
	fi
	
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
	
		if [ ! -d "$DIR_ISTANZA" ]; then
		
			echolog "impossibile ripulire l'istanza [$istanza]: il path [$DIR_ISTANZA] non esiste"
			return 1
		fi
		
		echolog "clean dell'istanza [$istanza]"
		DIR_TOMCAT_WORK="$DIR_ISTANZA/work/Catalina/localhost"
		test -d "$DIR_TOMCAT_WORK" && rm -rf "$DIR_TOMCAT_WORK"
		
		subarea="$2"
		if [ "$subarea" = "logs" ]; then
		
			DIR_TOMCAT_LOGS="$DIR_ISTANZA/logs"
			
			if [ ! -d "$DIR_TOMCAT_LOGS" ]; then
			
				echolog "impossibile ripulire i logs dell'istanza [$istanza]: il path [$DIR_TOMCAT_LOGS] non esiste"
				return 1
			fi
			
			echolog "backup e clean dei logs dell'istanza [$istanza]"
			FILE_LOGS_TARGZ="$DIR_TOMCAT_LOGS/tomcat.$istanza.logs.`get_timestamp`.tar.gz"
			DIR_CURRENT=`pwd -P`
			cd $DIR_TOMCAT_LOGS
			tar czf $FILE_LOGS_TARGZ ./*.log
			cd $DIR_CURRENT
			rm -f $DIR_TOMCAT_LOGS/*.log
		fi
	fi
}


# args:
# - istanza
# - context applicazione
tomcatctl_appstart()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	context="$2"
	version="$3"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/start?path=$context"
	
	if ! [ -z "$version" ]
	then
		URL="$URL&version=$version"
	fi
	
	$HTTP_BIN "$URL"
}

# args:
# - istanza
# - context applicazione
tomcatctl_appstop()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	context="$2"
	version="$3"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/stop?path=$context"
	
	if ! [ -z "$version" ]
	then
		URL="$URL&version=$version"
	fi
	
	$HTTP_BIN "$URL"
}

tomcatctl_appreload()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		helpmsg
		return 1
	fi
	
	istanza="$1"
	context="$2"
	version="$3"
	
	DIR_ISTANZA="$DIR_ISTANZE/$istanza"
	if ! [ -d "$DIR_ISTANZA" ]
	then
		echolog "istanza [$istanza] inesistente"
		return 1
	fi
	
	if ! tomcatctl_status "$istanza"
	then
		echolog "istanza non disponibile"
		return 1
	fi
	
	HTTP_PORT="90$istanza"
	if [ -L "$DIR_ISTANZA" ]
	then
		HTTP_PORT=`tomcatctl_get_attached_httpport "$istanza"`
	fi
	
	URL="http://$TOMCAT_MANAGER_USERNAME:$TOMCAT_MANAGER_PASSWORD@localhost:$HTTP_PORT/$TOMCAT_MANAGER_CONTEXT/text/reload?path=$context"
	
	if ! [ -z "$version" ]
	then
		URL="$URL&version=$version"
	fi
	
	$HTTP_BIN "$URL"
}



tomcatctl_install_template()
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
	
	template_path="$1"
	template_name="$2"
	
	if ! [ -d "$template_path" ]
	then
		echolog "il path [$template_path] non esiste"
		return 1
	fi

	if [ -d "$DIR_TEMPLATES/$template_name" ]
	then
		echolog "il template [$template_name] esiste gia'"
		return 1
	fi
	
	cp -r "$template_path" "$DIR_TEMPLATES/$template_name"
	cp -r $DIR_CONF_TEMPLATE_SKELETONS/* "$DIR_TEMPLATES/$template_name/"
	
	echolog "template [$template_name] installato"
}

tomcatctl_uninstall_template()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	template_name="$1"

	if ! [ -d "$DIR_TEMPLATES/$template_name" ]
	then
		echolog "il template [$template_name] non esiste"
		return 1
	fi
	
	echo "disinstallare il template [$template_name]? (y/n)"	
	read c

	if [ "$c" = "y" ]
	then
		rm -rf "$DIR_TEMPLATES/$template_name/"
	else
		echolog "operazione annullata"
		return 1
	fi
	
	echolog "template [$template_name] disinstallato"
}

# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------


if [ "$1" = "install" ]
then
	shift
	tomcatctl_install_template $@
	exit $?
fi

if [ "$1" = "uninstall" ]
then
	shift
	tomcatctl_uninstall_template $@
	exit $?
fi

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

if [ "$1" = "attach" ]
then
	shift
	tomcatctl_attach $@
	exit $?
fi

if [ "$1" = "detach" ]
then
	shift
	tomcatctl_detach $@
	exit $?
fi

if [ "$1" = "cp" ]
then
	shift
	tomcatctl_clona_istanza $@
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
	sleep 3
	tomcatctl_start $@
	exit $?
fi

if [ "$1" = "status" ]
then
	shift
	tomcatctl_status $@
	RET=$?
	if [ $RET -eq 0 ]
	then
		echo "up"
	else
		echo "down"
	fi
	exit $RET
fi

if [ "$1" = "info" ]
then
	shift
	tomcatctl_info $@
	tomcatctl_status $@
	RET=$?
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
	tomcatctl_info_apps $@
	exit $?
fi

if [ "$1" = "appstart" ]
then
	shift
	tomcatctl_appstart $@
	exit $?
fi

if [ "$1" = "appstop" ]
then
	shift
	tomcatctl_appstop $@
	exit $?
fi

if [ "$1" = "appreload" ]
then
	shift
	tomcatctl_appreload $@
	exit $?
fi

if [ "$1" = "apprestart" ]
then
	shift
	tomcatctl_appstop $@
	RET=$?
	if [ $RET -ne 0 ]
	then
		echolog "arresto applicazione fallito"
		exit $RET
	fi
	sleep 2
	tomcatctl_appstart $@
	if [ $RET -ne 0 ]
	then
		echolog "avvio applicazione fallito"
		exit $RET
	fi
	exit $RET
fi

if [ "$1" = "clean" ]
then
	shift
	tomcatctl_clean $@
	exit $?
fi


helpmsg
exit 0
