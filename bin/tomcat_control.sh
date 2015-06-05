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
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "nohup $CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			echolog "tentativo di avvio con comando sudo -u"
			sudo -u "$CATALINA_USER" CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" nohup bash "$CATALINA_HOME/bin/startup.sh" 2> /dev/null
			RET=$?
			if [ $RET -ne 0 ]
			then
				echolog "tentativo di avvio con comando sudo su"
				sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "nohup $CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
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
		CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "nohup $CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
		RET=$?
		
		# se non si hanno i permessi per utilizzare "su" il comando ritorna 126:
		# "126 if subshell is found but cannot be invoked"
		# https://www.gnu.org/software/coreutils/manual/html_node/su-invocation.html
		if [ $RET -eq 126 ]
		then
			echolog "tentativo di arresto con comando sudo -u"
			sudo -u "$CATALINA_USER" CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" nohup bash "$CATALINA_HOME/bin/shutdown.sh" 2> /dev/null
			RET=$?
			if [ $RET -ne 0 ]
			then
				echolog "tentativo di arresto con comando sudo su"
				sudo CATALINA_HOME="$DIR_TEMPLATES/$template" CATALINA_BASE="$DIR_ISTANZA" su -s /bin/sh -c "nohup $CATALINA_HOME/bin/shutdown.sh" "$CATALINA_USER" 2> /dev/null
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
		. "$CATALINA_HOME/bin/setenv.sh"
	fi
	
	if ! [ -z "$CATALINA_INIT" ]
	then
		echolog "tentativo di avvio con sudo tramite script esterno: trovato CATALINA_INIT [$CATALINA_INIT]"
		sudo nohup $CATALINA_INIT start
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
		su -s /bin/sh -c "nohup $CATALINA_HOME/bin/startup.sh" "$CATALINA_USER" 2> /dev/null
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
		. "$CATALINA_HOME/bin/setenv.sh"
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

