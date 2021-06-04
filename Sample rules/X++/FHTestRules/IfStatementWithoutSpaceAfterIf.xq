declare option db:writeback 'true';
for $if in /Class[@Package="ATS"][@Name="ATSStatementRecognition"]//IfStatement

let $ifExpression := $if/*[1]

where $if/@StartCol + 4 != $ifExpression/@StartCol

let $class := $if/ancestor::Class
let $method := $if/ancestor::Method
let $offset := $method/@StartLine - 1
let $xmlFilename := concat($class/@Name, ".xml")
let $xmlFolderpath := concat(
  "C:\AOSService\PackagesLocalDirectory\", 
  $class/@Package, 
  "\", 
  data(/AxModelInfo[Id=$class/@ModelId]/DisplayName), 
  "\",
  "Ax", 
  name($class),
  "\")
let $sourceDocument := doc(concat($xmlFolderpath, $xmlFilename))
let $sourceMethod := $sourceDocument/AxClass/SourceCode/Methods/Method[Name=$method/@Name]/Source
let $sourceString := data($sourceMethod)
let $sourceLines := tokenize($sourceString, "\n")
let $ifLineNumber := $if/@StartLine - $offset
let $ifLine := $sourceLines[$ifLineNumber]
let $indentation := tokenize($ifLine, "if")
let $fixedIfLine := concat($indentation[1], "if (", substring($ifLine, $ifExpression/@StartCol))
let $test := $sourceLines[position() = ($ifLineNumber cast as xs:integer to last())]
let $fixedSourceLines := (
  $sourceLines[position() = (1 to $ifLineNumber - 1)], 
  $fixedIfLine, 
  $sourceLines[position() = (($ifLineNumber + 1) cast as xs:integer to last())])
  
  
return $fixedSourceLines
(: return replace value of node $sourceMethod with $fixedSourceLines :)

(: return $if/ancestor::Method :)
(: return ($if/ancestor::Class/@Name, $if/ancestor::Method/@Name, $if/@StartLine) :)