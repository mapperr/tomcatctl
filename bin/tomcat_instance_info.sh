#! /bin/bash


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

