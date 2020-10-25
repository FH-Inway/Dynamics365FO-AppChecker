for $c in /(Class | Form | Table | Entity)[@Package="MixedRealityCore"]
let $filename := concat("C:\Temp\xpp\MixedRealityCore\", data($c/[@PathContribution]), ".xpp")
let $source := xs:string(data($c/[@Source]))
(:return file:write-text($filename, $source):)
return $c

