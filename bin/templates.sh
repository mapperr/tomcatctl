#! /bin/sh

# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

tomcatctl_list_templates()
{
  $HTTP_BIN "$URL_TEMPLATE_REPO/list.txt"
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

