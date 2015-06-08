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

