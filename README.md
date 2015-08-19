tomcatctl
=========

commands:

- help

- templates
- install <template_name>
- uninstall <template_name>
- create [template] [code] [tag]
- edit <code> <template> [ new_code [tag] ]
- delete <code>
- clone <source_code> [destination_code] [destination_tag]
- attach <path_catalina_home> [code] [tag]
- detach <code>
- ls
- apps <code>
- appstart | appstop | apprestart | appreload <code> <application_context_root> <application_version>
- start | stop | restart <code>
- info <code>
- deploy <code> <path_war> [context_root] [version]
- undeploy <code> <context_root> <version>
- log <code> [tail | cat]
- clean [code [logs]]
