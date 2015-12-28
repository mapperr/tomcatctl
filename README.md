# tomcatctl

version 1.0.1


	commands:

	- help

	- ls
	- create [template] [code] [tag]
	- edit <code> <new_template> [ new_code [new_tag] ]
	- delete <code> [force]
	- clone <source_code> [destination_code] [destination_tag]
	- attach <path_catalina_home> [code] [tag]
	- detach <code>
	- start | stop | restart <code>
	- info <code>
	- log <code> [tail | cat]
	- clean [code [logs]]
	- export <code> [export_dir_absolute_path]
	- import <exported_file_absolute_path> [code]

	- app ls <code>
	- app repo [search_string]
	- app start | stop | restart | reload <code> <application_context_root> <application_version>
	- app deploy <code> <path_war> [context_root] [version]
	- app undeploy <code> <context_root> <version>
	- app install <code> <app_name> [version]

	- template ls
	- template install <template_name>
	- template uninstall <template_name>



## Installation requirements

- a jdk or a jre: in tomcatctl/conf/tomcatctl.rc change the JAVA_HOME variable with your path (and make the files in $JAVA_HOME/bin/* executables)
- a bunch of basic tools, such as wget and tar. Check tomcatctl/conf/tomcatctl.rc for a list, but if you are on a average linux distro you probably already have all you need
