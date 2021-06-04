declare variable $db := "00xquerybook"; 
(: declare variable $db := "D365ApplicationExtended"; :)
db:optimize($db, false(), map { })
index:facets($db),
index:element-names($db),
index:attribute-names($db)