tomcatctl_is_reserved_contexts()
{
	local context="$1"

	if echo $context | grep "^/" >/dev/null; then
		context=`echo $context | sed 's#^/##'`
	fi

	for reserved_context in $RESERVED_CONTEXTS; do
		if [ "$reserved_context" = "$context" ]; then
			return 0
		fi
	done

	return 1
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

	APPS="`$HTTP_BIN "$URL" | grep -v "^OK" | sed 's/:/ /g'`"

	for reserved_context in $RESERVED_CONTEXTS; do
		APPS="`echo "$APPS" | grep -v "^/$reserved_context\b"`"
	done

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
	
	if tomcatctl_is_reserved_contexts "$context"; then
		echo "cannot undeploy a reserved context"
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
	
	if tomcatctl_is_reserved_contexts "$context"; then
		echolog "cannot deploy to a reserved context"
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
	
	if tomcatctl_is_reserved_contexts "$context"; then
		echolog "cannot stop a reserved context"
		return 4
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
	
	if tomcatctl_is_reserved_contexts "$context"; then
		echolog "cannot reload a reserved context"
		return 4
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

tomcatctl_get_artifact()
{
	local name="$1"
	local version="$2"

	if [ -z "$name" ]; then
		helpmsg
		return 1
	fi

	file_artifact_unversioned=`$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">$name.war" | sed 's/>//'`
	file_artifact=`$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">$name##$version.war" | sed 's/>//'`

	if [ -z "$version" ]; then
		if [ -z "$file_artifact_unversioned" ]; then
			echolog "no artifact found" >&2
			return 1
		fi
		echo "$file_artifact_unversioned"
		return 0
	fi

	if [ -z "$file_artifact" ]; then
		echolog "no artifact found" >&2
		return 1
	fi

	echolog "found artifact [$file_artifact]" >&2
	echo "$file_artifact"
}

tomcatctl_get_context_file()
{
	local name="$1"
	local version="$2"

	if [ -z "$name" ]; then
		helpmsg
		return 1
	fi

	file_context_unversioned=`$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">$name.xml" | sed 's/>//'`
	files_context_versioned=`$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">$name##.*.xml" | sed 's/>//' | sort -r`

	file_context="$file_context_unversioned"

	if [ -z "$version" ]; then
		if [ -z "$file_context" ]; then
			echolog "no context file found" >&2
			return 1
		fi
		echo "$file_context"
		return 0
	fi

	for file_context_versioned in $files_context_versioned; do
		file_context_version=`echo $file_context_versioned | sed -e 's/##/|/' -e 's/\.xml$//' | cut -d "|" -f 2`
		if [ "$version" = "$file_context_version" ]; then
			file_context="$file_context_versioned"
			break
		fi
		if [ "$version" '>' "$file_context_version" ]; then
			file_context="$file_context_versioned"
			break
		fi
	done

	if [ -z "$file_context" ]; then
		echolog "no context file found" >&2
		return 1
	fi

	echolog "found context file [$file_context]" >&2
	echo "$file_context"
}

tomcatctl_appinstall()
{
	local instance="$1"
	local context="$2"
	local version="$3"

	if [ -z "$instance" ] || [ -z "$context" ]
	then
		helpmsg
		return 1
	fi
	
	if tomcatctl_is_reserved_contexts "$context"; then
		echolog "cannot install with a reserved context"
		return 4
	fi

	artifact_file=`tomcatctl_get_artifact $context $version`
	context_file=`tomcatctl_get_context_file $context $version`
 
	if [ -z "$artifact_file" ]; then
		echolog "artifact [$context] not found at version [$version]" >&2
		return 1
	fi

	if [ -z "$context_file" ]; then
		echolog "context file [$context] not found at version [$version]" >&2
		return 1
	fi

	url_artifact=`echo "$URL_ARTIFACT_REPO/$artifact_file" | sed 's/#/%23/g'`
	url_context_file=`echo "$URL_ARTIFACT_REPO/$context_file" | sed 's/#/%23/g'`

	cd /tmp
	$HTTP_BIN_DOWNLOAD "$url_artifact"
	if [ $? -ne 0 ]; then echolog "error downloading artifact from [$url_artifact]" >&2; return 1; fi

	$HTTP_BIN_DOWNLOAD "$url_context_file"
	if [ $? -ne 0 ]; then echolog "error downloading context file from [$url_context_file]" >&2; return 1; fi
	cd - >/dev/null

	unpacked_artifact_name="$context##$version"
	if [ -z "$version" ]; then
		unpacked_artifact_name="$context"
	fi

	rm -f  $DIR_ISTANZE/$instance/conf/Catalina/localhost/$context.xml
	rm -f  $DIR_ISTANZE/$instance/conf/Catalina/localhost/$context##*.xml
	rm -rf $DIR_ISTANZE/$instance/webapps/$context
	rm -rf $DIR_ISTANZE/$instance/webapps/$context##*

	mv /tmp/$context_file $DIR_ISTANZE/$instance/conf/Catalina/localhost/$unpacked_artifact_name.xml
	unzip -d $DIR_ISTANZE/$instance/webapps/$unpacked_artifact_name /tmp/$artifact_file >/dev/null

	if [ ! -z "$CATALINA_GROUP" ]; then
		chgrp $CATALINA_GROUP -R $DIR_ISTANZE/$instance 2>/dev/null
		chmod -R g+rw $DIR_ISTANZE/$instance 2>/dev/null
	fi

	test -f /tmp/$artifact_file && rm -f /tmp/$artifact_file
	test -f /tmp/$context_file && rm -f /tmp/$context_file

	echolog "installed [$context] at version [$version] on instance [$instance]"
}


tomcatctl_applist_repo()
{
	search_string="$1"

	if [ -z "$search_string" ]; then
		$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">.*<" | grep -e "\.war" -e "\.xml" | sed -e 's/>//' -e 's/<//' | sort
		exit 0
	fi

	$HTTP_BIN "$URL_ARTIFACT_REPO" | grep -o ">.*<" | grep -e "\.war" -e "\.xml" | sed -e 's/>//' -e 's/<//' | sort | grep -i "$search_string"
}
