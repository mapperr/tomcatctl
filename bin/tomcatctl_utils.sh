#! /bin/sh

tomcatctl_clean()
{
	echolog "deleting old log files"
	
	for logfile in `ls "$DIR_LOG"`
	do
		if ! [ "$DIR_LOG/$logfile" = "$FILE_LOG" ]
		then
			echolog "deleting [$DIR_LOG/$logfile]"
			rm -f "$DIR_LOG/$logfile"
			if [ $? -ne 0 ]
			then
				echolog "the file [$DIR_LOG/$logfile] cannot be deleted"
				return 1
			fi
		fi
	done
}

