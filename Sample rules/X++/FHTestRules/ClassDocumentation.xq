<ClassDocumentation>
{
  for $c in (/Class | /Table | /Form)
      return <Class>
               <Name>{data($c/[@Artifact])}</Name>
               <Documentation>{data($c/[@Comments])}</Documentation>
             </Class>
} 
</ClassDocumentation>