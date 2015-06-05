tomcatctl
=========

commands:

- templates
- install <template_name>
- uninstall <template_name>
- add [template] [codice_istanza] [tag_istanza]
- del <codice_istanza>
- clone <codice_istanza_originale> [codice_istanza_clonata] [tag_istanza_clonata]
- attach <path_catalina_home> [codice_istanza] [tag_istanza]
- detach <codice_istanza>
- ls
- apps <codice_istanza>
- appstart | appstop | apprestart | appreload <codice_istanza> <context_applicazione> <versione_applicazione>
- start | stop | restart <codice_istanza>
- info <codice_istanza>
- deploy <codice_istanza> <path_war> [context_path] [version]
- undeploy <codice_istanza> <context_path> <version>
- log <codice_istanza> [tail | cat]
- clean [istanza [logs]]

