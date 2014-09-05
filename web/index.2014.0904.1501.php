<?php

require_once "conf.php";

echo <<<TT
<html>
<head>
<script src="jquery-2.1.1.min.js"></script>
<script src="main.js"></script>
</head>
<body>
TT;

exec("$tomcatctl_bin ls | grep -v '^#'",$list_outlines);

foreach($list_outlines as $line)
{
	$words = preg_split("/[\s\t]+/",trim($line));
	$codiceIstanza = $words[0];
	
	unset($apps_outlines);
	exec("$tomcatctl_bin apps $codiceIstanza | grep -v '^#'",$apps_outlines);
	
	echo "<p>";
	echo "<pre id='status_$codiceIstanza' onclick='toggle_info($codiceIstanza)' style='font-size:20px;cursor:pointer;'>$line</pre>";
	echo "<pre id='apps_$codiceIstanza' style='margin-left:100px;display:none;'>";
	foreach($apps_outlines as $apps_line)
	{
		$apps_words = preg_split("/[\s\t]+/",trim($apps_line));
		$app_context = $apps_words[0];
		$app_version = $apps_words[3];
		$app_status = $apps_words[1];
		echo "<a href='$host:90$codiceIstanza$app_context'>$app_context</a> $app_version $app_status\n";
	}
	echo "</pre>";
	echo "</p>";
}

echo <<<TT
</body></html>
TT;

?>
