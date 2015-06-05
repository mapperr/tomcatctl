# codice tomcat
CODICE_TOMCAT=`basename $CATALINA_BASE`

echo "codice istanza [$CODICE_TOMCAT]"

# altro
CATALINA_PID="$CATALINA_BASE/catalina.pid"

# opzioni java virtual machine
INSTANCE_OPTS="-Dcodice.tomcat=$CODICE_TOMCAT"
VM_OPTS="-server"
MEMORY_OPTS="-Xms128m -Xmx256m"
#GARBAGE_OPTS="-XX:+UseG1GC"
#JMX_AUTH_OPTS="-Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
#JMX_OPTS="-Dcom.sun.management.jmxremote.port=100$CODICE_TOMCAT"

CATALINA_OPTS="$INSTANCE_OPTS $VM_OPTS $MEMORY_OPTS $GARBAGE_OPTS $JMX_OPTS $JMX_AUTH_OPTS"

# le CATALINA_OPTS non vengono considerate per lo shutdown,
# quindi le relative funzioni non considerano il codice tomcat
# e non trovano ad esempio la porta di shutdown
# il codice tomcat va aggiunto anche alle JAVA_OPTS
JAVA_OPTS="$JAVA_OPTS $INSTANCE_OPTS"

# pre-esecuzione

# maschera che setti tutti i permessi per il gruppo e l'owner
umask 0002
