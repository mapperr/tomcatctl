#! /bin/sh

cd `dirname $0`
DIR_BASE=`pwd -P`


# ---------------------------------------------------------
# setup
# ---------------------------------------------------------

URL_REPOSITORY="http://localhost/"

PATH_REPO="tomcatctl"
PATH_TEMPLATES="templates"
PATH_JDK="jdk"
PATH_PACKAGE="tomcatctl.zip"
PATH_TEMPLATE_LIST="template.list"

URL_PACKAGE="$URL_REPOSITORY/$PATH_REPO/$PATH_PACKAGE"
URL_TEMPLATE_DIR="$URL_REPOSITORY/$PATH_REPO/$PATH_TEMPLATES"
URL_TEMPLATE_LIST="$URL_TEMPLATE_DIR/$PATH_TEMPLATE_LIST"
URL_JDK="$URL_REPOSITORY/$PATH_REPO/$PATH_JDK"


# ---------------------------------------------------------
# checks
# ---------------------------------------------------------

if hash wget
then
	BIN_HTTP="wget -q -t1 -T120 --no-proxy"
else
	echo "impossibile trovare un client http valido!"
	echo "installare un client http valido"
	echo "clients validi: wget"
	exit 1
fi

if hash unzip
then
	BIN_UNZIP="unzip"
else
	echo "impossibile trovare un unzipper valido!"
	echo "installare un unzipper"
	echo "programmi validi: unzip"
	exit 1
fi

# rilevo ambienti che hanno bisogno di trattamenti particolari
if uname | grep -i "cygwin" > /dev/null
then
	OS="cygwin"
else
	OS="altro"
fi


# ---------------------------------------------------------
# funzioni
# ---------------------------------------------------------

helpmsg()
{
	SCRIPT_NAME=`basename $0`
	echo ""
	echo "comandi:"
	echo ""
	echo "- install"
	echo "	installa tomcatctl nella directory corrente"
	echo ""
}


# ---------------------------------------------------------
# esecuzione
# ---------------------------------------------------------

if [ "$1" = "install" ]
then
	echo "scarico il pacchetto"
	$BIN_HTTP "$URL_PACKAGE" || exit 1
	
	echo "scarico il checksum"
	$BIN_HTTP "$URL_PACKAGE.md5" || exit 1
	
	echo "eseguo il checksum"
	md5sum -c $PATH_PACKAGE.md5 || exit 1
	
	echo "scompatto il pacchetto"
	$BIN_UNZIP $PATH_PACKAGE > /dev/null || exit 1
	
	echo "setto i permessi di esecuzione per gli script"
	chmod +x tomcatctl bin/tomcatctl.sh
	
	echo "cleanup pacchetto"
	rm -f $PATH_PACKAGE*
	
	echo "recupero configurazioni"
	test -r conf/tomcatctl.rc && source conf/tomcatctl.rc
	
	echo "check configurazioni"
	test -z "$DIR_TEMPLATES" && exit 1
	
	echo "creo una directory per i templates"
	mkdir $DIR_TEMPLATES || exit 1
	cd $DIR_TEMPLATES
	
	echo "scarico la lista templates"
	$BIN_HTTP "$URL_TEMPLATE_LIST" || exit 1
	
	echo "scarico i templates"
	for template in `cat $PATH_TEMPLATE_LIST`
	do
		echo "scarico il template [$template]"
		$BIN_HTTP $URL_TEMPLATE_DIR/$template.zip
		
		echo "scarico il checksum per il template [$template]"
		$BIN_HTTP $URL_TEMPLATE_DIR/$template.zip.md5
		
		echo "eseguo il checksum per il template [$template]"
		md5sum -c "$template.zip.md5"
		if [ $? -eq 0 ]
		then
			echo "scompatto il template [$template]"
			$BIN_UNZIP $template.zip > /dev/null || exit 1
			
			echo "setto i permessi per l'esecuzione del template [$template]"
			chmod ug+x $template/bin/*.sh
		else
			echo "errore nella verifica del checksum del template [$template]"
		fi
		
		echo "cleanup del pacchetto del template [$template]"
		rm -f $template.zip*
	done
	
	echo "cleanup file lista templates"
	rm -f $PATH_TEMPLATE_LIST
	
	cd $DIR_BASE
	
	echo "creo una directory per la jdk"
	mkdir $DIR_JDK || exit 1
	cd $DIR_JDK
	
	echo "scarico la jdk"
	if [ "$OS" = "cygwin" ]
	then
		$BIN_HTTP "$URL_JDK/windows/jdk.zip" || exit 1
	else
		$BIN_HTTP "$URL_JDK/linux/jdk.zip" || exit 1
	fi
	
	echo "scarico il checksum per la jdk"
	if [ "$OS" = "cygwin" ]
	then
		$BIN_HTTP "$URL_JDK/windows/jdk.zip.md5" || exit 1
	else
		$BIN_HTTP "$URL_JDK/linux/jdk.zip.md5" || exit 1
	fi
	
	echo "eseguo il checksum per la jdk"
	md5sum -c "jdk.zip.md5" || exit 1
	
	echo "scompatto il pacchetto della jdk"
	$BIN_UNZIP "jdk.zip" > /dev/null || exit 1
	
	echo "setto i permessi di esecuzione per la jdk"
	chmod ug+x -R bin/* jre/bin/*
	
	echo "cleanup jdk"
	rm -f jdk.zip*
	
	cd $DIR_BASE
	
	echo "fine"
	exit 0
fi

if [ "$1" = "update" ]
then
	echo "update"
	
	echo "fine"
	exit 0
fi

if [ "$1" = "pack" ]
then
	echo "check install"
	test -d bin || exit 1
	test -d conf || exit 1
	test -f tomcatctl || exit 1
	
	echo "zippo"
	zip -r tomcatctl.zip bin conf web tomcatctl > /dev/null || exit 1
	
	echo "generate checksum"
	md5sum tomcatctl.zip > tomcatctl.zip.md5
	
	echo "fine"
	exit 0
fi

if [ "$1" = "uninstall" ]
then
	echo "disinstallo"
	rm -rf bin conf templates istanze web jdk log tomcatctl
	
	echo "fine"
	exit 0
fi

helpmsg
exit 0
