import module namespace functx = "http://www.functx.com";

declare variable $elementNames := ('Entity', 'Table');
declare variable $objectNames := ('ProjInvoiceProposalHourEntity', 'ProjInvoiceProposalHourStaging');


let $objects := /*[name() = $elementNames][@Name=$objectNames]
for $object in $objects
let $objectWOElements := functx:remove-elements-deep($object,
(: let $classWOElements := functx:remove-elements-not-contents($class, :)
  (
    "AttributeList",
    "AttributeExpression",
    "StringLiteralExpression",
    "NamedType",
    "Implements",
    "ReturnStatement",
    "ParameterDeclaration",
    "ExpressionStatement",
    "AssignEqualStatement",
    "LocalDeclarationsStatement",
    "IfStatement",
    "IfThenElseStatement",
    "CompoundStatement",
    "SuperCall",
    "IntLiteralExpression",
    "ContainerLiteralExpression",
    "SimpleField",
    "FieldExpression",
    "QualifiedStaticFieldExpression",
    "QualifiedStaticField",
    "StaticQualifier",
    "StringType",
    "BooleanLiteralExpression",
    "ContainerType",
    "NullLiteralExpression",
    "VariableDeclaration",
    "QualifiedField",
    "ExpressionQualifier",
    "QualifiedCall",
    "NewCall",
    "FunctionCall",
    "AsExpression",
    "Intrinsic",
    "Int64Type"
  ))
let $objectWOAttributes := functx:remove-attributes-deep($objectWOElements, 
  (
    "ElementTypeName",
    "PathContribution", 
    "HasCyclicInheritance", 
    "IsNested", 
    "Qualifier", 
    "IsStatic", 
    "IsFinal", 
    "IsAbstract", 
    "IsCompositeDataEntityView", 
    "Modifiers", 
    "Visibility",
    "IsPrivate",
    "IsPublic",
    "IsInternal",
    "IsObsolete",
    "HasNamespace",
    "Namespace",
    "FullName",
    "FullNameNoDefaultNamespace",
    "IsKernel",
    "IsNameEscaped",
    "Comments",
    "NeedsTransformation",
    "Artifact",
    "HeaderPosition",
    "Type",
    "StartLine",
    "StartCol",
    "EndLine",
    "EndCol",
    "Source",
    
    (: AttributeList attributes :)
    "ContainsInternalUseOnlyAttribute",
    
    (: Attribute attributes :)
    "NonFullyQualifiedName",
    
    (: Method attributes :)
    "IsExtendedMethod",
    "HasLocalFunctions",
    "IsProtected",
    "IsClient",
    "IsServer",
    "IsDisplay",
    "IsEdit",
    "IsConstructor",
    "IsTypeInitializer",
    "IsExplicitNonHookable",
    "IsHookable",
    "IsHookableOnChainOfCommand",
    "IsExplicitNonWrappable",
    "IsWrappable",
    "IsPrivateWrappable",
    "IsReplaceable",
    "AlwaysCallsSuper",
    "Reachability",
    "BaseMethodDeclaration"
    
  ))
return $objectWOAttributes 