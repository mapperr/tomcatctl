#! /bin/bash

cd `dirname $0`
DIR_BASE=`pwd -P`

# ---------------------------------------------------------
# setup
# ---------------------------------------------------------

URL_REPOSITORY="http://tomcatctl.mapperr.net"

PATH_REPO="tomcatctl"
PATH_PACKAGE="tomcatctl.tar.gz"
PATH_TEMPLATES="templates"
PATH_JDK="jdk"
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


# rilevo ambienti che hanno bisogno di trattamenti particolari
if uname | grep -i "cygwin" > /dev/null
then
	OS="cygwin"
else
	OS="altro"
fi

echo "scarico il pacchetto"
$BIN_HTTP "$URL_PACKAGE" || exit 1

echo "scarico il checksum"
$BIN_HTTP "$URL_PACKAGE.md5" || exit 1

echo "eseguo il checksum"
md5sum -c $PATH_PACKAGE.md5 || exit 1

echo "scompatto il pacchetto"
tar xzf $PATH_PACKAGE > /dev/null || exit 1

echo "setto i permessi di esecuzione per gli script"
chmod -R ug+x tomcatctl bin

echo "cleanup pacchetto"
rm -f $PATH_PACKAGE*

echo "recupero configurazioni"
test -r conf/tomcatctl.rc && source conf/tomcatctl.rc

echo "check configurazioni"
test -z "$DIR_TEMPLATES" && exit 1

echo "creo una directory per i templates"
mkdir $DIR_TEMPLATES || exit 1

cd $DIR_BASE

echo "creo una directory per la jdk"
mkdir $DIR_JDK || exit 1
cd $DIR_JDK

echo "scarico la jdk"
if [ "$OS" = "cygwin" ]
then
	$BIN_HTTP "$URL_JDK/windows/jdk.tar.gz" || exit 1
else
	$BIN_HTTP "$URL_JDK/linux/jdk.tar.gz" || exit 1
fi

echo "scarico il checksum per la jdk"
if [ "$OS" = "cygwin" ]
then
	$BIN_HTTP "$URL_JDK/windows/jdk.tar.gz.md5" || exit 1
else
	$BIN_HTTP "$URL_JDK/linux/jdk.tar.gz.md5" || exit 1
fi

echo "eseguo il checksum per la jdk"
md5sum -c "jdk.tar.gz.md5" || exit 1

echo "scompatto il pacchetto della jdk"
tar xzf "jdk.tar.gz" > /dev/null || exit 1

echo "setto i permessi di esecuzione per la jdk"
chmod ug+x -R bin/* jre/bin/*

echo "cleanup jdk"
rm -f jdk.tar.gz

cd $DIR_BASE

echo "modifing repository url"
sed -i "s#^URL_TEMPLATE_REPO=.*#URL_TEMPLATE_REPO='$URL_REPOSITORY/$PATH_REPO'#g" "conf/tomcatctl.rc"

echo "fine"

echo "check conf/tomcatctl.rc for additional configuration"
exit 0
