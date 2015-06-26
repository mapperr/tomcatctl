#! /bin/sh

# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

tomcatctl_list_templates()
{
  echo "=== available templates on [$URL_TEMPLATE_REPO] ===="
  $HTTP_BIN "$URL_TEMPLATE_REPO/templates.list"

  echo ""
  echo "=== installed templates ==="
  for template in `ls $DIR_TEMPLATES`; do
    echo "$template"
  done

}

tomcatctl_install_template()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	template_name="$1"
	
  templates_available=`$HTTP_BIN "$URL_TEMPLATE_REPO/templates.list"`
  
  $BIN_DOWNLOAD "$URL_TEMPLATE_REPO/$template_name.zip"
  $BIN_UNZIP -d $DIR_TEMPLATES $template_name.zip
  if [ -f $template_name.zip ]; then rm $template_name.zip; fi
	echolog "template [$template_name] installed"
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
		echolog "template [$template_name] is not installed"
		return 1
	fi
	
	echo "uninstall template [$template_name]? (y/n)"	
	read c

	if [ "$c" = "y" ]
	then
		rm -rf "$DIR_TEMPLATES/$template_name/"
	else
		echolog "uninstall aborted"
		return 1
	fi
	
	echolog "template [$template_name] uninstalled"
}

