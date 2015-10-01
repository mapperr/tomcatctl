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

includes="templates.sh tomcat_instance_admin.sh tomcat_instance_control.sh tomcat_instance_info.sh apps.sh tomcatctl_utils.sh"
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
	echo "- help"
	test $full && echo "	show this help" && echo ""
	echo ""
	echo "- ls"
	test $full && echo "	lists templates and instances under control" && echo ""
	echo "- create [template] [code] [tag]"
	test $full && echo "	creates a new instance" && echo ""
	echo "- edit <code> <template> [ new_code [tag] ]"
	test $full && echo "	modify an instance" && echo ""
	echo "- delete <code>"
	test $full && echo "	deletes an instance" && echo ""
	echo "- clone <source_code> [destination_code] [destination_tag]"
	test $full && echo "	clones the instance <source_code>" && echo ""
	echo "- attach <path_catalina_home> [code] [tag]"
	test $full && echo "	attachs to a existent tomcat instance outside tomcatctl" && echo ""
	echo "- detach <code>"
	test $full && echo "	detach the attached external instance" && echo ""
	echo "- start | stop | restart <code>"
	test $full && echo "	controls the instance" && echo ""
	echo "- info <code>"
	test $full && echo "	shows info about the instance" && echo ""
	echo "- log <code> [tail | cat]"
	test $full && echo "	shows the catalina.out of the instance, by default with the 'less' command" && echo ""
	echo "- clean [code [logs]]"
	test $full && echo "	deletes the tomcatctl log files. If an instance is specified then deletes the work directory. If 'logs' is specified then backups the 'logs' folder and deletes its contents" && echo ""
	echo "- export <code> [export_dir_absolute]"
	test $full && echo "	export the specified instance in exported_dir if specified" && echo ""
	echo "- import <exported_file> [code]"
	test $full && echo "	import instance file into first available code or into the specified code" && echo ""
	echo ""
	echo "- app ls <code>"
	test $full && echo "	lists applications deployed on the instance" && echo ""
	echo "- app start | stop | restart | reload <code> <application_context_root> <application_version>"
	test $full && echo "	controls an application" && echo ""
	echo "- app deploy <code> <path_war> [context_root] [version]"
	test $full && echo "	deploys the war on target instance" && echo ""
	echo "- app undeploy <code> <context_root> <version>"
	test $full && echo "	undeploy an application" && echo ""
	echo ""
	echo "- template ls"
	test $full && echo "	list installed and available templates" && echo ""
	echo "- template install <template_name>"
	test $full && echo "	download and install a template" && echo ""
	echo "- template uninstall <template_name>"
	test $full && echo "	delete an installed template" && echo ""
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "help" ]; then
  helpmsg 0
  exit $?
fi

if [ "$1" = "template" ]; then
	shift
	
	if [ "$1" = "ls" ]; then
		tomcatctl_list_templates $@
		exit $?
	elif [ "$1" = "install" ]; then
		shift
		tomcatctl_install_template $@
		exit $?
	elif [ "$1" = "uninstall" ]; then
		shift
		tomcatctl_uninstall_template $@
		exit $?
	fi
fi

if [ "$1" = "create" ]; then
	shift
	tomcatctl_create $@
	exit $?
fi

if [ "$1" = "edit" ]; then
	shift
	tomcatctl_edit $@
	exit $?
fi

if [ "$1" = "delete" ]; then
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

if [ "$1" = "clone" ]; then
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
		echo "cannot stop instance [$1]"
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

if [ "$1" = "export" ]; then
	shift
	tomcatctl_export_instance $1 $2 $3
	exit $?
fi

if [ "$1" = "import" ]; then
	shift
	tomcatctl_import_instance $1 $2 $3
	exit $?
fi

if [ "$1" = "app" ]; then
	shift
	
	if [ "$1" = "ls" ]; then
		shift
		tomcatctl_info_apps $@
		exit $?
	elif [ "$1" = "start" ]; then
		shift
		tomcatctl_appstart $@
		exit $?
	elif [ "$1" = "appstop" ]; then
		shift
		tomcatctl_appstop $@
		exit $?
	elif [ "$1" = "appreload" ]; then
		shift
		tomcatctl_appreload $@
		exit $?
	elif [ "$1" = "apprestart" ]; then
		shift
		tomcatctl_appstop $@
		RET=$?
		if [ $RET -ne 0 ]; then
			echolog "application start failed"
			exit $RET
		fi
		sleep 2
		tomcatctl_appstart $@
		if [ $RET -ne 0 ]; then
			echolog "application stop failed"
			exit $RET
		fi
		exit $RET
	fi
fi

if [ "$1" = "clean" ]; then
	shift
  if [ -z "$1" ]; then tomcatctl_clean;
  else tomcatctl_clean_instance $@; fi
	exit $?
fi

helpmsg
exit 0
