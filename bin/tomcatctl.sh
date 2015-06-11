#! /bin/sh

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/tomcatctl.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "configuration file [$FILE_CONFIG] not found"
	exit 1
fi

. "$FILE_CONFIG"

includes="templates.sh tomcat_instance_admin.sh tomcat_control.sh tomcat_instance_info.sh apps.sh tomcatctl_utils.sh"
for include in $includes; do
  file_include="bin/$include"
  if ! [ -r "$file_include" ]; then
	  echo "file [$include] not found"
	  exit 1
  fi
  . $file_include
done


# ---------------------------------------------------------
# setup
# ---------------------------------------------------------

DIRS="$DIR_LOG $DIR_ISTANZE $DIR_TEMPLATES"

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
  full=$1

	echo ""
	echo "commands:"
	echo ""
	echo "- templates"
	test $full && echo "	list installed and available templates" && echo ""
	echo "- install <template_name>"
	test $full && echo "	download and install a template" && echo ""
	echo "- uninstall <template_name>"
	test $full && echo "	delete an installed template" && echo ""
	echo "- add [template] [codice_istanza] [tag_istanza]"
	test $full && echo "	crea un'istanza di tomcat dal template [template] (o da quello di default se omesso) e gli assegna un codice istanza non ancora utilizzato oppure [codice_istanza] se specificato inoltre gli assegna un tag se specificato" && echo ""
	echo "- del <codice_istanza>"
	test $full && echo "	elimina l'istanza a cui e' stato assegnato il codice <codice_istanza>" && echo ""
	echo "- clone <codice_istanza_originale> [codice_istanza_clonata] [tag_istanza_clonata]"
	test $full && echo "	clona l'istanza specificata" && echo ""
	echo "- attach <path_catalina_home> [codice_istanza] [tag_istanza]"
	test $full && echo "	aggancia l'istanza di tomcat <path_catalina_home> e gli assegna un codice istanza non ancora utilizzato oppure [codice_istanza] se specificato inoltre gli assegna un tag se specificato" && echo ""
	echo "- detach <codice_istanza>"
	test $full && echo "	sgancia l'istanza virtuale a cui e' stato assegnato il codice <codice_istanza>" && echo ""
	echo "- ls"
	test $full && echo "	lista dei templates e delle istanze" && echo ""
	echo "- apps <codice_istanza>"
	test $full && echo "	lista delle applicazioni deployate con relativo status, context path e versione" && echo ""
	echo "- appstart | appstop | apprestart | appreload <codice_istanza> <context_applicazione> <versione_applicazione>"
	test $full && echo "	controllo dell'applicazione" && echo ""
	echo "- start | stop | restart <codice_istanza>"
	test $full && echo "	controllo del tomcat" && echo ""
	echo "- info <codice_istanza>"
	test $full && echo "	mostra informazioni sullo stato dell'istanza" && echo ""
	echo "- deploy <codice_istanza> <path_war> [context_path] [version]"
	test $full && echo "	effettua il deploy del war passato come argomento con il context path specificato se il context path e' gia' utilizzato, allora viene effettuato prima l'undeploy dell'applicazione che ha quel context path. Note: se c'e' l'autoDeploy attivo sul tomcat, allora il context path e' obbligatorio" && echo ""
	echo "- undeploy <codice_istanza> <context_path> <version>"
	test $full && echo "	effettua l'undeploy dell'applicazione che ha il context path passato come argomento" && echo ""
	echo "- log <codice_istanza> [tail | cat]"
	test $full && echo "	mostra il catalina.out dell'istanza <codice_istanza>" && echo ""
	echo "- clean [istanza [logs]]"
	test $full && echo "	elimina i file temporanei di tomcatctl, oppure di un'istanza di tomcat. Con [logs] vengono eliminati anche i files di log" && echo ""
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "help" ]; then
  helpmsg 0
  exit $?
fi

if [ "$1" = "templates" ]; then
  tomcatctl_list_templates $@
  exit $?
fi

if [ "$1" = "install" ]; then
  shift
  tomcatctl_install_template $@
  exit $?
fi

if [ "$1" = "uninstall" ]; then
  shift
  tomcatctl_uninstall_template $@
  exit $?
fi

if [ "$1" = "add" ]; then
	shift
	tomcatctl_create $@
	exit $?
fi

if [ "$1" = "rm" ]; then
	shift
	tomcatctl_delete $@
	exit $?
fi

if [ "$1" = "attach" ]; then
	shift
	tomcatctl_attach $@
	exit $?
fi

if [ "$1" = "detach" ]; then
	shift
	tomcatctl_detach $@
	exit $?
fi

if [ "$1" = "cp" ]; then
	shift
	tomcatctl_clona_istanza $@
	exit $?
fi

if [ "$1" = "ls" ]; then
	tomcatctl_list
	exit $?
fi

if [ "$1" = "start" ]; then
	shift
	tomcatctl_start $@
	exit $?
fi

if [ "$1" = "stop" ]; then
	shift
	tomcatctl_stop $@
	exit $?
fi

if [ "$1" = "restart" ]; then
	shift
	tomcatctl_stop $@
	RET=$?
	if [ $RET -ne 0 ]; then
		echo "impossibile stoppare l'istanza [$1]"
		exit $RET
	fi
	sleep 3
	tomcatctl_start $@
	exit $?
fi

if [ "$1" = "status" ]; then
	shift
	tomcatctl_status $@
	RET=$?
	if [ $RET -eq 0 ]; then
		echo "up"
	else
		echo "down"
	fi
	exit $RET
fi

if [ "$1" = "info" ]; then
	shift
	tomcatctl_info $@
	tomcatctl_status $@
	RET=$?
	exit $RET
fi

if [ "$1" = "log" ]; then
	shift
	tomcatctl_log $@
	exit $?
fi

if [ "$1" = "deploy" ]; then
	shift
	tomcatctl_deploy $@
	exit $?
fi

if [ "$1" = "undeploy" ]; then
	shift
	tomcatctl_undeploy $@
	exit $?
fi

if [ "$1" = "apps" ]; then
	shift
	tomcatctl_info_apps $@
	exit $?
fi

if [ "$1" = "appstart" ]; then
	shift
	tomcatctl_appstart $@
	exit $?
fi

if [ "$1" = "appstop" ]; then
	shift
	tomcatctl_appstop $@
	exit $?
fi

if [ "$1" = "appreload" ]; then
	shift
	tomcatctl_appreload $@
	exit $?
fi

if [ "$1" = "apprestart" ]; then
	shift
	tomcatctl_appstop $@
	RET=$?
	if [ $RET -ne 0 ]; then
		echolog "arresto applicazione fallito"
		exit $RET
	fi
	sleep 2
	tomcatctl_appstart $@
	if [ $RET -ne 0 ]; then
		echolog "avvio applicazione fallito"
		exit $RET
	fi
	exit $RET
fi

if [ "$1" = "clean" ]; then
	shift
  if [ -z "$1" ]; then tomcatctl_clean;
  else tomcatctl_clean_instance $@; fi
	exit $?
fi


helpmsg
exit 0
