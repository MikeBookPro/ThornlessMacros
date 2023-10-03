import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ThornlessMacrosImpl)
import ThornlessMacrosImpl

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
    "PubliclyInitializable": PubliclyInitializableMacro.self
]
#endif

final class ThornlessMacrosTests: XCTestCase {
    func testMacro() throws {
        #if canImport(ThornlessMacrosMacros)
        assertMacroExpansion(
            """
            #stringify(a + b)
            """,
            expandedSource: """
            (a + b, "a + b")
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringLiteral() throws {
        #if canImport(ThornlessMacrosMacros)
        assertMacroExpansion(
            #"""
            #stringify("Hello, \(name)")
            """#,
            expandedSource: #"""
            ("Hello, \(name)", #""Hello, \(name)""#)
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testPubliclyInitializable_withValidStruct() throws {
        assertMacroExpansion(
        #"""
        @PubliclyInitializable
        public struct MyStruct {
            public let id: UUID
            public var name: String?
            public var age: Int = 0
        }
        """#,
        expandedSource: #"""
        public struct MyStruct {
            public let id: UUID
            public var name: String?
            public var age: Int = 0

            public init(id: UUID, name: String?, age: Int) {
                self.id = id
                self.name = name
                self.age = age
            }
        }
        """#,
        macros: testMacros
        )
    }
}
