﻿using Azure;
using Azure.AI.OpenAI;
using Microsoft.SemanticKernel.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.OpenAI;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static System.Windows.Forms.Design.AxImporter;

namespace XppReasoningWpf.OpenAI
{
    /// <summary>
    /// This class does the evaluation of the AI (for now: OpenAI) prompts.
    /// </summary>
    internal class PromptEvaluator
    {
        /// <summary>
        /// This is the system prompt that is used to inform the AI model about what to do when presented 
        /// with some X++ code.
        /// </summary>
        public const string ManipulateSystemPrompt = @"You are a friendly assistant that is an expert in the X++ programming language.
You are able to perform various refactoring tasks, and you know about the semantics of the X++ language.
Always provide explanations in comments (i.e. prefixed with //) at the start of the result.
Do not remove anything from the result for brevity.
";
        public const string FindSystemPrompt = @"
Your job is to convert natural language text to XQuery queries over XML in the BaseX database with the format described below.  
The queries work over the collection of documents in the database.

Note: All generated XQueries must be case insensitive. Convert to lower case when needed.

It the prompt contains text in (: ... :), then convert the text into an XQuery query and return the result enclosed in 'Query->' and '<-Query' on single lines.
If not, assume that the query is already an XQuery query, and return the query enclosed in 'ProvidedQuery->' and '<-ProvidedQuery' on single lines.

Always provide an explanation enclosed in 'E->' and '<-E' on single lines..

Here are a few examples of how the XML is formatted. All source code in the Source attributes is X++ code.

A class called 'name' that extends a class called 'base' in package 'mypackage' with methods 'P1' and 'P2' is represented like this in the XML:
<Class Name='name' Artifact='class:name' Extends='base' Package='mypackage' IsAbstract='true' IsStatic='false' IsFinal='true' Artifact='class:name' Source='class name extends base { void p1() {} void p2() {}' >
    <Method Name='P1'>...</Method>
    <Method Name='P2'>...</Method>
</Class>

A method named 'p1' returning a type 'T' is represented like this:
<Method Name='p1' Type='T' IsAbstract='true' IsStatic='false' IsFinal='true' IsPrivate='false' IsProtected='false' IsPublic='false'>
   Statement...
</Method>

Methods contain one or more Statements (described below) nested within the <Method></Method> tag. For instance, 
a method called 'MyMethod' containing a return statement would be represented like this:

<Method Name='MyMethod' IsAbstract='true' IsStatic='false' IsFinal='true' IsPrivate='false' IsProtected='false' IsPublic='false'>
   <ReturnStatement></ReturnStatement>
</Method>

These are examples of statements:
'If Statements' If statements contain a condition (the Expression, as described below) and a statement as show here: <IfStatement>Expression Statement</IfStatement>.
'Compound statements' are sequences of statements, inside <CompoundStatement> ... </CompoundStatement>.
'Return statements' are represented as <ReturnStatement> ... </ReturnStatement>, optionally including an expression.
'While statements' are represented as <WhileStatement> Expression Statement</WhileStatement> where the first child (i.e. the condition) is an expression, and the second child is a statement.
---------------
These are examples of expressions:
String literals with the value 'abcd' is represented as <StringLiteralExpression Value='abcd' />.
Integer literal with the value 123 is represented as <IntLiteralExpression Value='123'/>.

Subtractions are represented as <SubtractExpression> ... </SubtractExpression> nodes with the left and right expressions embedded.
Additions are represented as <AddExpression> ... </AddExpression> nodes with the left and right expressions embedded.
---------------

Each embedded result must contain the @Package attribute on the top level artifact (i.e. the class, or table, or query or form) in the result. 

For instance the prompt:

'Get me the methods on MyClass'

should generate:

declare option output:indent 'yes';
<Results>
{
    for $c in /Class[lower-case(@Name) = 'myclass']/Method
    return <Result Artifact='{$c/@Artifact}' Package='{$c/@Package}'> { } </Result>
}
</Results>

All queries must be case insensitive.
";

        private string systemPrompt = string.Empty;

        private ChatHistory history = null;
        private AzureOpenAIChatCompletionService chatCompletionService;

        public PromptEvaluator(string systemPrompt)
        {
            this.systemPrompt = systemPrompt;
        }

        public async Task<string> EvaluatePromptAsync(string query)
        {
            if (string.IsNullOrEmpty(query))
                return string.Empty;

            // We need the chatGPT instance and the history
            if (this.history == null)
            {
                // This will insert the system prompt into the chat history.
                this.history = new ChatHistory(this.systemPrompt);
            }

            if (chatCompletionService == null)
            {
                this.chatCompletionService = new AzureOpenAIChatCompletionService(
                    deploymentName: Secrets.AzureOpenAiModel,
                    openAIClient: Secrets.OpenAIClient.Value);
            }

            this.history.AddUserMessage(query);
            var result = await this.chatCompletionService.GetChatMessageContentAsync(this.history);

            history.Add(result);

            return result.Content;
        }
    }
}
