function toggle_info(codiceIstanza)
{
	if($("#apps_"+codiceIstanza).css("display") == "none") $("#apps_"+codiceIstanza).show("slow");
	else $("#apps_"+codiceIstanza).hide("slow");
}

