import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct PubliclyInitializableMacro: MemberMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }
        
        // TODO: (2023-10-04) Add comiler warnings if there are public variables that don't explicitly define it's type.

        let varBindings = structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .flatMap(\.bindings)
            .compactMap { $0.as(PatternBindingSyntax.self) }
        let parameterList = varBindings.reduce(into: FunctionParameterListSyntax()) { partialResult, varBinding in
            guard let paramSyntax = makeFunctionParameter(fromVariable: varBinding, isLastParameter: partialResult.count == varBindings.count - 1) else { return }
            partialResult.append(paramSyntax)
        }
        let codeBlockItems = varBindings
            .compactMap { $0.pattern.as(IdentifierPatternSyntax.self) }
            .reduce(into: CodeBlockItemListSyntax()) { partialResult, identifierPatter in
                guard let codeBlock = makeCodeBlockItem(fromIdentifier: identifierPatter) else { return }
                partialResult.append(codeBlock)
            }
        let initializerDecl = InitializerDeclSyntax(
            leadingTrivia: .newlines(2),
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(parameters: parameterList.trimmed)
            ),
            body: CodeBlockSyntax(statements: codeBlockItems)
        )
        return [DeclSyntax(initializerDecl)]
    }

    private static func makeFunctionParameter(fromVariable patternBinding: PatternBindingSyntax, isLastParameter: Bool) -> FunctionParameterSyntax? {
        guard 
            let nameToken = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let typeSyntax = patternBinding.typeAnnotation?.as(TypeAnnotationSyntax.self)?.type
        else { return nil }

        return FunctionParameterSyntax(
            firstName: nameToken,
            type: typeSyntax,
            trailingComma: isLastParameter ? .none : .commaToken()
        )
    }

    private static func makeCodeBlockItem(fromIdentifier patternSyntax: IdentifierPatternSyntax) -> CodeBlockItemSyntax? {
        let seqExpr = SequenceExprSyntax {
            ExprListSyntax {
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.`self`)),
                    period: .periodToken(),
                    name: patternSyntax.identifier,
                    trailingTrivia: .space
                )

                AssignmentExprSyntax()

                DeclReferenceExprSyntax(
                    leadingTrivia: .space,
                    baseName: patternSyntax.identifier
                )
            }
        }

        return CodeBlockItemSyntax(
            item: CodeBlockItemSyntax.Item(seqExpr),
            trailingTrivia: .newline
        ).trimmed
    }
}
