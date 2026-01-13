import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - CategoryDefinition Basic Tests
final class CategoryDefinitionBasicTests: XCTestCase {

    func testCategoryDefinitionCreation() {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test Category",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test description",
            promptTemplate: "Test template",
            isSystem: false
        )

        XCTAssertEqual(category.id, "test")
        XCTAssertEqual(category.displayName, "Test Category")
        XCTAssertEqual(category.icon, "star")
        XCTAssertEqual(category.colorHex, "#FF0000")
        XCTAssertEqual(category.promptDescription, "Test description")
        XCTAssertEqual(category.promptTemplate, "Test template")
        XCTAssertFalse(category.isSystem)
    }

    func testCategoryDefinitionIdentifiable() {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        XCTAssertEqual(category.id, "test")
    }

    func testCategoryDefinitionEquatable() {
        let category1 = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        let category2 = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        XCTAssertEqual(category1, category2)
    }

    func testCategoryDefinitionHashable() {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        var set = Set<CategoryDefinition>()
        set.insert(category)
        XCTAssertEqual(set.count, 1)
    }

    func testCategoryDefinitionCodable() throws {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#FF0000",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(CategoryDefinition.self, from: encoded)

        XCTAssertEqual(category, decoded)
    }
}

// MARK: - CategoryDefinition Color Tests
final class CategoryDefinitionColorTests: XCTestCase {

    func testColorFromValidHex() {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "#4CD966",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        let color = category.color
        XCTAssertNotNil(color)
    }

    func testColorFromInvalidHexReturnsFallback() {
        let category = CategoryDefinition(
            id: "test",
            displayName: "Test",
            icon: "star",
            colorHex: "invalid",
            promptDescription: "Test",
            promptTemplate: "Test",
            isSystem: false
        )

        let color = category.color
        // Should return fallback gray color
        XCTAssertNotNil(color)
    }
}

// MARK: - CategoryDefinition Defaults Tests
final class CategoryDefinitionDefaultsTests: XCTestCase {

    func testDefaultsContainsSixCategories() {
        XCTAssertEqual(CategoryDefinition.defaults.count, 6)
    }

    func testDefaultCategoryIds() {
        let ids = CategoryDefinition.defaults.map { $0.id }
        XCTAssertTrue(ids.contains("terminal"))
        XCTAssertTrue(ids.contains("coding"))
        XCTAssertTrue(ids.contains("chat"))
        XCTAssertTrue(ids.contains("writing"))
        XCTAssertTrue(ids.contains("email"))
        XCTAssertTrue(ids.contains("general"))
    }

    func testDefaultCategoryDisplayNames() {
        let names = CategoryDefinition.defaults.map { $0.displayName }
        XCTAssertTrue(names.contains("Terminal"))
        XCTAssertTrue(names.contains("Coding"))
        XCTAssertTrue(names.contains("Chat"))
        XCTAssertTrue(names.contains("Writing"))
        XCTAssertTrue(names.contains("Email"))
        XCTAssertTrue(names.contains("General"))
    }

    func testAllDefaultCategoriesAreSystem() {
        for category in CategoryDefinition.defaults {
            XCTAssertTrue(category.isSystem, "\(category.displayName) should be a system category")
        }
    }

    func testAllDefaultCategoriesHaveIcons() {
        for category in CategoryDefinition.defaults {
            XCTAssertFalse(category.icon.isEmpty, "\(category.displayName) should have an icon")
        }
    }

    func testAllDefaultCategoriesHaveValidColors() {
        for category in CategoryDefinition.defaults {
            XCTAssertNotNil(Color(hex: category.colorHex), "\(category.displayName) should have a valid hex color")
        }
    }

    func testAllDefaultCategoriesHavePromptDescriptions() {
        for category in CategoryDefinition.defaults {
            XCTAssertFalse(category.promptDescription.isEmpty, "\(category.displayName) should have a prompt description")
        }
    }

    func testAllDefaultCategoriesHavePromptTemplates() {
        for category in CategoryDefinition.defaults {
            XCTAssertFalse(category.promptTemplate.isEmpty, "\(category.displayName) should have a prompt template")
        }
    }
}

// MARK: - CategoryDefinition Fallback Tests
final class CategoryDefinitionFallbackTests: XCTestCase {

    func testFallbackReturnsGeneral() {
        let fallback = CategoryDefinition.fallback
        XCTAssertEqual(fallback.id, "general")
    }

    func testFallbackIsNotNil() {
        XCTAssertNotNil(CategoryDefinition.fallback)
    }
}

// MARK: - Individual Category Tests
final class TerminalCategoryTests: XCTestCase {

    func testTerminalCategoryProperties() {
        guard let terminal = CategoryDefinition.defaults.first(where: { $0.id == "terminal" }) else {
            XCTFail("Terminal category not found")
            return
        }

        XCTAssertEqual(terminal.displayName, "Terminal")
        XCTAssertEqual(terminal.icon, "terminal")
        XCTAssertEqual(terminal.colorHex, "#4CD966")
        XCTAssertTrue(terminal.isSystem)
    }

    func testTerminalPromptContainsSudo() {
        XCTAssertTrue(CategoryDefinition.terminalPrompt.contains("sudo"))
    }

    func testTerminalPromptContainsGit() {
        XCTAssertTrue(CategoryDefinition.terminalPrompt.contains("git"))
    }

    func testTerminalPromptContainsGhostty() {
        XCTAssertTrue(CategoryDefinition.terminalPrompt.contains("Ghostty"))
    }
}

final class CodingCategoryTests: XCTestCase {

    func testCodingCategoryProperties() {
        guard let coding = CategoryDefinition.defaults.first(where: { $0.id == "coding" }) else {
            XCTFail("Coding category not found")
            return
        }

        XCTAssertEqual(coding.displayName, "Coding")
        XCTAssertEqual(coding.icon, "curlybraces")
        XCTAssertEqual(coding.colorHex, "#66A6F2")
        XCTAssertTrue(coding.isSystem)
    }

    func testCodingPromptContainsUseState() {
        XCTAssertTrue(CategoryDefinition.codingPrompt.contains("useState"))
    }

    func testCodingPromptContainsAsync() {
        XCTAssertTrue(CategoryDefinition.codingPrompt.contains("async"))
    }

    func testCodingPromptContainsCamelCase() {
        XCTAssertTrue(CategoryDefinition.codingPrompt.contains("camelCase"))
    }
}

final class ChatCategoryTests: XCTestCase {

    func testChatCategoryProperties() {
        guard let chat = CategoryDefinition.defaults.first(where: { $0.id == "chat" }) else {
            XCTFail("Chat category not found")
            return
        }

        XCTAssertEqual(chat.displayName, "Chat")
        XCTAssertEqual(chat.icon, "bubble.left.and.bubble.right")
        XCTAssertEqual(chat.colorHex, "#F3994C")
        XCTAssertTrue(chat.isSystem)
    }

    func testChatPromptContainsLol() {
        XCTAssertTrue(CategoryDefinition.chatPrompt.contains("lol"))
    }

    func testChatPromptContainsEmoji() {
        XCTAssertTrue(CategoryDefinition.chatPrompt.contains("emoji"))
    }
}

final class WritingCategoryTests: XCTestCase {

    func testWritingCategoryProperties() {
        guard let writing = CategoryDefinition.defaults.first(where: { $0.id == "writing" }) else {
            XCTFail("Writing category not found")
            return
        }

        XCTAssertEqual(writing.displayName, "Writing")
        XCTAssertEqual(writing.icon, "doc.text")
        XCTAssertEqual(writing.colorHex, "#A685D8")
        XCTAssertTrue(writing.isSystem)
    }

    func testWritingPromptContainsFormalTone() {
        XCTAssertTrue(CategoryDefinition.writingPrompt.contains("formal"))
    }
}

final class EmailCategoryTests: XCTestCase {

    func testEmailCategoryProperties() {
        guard let email = CategoryDefinition.defaults.first(where: { $0.id == "email" }) else {
            XCTFail("Email category not found")
            return
        }

        XCTAssertEqual(email.displayName, "Email")
        XCTAssertEqual(email.icon, "envelope")
        XCTAssertEqual(email.colorHex, "#D96F8C")
        XCTAssertTrue(email.isSystem)
    }

    func testEmailPromptContainsGreetings() {
        XCTAssertTrue(CategoryDefinition.emailPrompt.contains("greetings"))
    }

    func testEmailPromptContainsSignOffs() {
        XCTAssertTrue(CategoryDefinition.emailPrompt.contains("sign-offs"))
    }
}

final class GeneralCategoryTests: XCTestCase {

    func testGeneralCategoryProperties() {
        guard let general = CategoryDefinition.defaults.first(where: { $0.id == "general" }) else {
            XCTFail("General category not found")
            return
        }

        XCTAssertEqual(general.displayName, "General")
        XCTAssertEqual(general.icon, "square.grid.2x2")
        XCTAssertEqual(general.colorHex, "#33D9D9")
        XCTAssertTrue(general.isSystem)
    }

    func testGeneralPromptAdaptsToContext() {
        XCTAssertTrue(CategoryDefinition.generalPrompt.contains("context"))
    }
}

// MARK: - Prompt Template Tests
final class PromptTemplateTests: XCTestCase {

    func testAllPromptsContainFillerWordRemoval() {
        let prompts = [
            CategoryDefinition.terminalPrompt,
            CategoryDefinition.codingPrompt,
            CategoryDefinition.chatPrompt,
            CategoryDefinition.writingPrompt,
            CategoryDefinition.emailPrompt,
            CategoryDefinition.generalPrompt,
        ]

        for prompt in prompts {
            XCTAssertTrue(prompt.contains("filler") || prompt.contains("um") || prompt.contains("uh"),
                          "Prompt should mention filler word handling")
        }
    }

    func testAllPromptsContainTypoFix() {
        let prompts = [
            CategoryDefinition.terminalPrompt,
            CategoryDefinition.codingPrompt,
            CategoryDefinition.chatPrompt,
            CategoryDefinition.writingPrompt,
            CategoryDefinition.emailPrompt,
            CategoryDefinition.generalPrompt,
        ]

        for prompt in prompts {
            XCTAssertTrue(prompt.lowercased().contains("typo") || prompt.lowercased().contains("fix"),
                          "Prompt should mention typo fixing")
        }
    }

    func testAllPromptsPreserveOriginalIntent() {
        let prompts = [
            CategoryDefinition.terminalPrompt,
            CategoryDefinition.codingPrompt,
            CategoryDefinition.chatPrompt,
            CategoryDefinition.writingPrompt,
            CategoryDefinition.emailPrompt,
            CategoryDefinition.generalPrompt,
        ]

        for prompt in prompts {
            XCTAssertTrue(prompt.contains("intent") || prompt.contains("original"),
                          "Prompt should mention preserving intent")
        }
    }

    func testAllPromptsEndWithOutputInstruction() {
        let prompts = [
            CategoryDefinition.terminalPrompt,
            CategoryDefinition.codingPrompt,
            CategoryDefinition.chatPrompt,
            CategoryDefinition.writingPrompt,
            CategoryDefinition.emailPrompt,
            CategoryDefinition.generalPrompt,
        ]

        for prompt in prompts {
            XCTAssertTrue(prompt.contains("Output only the corrected text"),
                          "Prompt should end with output instruction")
        }
    }
}
