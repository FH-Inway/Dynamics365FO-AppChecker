<R>
{
    for $c in /(Class | Table | Query | Form)
    for $m in $c//Method
    let $name := $m/@Name
    where lower-case($m/@Name) = ("next",
"while", 
"guid", 
"int", 
"int64", 
"str", 
"container", 
"real", 
"date", 
"utcdatetime", 
"void", 
"anytype", 
"null", 
"super", 
"class", 
"interface", 
"implements", 
"extends", 
"like", 
"div", 
"mod", 
"in", 
"do", 
"throw", 
"try", 
"catch", 
"switch", 
"case", 
"default", 
"if", 
"else", 
"print", 
"break", 
"breakpoint", 
"continue", 
"return", 
"f", 
"retry", 
"select", 
"delete_from", 
"from", 
"index", 
"hint", 
"firstfast", 
"reverse", 
"firstonly", 
"firstonly1", 
"firstonly10", 
"firstonly100", 
"firstonly1000", 
"fceliterals", 
"fcenestedloop", 
"fceselectder", 
"fceplaceholders", 
"fupdate", 
"nofetch", 
"repeatableread", 
"optimisticlock", 
"pessimisticlock", 
"generateonly", 
"crosscompany", 
"where", 
"der", 
"group", 
"by", 
"asc", 
"desc", 
"outer", 
"exists", 
"notexists", 
"join", 
"count", 
"avg", 
"sum", 
"minof", 
"maxof", 
"insert_recdset", 
"update_recdset", 
"setting", 
"ttsbegin", 
"ttscommit", 
"ttsabt", 
"flush", 
"next", 
"changecompany", 
"private", 
"protected", 
"public", 
"final", 
"abstract", 
"static", 
"display", 
"edit", 
"server", 
"client", 
"true", 
"false", 
"eventhandler", 
"delegate", 
"as", 
"is", 
"byref", 
"unchecked", 
"validtimestate", 
"finally", 
"namespace", 
"using", 
"const", 
"readonly", 
"internal", 
"var"  )
    order by $name
    return <NamedMethod Artifact='{$c/@Artifact}' 
    Name='{$m/@Name}'
    StartLine='{$m/@StartLine}' EndLine='{$m/@EndLine}' 
    StartCol='{$m/@StartCol}' EndCol='{$m/@EndCol}' 
/>
}
</R>
