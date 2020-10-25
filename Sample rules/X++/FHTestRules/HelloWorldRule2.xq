<MyTag>
{
for $c in /Class
return <Class>{data($c/@Name)}</Class>
}
</MyTag>