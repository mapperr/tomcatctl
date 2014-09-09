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

try{

if(isset($_FILES['file']))
{
	$tempPos = $_FILES['file']['tmp_name'];
	$destPos = "/tmp/".$_FILES['file']['name'];
	move_uploaded_file($tempPos, $destPos);
	$istanza = $_POST['istanza'];
	$command = "$tomcatctl_bin deploy $istanza $destPos";
	if(isset($_POST['context']) && ($_POST['context'] != ""))
	{
		$command .= " " . $_POST['context'];
		if(isset($_POST['version']) && ($_POST['version'] != ""))
		{
			$command .= " " . $_POST['version'];
		}
	}
	exec("$command", $output_lines);
	echo "<div id='msg'><pre>";
	foreach($output_lines as $outline) echo "$outline<br />";
	echo "</pre></div>";
	unlink($destPos);
}

if($_GET['cmd'] == "log")
{
	$istanza = $_GET['istanza'];
	exec("$tomcatctl_bin log $istanza cat", $output_lines);
	echo "<div id='msg'><pre>";
	foreach($output_lines as $outline) echo "$outline<br />";
	echo "<a name='lastlogline'></a>";
	echo "</pre></div>";
}

// app restart
if( $_GET['cmd'] == "restart" )
{
	$istanza = $_GET['istanza'];
	$context = $_GET['path'];
	$version = $_GET['version'];
	exec("$tomcatctl_bin apprestart $istanza $context $version", $output_lines);
	echo "<div id='msg'><pre>";
	foreach($output_lines as $outline) echo "$outline<br />";
	echo "</pre></div>";
}


// app start
if( $_GET['cmd'] == "start" )
{
    $istanza = $_GET['istanza'];
    $context = $_GET['path'];
    $version = $_GET['version'];
	exec("$tomcatctl_bin appstart $istanza $context $version", $output_lines);
	echo "<div id='msg'><pre>";
	foreach($output_lines as $outline) echo "$outline<br />";
	echo "</pre></div>";
}

// app stop
if( $_GET['cmd'] == "stop" )
{
    $istanza = $_GET['istanza'];
    $context = $_GET['path'];
    $version = $_GET['version'];
	exec("$tomcatctl_bin appstop $istanza $context $version", $output_lines);
    echo "<div id='msg'><pre>";
    foreach($output_lines as $outline) echo "$outline<br />";
	echo "</pre></div>";
}

if( $_GET['cmd'] == "reload" )
{
    $istanza = $_GET['istanza'];
    $context = $_GET['path'];
    $version = $_GET['version'];
    exec("$tomcatctl_bin appreload $istanza $context $version", $output_lines);
    echo "<div id='msg'><pre>";
    foreach($output_lines as $outline) echo "$outline<br />";
    echo "</pre></div>";
}


if( $_GET['cmd'] == "undeploy" )
{
    $istanza = $_GET['istanza'];
    $context = $_GET['path'];
    $version = $_GET['version'];
    exec("$tomcatctl_bin undeploy $istanza $context $version", $output_lines);
    echo "<div id='msg'><pre>";
    foreach($output_lines as $outline) echo "$outline<br />";
	echo "</pre></div>";
}

exec("$tomcatctl_bin ls | grep -v '^#'",$list_outlines);

foreach($list_outlines as $line)
{
	$words = preg_split("/[\s\t]+/",trim($line));
	$codiceIstanza = $words[0];
	$status = (strpos($words[1],"down")===FALSE)?TRUE:FALSE;

	unset($apps_outlines);
	
	echo "<p>";
	$onclick_fragment = "";
	$style_fragment = "";
	if($status)
	{
		exec("$tomcatctl_bin apps $codiceIstanza | grep -v '^#'",$apps_outlines);
		$onclick_fragment = "onclick='toggle_info(\"$codiceIstanza\");'";
		$style_fragment = "font-weight:bold;cursor:pointer;";
	}
	echo "<pre id='status_$codiceIstanza' $onclick_fragment style='font-size:20px;$style_fragment'>$line</pre>";
	echo "<div id='apps_$codiceIstanza' style='margin-left:100px;display:none;'>";
	echo "<a href='?cmd=log&amp;istanza=$codiceIstanza#lastlogline'>log</a> ";
	echo <<<TT
		<form name="deploy" method="post" action="" enctype="multipart/form-data"> 
		<input type="hidden" name="istanza" value="$codiceIstanza">
		war: <input type="file" name="file"> context path: <input type="text" name="context"> version: <input type="text" name="version"> <input type="submit" name="submit" value="deploy">
		</form>
TT;
	echo "<pre>";
	foreach($apps_outlines as $apps_line)
	{
		$apps_words = preg_split("/[\s\t]+/",trim($apps_line));
		$app_context = $apps_words[0];
		$app_version = $apps_words[1];
		$app_status = $apps_words[2];
		$version_querystring = ($app_version != "##") ? "&amp;version=$app_version":"";
		echo "<a href='?cmd=restart&amp;istanza=$codiceIstanza&amp;path=$app_context$version_querystring'>restart</a> ";
		echo "<a href='?cmd=start&amp;istanza=$codiceIstanza&amp;path=$app_context$version_querystring'>start</a> ";
		echo "<a href='?cmd=stop&amp;istanza=$codiceIstanza&amp;path=$app_context$version_querystring'>stop</a> ";
		echo "<a href='?cmd=reload&amp;istanza=$codiceIstanza&amp;path=$app_context$version_querystring'>reload</a> ";
		echo "<a href='?cmd=undeploy&amp;istanza=$codiceIstanza&amp;path=$app_context$version_querystring'>undeploy</a> ";
		echo "<a href='$host:90$codiceIstanza$app_context'>$app_context</a> $app_version $app_status\n";
	}
	echo "</pre>";
	echo "</div></p>";
}

echo <<<TT
</body></html>
TT;
}
catch (Exception $e)
{
    echo 'Caught exception: '.  $e->getMessage(). "\n";
}
?>