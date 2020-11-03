let $module := "SCI"
for $c in /(Class | Form | Table | Entity)[@Package=$module]
let $folderPath := concat("C:\Temp\xpp\", $module, "\")
let $_ := if (not(file:exists($folderPath))) then file:create-dir($folderPath)
let $filename := concat($folderPath, data($c/[@PathContribution]), ".xpp")
let $source := xs:string(data($c/[@Source]))
return file:write-text($filename, $source)
(:return $c:)

