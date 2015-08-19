#! /bin/bash


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
	echo '. "$CATALINA_HOME/bin/setenv.sh"' > "$DIR_ISTANZA/bin/setenv.sh"
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
	if [ -z "$1" ]; then
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

tomcatctl_edit()
{
	if [ -z "$1" ]; then
		helpmsg
		return 1
	fi
	
	if [ -z "$2" ]; then
		helpmsg
		return 1
	fi
	
	code="$1"
	new_template="$2"
	new_code="$3"
	new_tag="$4"
	
	# check if code exists
	DIR_INSTANCE="$DIR_ISTANZE/$code"
	if ! [ -e "$DIR_INSTANCE" ]; then
		echolog "instance [$code] not found"
		return 2
	fi
	
	# check if instance is running
	tomcatctl_status "$code"
	RUNNING=$?
	if [ $RUNNING -eq 0 ]; then
		echolog "instance [$code] is running, stop it first"
		return 5
	fi
	
	# check if new_template exists
	if ! [ -d "$DIR_TEMPLATES/$new_template" ]; then
		echolog "template [$new_template] not found"
		return 2
	fi
	
	echo "$new_template" > "$DIR_INSTANCE/TEMPLATE"
	
	if [ -z "$new_code" ]; then return 0; fi
	
	# check if new_code is valid
	if ! tomcatctl_codice_istanza_is_valido "$new_code"; then
		echolog "[$new_code] is not a valid instance code"
		echolog "a valid code is a 2 digit number"
		return 3
	fi
	
	# check if new_code is available
	DIR_NEW_INSTANCE="$DIR_ISTANZE/$new_code"
	if ! [ -e "$DIR_NEW_INSTANCE" ]; then
	 	# if new_code is available mv instance to new code
		mv "$DIR_INSTANCE" "$DIR_NEW_INSTANCE"
	elif [ ! "$code" = "$new_code" ]; then
		echolog "code [$new_code] is already taken"
		return 3
	fi
	
	# if new_tag is not blank then change tag
	if [ -z "$new_tag" ]; then return 0; fi
	echo "$new_tag" > "$DIR_NEW_INSTANCE/TAG"
	
	echolog "instance [$code] modified"
}

tomcatctl_clona_istanza()
{
	istanza_originale="$1"
	
	if [ -z "$istanza_originale" ]; then
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

tomcatctl_clean_instance()
{
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
		FILE_LOGS_TARGZ="$DIR_ISTANZA/tomcat.$istanza.logs.`get_timestamp`.tar.gz"
		DIR_CURRENT=`pwd -P`
		cd $DIR_TOMCAT_LOGS
		tar czf $FILE_LOGS_TARGZ ./*
		cd $DIR_CURRENT
		rm -f $DIR_TOMCAT_LOGS/*
	fi
}
