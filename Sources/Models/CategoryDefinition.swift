import SwiftUI

internal struct CategoryDefinition: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var displayName: String
    var icon: String
    var colorHex: String
    var promptDescription: String
    var promptTemplate: String
    var isSystem: Bool

    var color: Color {
        Color(hex: colorHex) ?? Color(red: 0.3, green: 0.3, blue: 0.3)
    }

    static let defaults: [CategoryDefinition] = [
        CategoryDefinition(
            id: "terminal",
            displayName: "Terminal",
            icon: "terminal",
            colorHex: "#4CD966",
            promptDescription: "Preserves CLI terms, flags, paths. Fixes: 'suit oh' → 'sudo', 'see dee' → 'cd'",
            promptTemplate: Self.terminalPrompt,
            isSystem: true
        ),
        CategoryDefinition(
            id: "coding",
            displayName: "Coding",
            icon: "curlybraces",
            colorHex: "#66A6F2",
            promptDescription: "Preserves syntax, naming conventions. Fixes: 'you state' → 'useState', 'a sink' → 'async'",
            promptTemplate: Self.codingPrompt,
            isSystem: true
        ),
        CategoryDefinition(
            id: "chat",
            displayName: "Chat",
            icon: "bubble.left.and.bubble.right",
            colorHex: "#F3994C",
            promptDescription: "Light corrections, keeps casual tone. Preserves slang, emoji refs, abbreviations",
            promptTemplate: Self.chatPrompt,
            isSystem: true
        ),
        CategoryDefinition(
            id: "writing",
            displayName: "Writing",
            icon: "doc.text",
            colorHex: "#A685D8",
            promptDescription: "Thorough grammar, formal style. Fixes fragments and homophones",
            promptTemplate: Self.writingPrompt,
            isSystem: true
        ),
        CategoryDefinition(
            id: "email",
            displayName: "Email",
            icon: "envelope",
            colorHex: "#D96F8C",
            promptDescription: "Professional tone, preserves greetings/sign-offs. Fixes: 'attach meant' → 'attachment'",
            promptTemplate: Self.emailPrompt,
            isSystem: true
        ),
        CategoryDefinition(
            id: "general",
            displayName: "General",
            icon: "square.grid.2x2",
            colorHex: "#33D9D9",
            promptDescription: "Balanced cleanup, adapts to context. Fixes common misrecognitions",
            promptTemplate: Self.generalPrompt,
            isSystem: true
        )
    ]

    static var fallback: CategoryDefinition {
        defaults.last!
    }
}

internal extension CategoryDefinition {
    static let terminalPrompt = """
            Clean up this speech transcription for a terminal/command-line context.
            - Fix typos, grammar, and punctuation while preserving command structure
            - Remove filler words (um, uh, like, you know)
            - Preserve technical terms: CLI, sudo, grep, awk, sed, bash, zsh, tmux, vim, git, ssh, curl, wget, ls, cd, rm, mkdir, echo, apt, brew
            - Preserve app names: Ghostty, iTerm, Kitty, Wezterm, Hyper
            - Preserve flags, paths, syntax, and multi-line elements (e.g., -v, --verbose, ~/Documents, |, >, &&, $VAR, \\ for line continuation)
            - Infer and correct common homophones, misrecognitions, or fragments based on context (e.g., 'eye term' -> 'iTerm', 'suit oh' -> 'sudo', 'see dee' -> 'cd', incomplete 'pipe to' -> '|')
            - Handle fragmented sentences by connecting logically without adding content
            - Do not add or invent commands; keep original intent
            Output only the corrected text.
            """

    static let codingPrompt = """
            Clean up this speech transcription for a coding/programming context.
            - Fix typos, grammar, and punctuation while preserving code integrity
            - Remove filler words (um, uh, like, you know)
            - Preserve programming terms: function, class, method, variable, const, let, var, async, await, if, for, while, return, import, export
            - Preserve naming conventions: camelCase, snake_case, PascalCase, kebab-case
            - Preserve common abbreviations: API, SDK, CLI, UI, UX, JSON, XML, SQL, HTTP, REST, GraphQL
            - Preserve code-related words, symbols, and blocks intact (e.g., useState, onClick, handleSubmit, ==, !=, +=, ```code blocks```, // comments)
            - Infer and correct common homophones, misrecognitions, or fragments based on context (e.g., 'you state' -> 'useState', 'a sink' -> 'async', 'four loop' -> 'for loop')
            - Handle mixed code and prose by separating logically if fragmented
            - Do not add or invent code; keep original intent
            Output only the corrected text.
            """

    static let chatPrompt = """
            Clean up this speech transcription for a chat/messaging context like Slack.
            - Fix obvious typos and unclear words
            - Light punctuation cleanup
            - Remove excessive filler words but keep casual tone and rhythm
            - Preserve informal language, expressions, slang, abbreviations, and tone (e.g., lol, brb, btw, imo, sarcasm like "sure thing /s")
            - Preserve emoji references (e.g., "smiley face", "thumbs up")
            - Infer and correct common homophones, misrecognitions, or fragments based on context (e.g., 'wreck' -> 'rec' for recommendation, 'you are ell' -> 'URL')
            - Handle short, fragmented messages by keeping them concise
            - Do not add or invent content; maintain original casual intent
            Output only the corrected text.
            """

    static let writingPrompt = """
            Clean up this speech transcription for formal writing or notes.
            - Fix typos, grammar, and punctuation thoroughly
            - Remove all filler words (um, uh, like, you know, basically, actually)
            - Improve sentence structure for clarity, flow, and completeness if fragmented
            - Ensure proper capitalization and formal tone where appropriate
            - Infer and correct common homophones, misrecognitions, or fragments based on context (e.g., 'there' -> 'their', 'right a function' -> 'write a function')
            - Keep phrasing close to original without changing meaning
            - Do not add or invent ideas; keep original intent
            Output only the corrected text.
            """

    static let emailPrompt = """
            Clean up this speech transcription for email composition.
            - Fix typos, grammar, and punctuation for professional tone
            - Remove filler words (um, uh, like, you know)
            - Preserve key elements: greetings (e.g., Hi [Name]), sign-offs (e.g., Best regards), attachments mentions
            - Improve sentence structure for politeness and clarity if needed
            - Infer and correct common homophones or misrecognitions based on context (e.g., 'sand' -> 'send', 'attach meant' -> 'attachment')
            - Handle fragmented thoughts by forming coherent paragraphs
            - Do not add or invent content; keep original intent
            Output only the corrected text.
            """

    static let generalPrompt = """
            Clean up this speech transcription for general use.
            - Fix typos, grammar, and punctuation appropriately
            - Remove filler words (um, uh, like, you know)
            - Preserve any technical or informal terms based on context
            - Infer and correct common homophones or misrecognitions (e.g., 'weather' -> 'whether')
            - Handle fragments by connecting logically without adding content
            - Adapt tone to inferred context (casual or formal)
            - Do not add or invent ideas; keep original intent
            Output only the corrected text.
            """
}
