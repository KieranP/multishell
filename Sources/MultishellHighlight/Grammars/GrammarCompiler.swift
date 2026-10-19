import MultishellAppCore

/// How `SyntaxHighlighter` compiles a language, a test handing it one that fails.
typealias GrammarCompiler = @Sendable (HighlightLanguage) throws -> CompiledGrammar
