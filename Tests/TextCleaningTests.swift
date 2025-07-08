import XCTest
@testable import AudioWhisper

final class TextCleaningTests: XCTestCase {
    
    func testBracketedMarkerRemoval() {
        let testCases = [
            ("[BLANK_AUDIO]", ""),
            ("[blank_audio]", ""),
            ("[BLANK AUDIO]", ""),
            ("[blank audio]", ""),
            ("[NO_AUDIO]", ""),
            ("[no_audio]", ""),
            ("[NO AUDIO]", ""),
            ("[no audio]", ""),
            ("[SILENCE]", ""),
            ("[silence]", ""),
            ("[EMPTY]", ""),
            ("[empty]", ""),
            ("[Music]", ""),
            ("[music]", ""),
            ("[MUSIC]", ""),
            ("[Background noise]", ""),
            ("[background noise]", ""),
            ("[BACKGROUND NOISE]", ""),
            ("[Inaudible]", ""),
            ("[inaudible]", ""),
            ("[INAUDIBLE]", ""),
            ("[laughter]", ""),
            ("[applause]", ""),
            ("[coughing]", ""),
            ("[door closing]", ""),
            ("[phone ringing]", "")
        ]
        
        for (input, expected) in testCases {
            let result = SpeechToTextService.cleanTranscriptionText(input)
            XCTAssertEqual(result, expected, "Failed to clean: \(input)")
        }
    }
    
    func testParentheticalMarkerRemoval() {
        let testCases = [
            ("(crying)", ""),
            ("(laughing)", ""),
            ("(applause)", ""),
            ("(background noise)", ""),
            ("(inaudible)", ""),
            ("(music)", ""),
            ("(coughing)", ""),
            ("(door slamming)", ""),
            ("(phone ringing)", ""),
            ("(sighs)", ""),
            ("(whispers)", ""),
            ("(shouting)", "")
        ]
        
        for (input, expected) in testCases {
            let result = SpeechToTextService.cleanTranscriptionText(input)
            XCTAssertEqual(result, expected, "Failed to clean: \(input)")
        }
    }
    
    func testMixedContentCleaning() {
        let input = "Hello [BLANK_AUDIO] world [Music] this is a test [SILENCE] and (crying) more text (applause)"
        let expected = "Hello world this is a test and more text"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testMixedBracketsAndParentheses() {
        let input = "The speaker said [laughter] hello there (coughing) and then continued [background music] talking (whispers)"
        let expected = "The speaker said hello there and then continued talking"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testWhitespaceNormalization() {
        let input = "  Hello    world   with   extra   spaces  "
        let expected = "Hello world with extra spaces"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testValidTextPreservation() {
        let input = "This is valid transcription text that should remain unchanged."
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, input)
    }
    
    func testEmptyStringHandling() {
        let input = ""
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "")
    }
    
    func testOnlyMarkersString() {
        let input = "[BLANK_AUDIO] [SILENCE] [Music] (crying) (applause)"
        let expected = ""
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testNestedMarkersHandling() {
        // Test that nested brackets/parentheses are properly handled with iterative approach
        let input = "Hello [some [nested] content] world (and (nested) parens) text"
        let expected = "Hello world text"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testEmptyMarkersHandling() {
        let input = "Hello [] world () text"
        let expected = "Hello world text"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testPreserveValidParenthesesAndBrackets() {
        // Test that we preserve parentheses and brackets that are part of actual content
        // Note: This is a limitation of the generic approach - it will remove ALL bracketed/parenthetical content
        let input = "The formula is (x + y) and the array is [1, 2, 3]"
        let expected = "The formula is and the array is"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
        
        // This test documents the current behavior - we might want to make this more sophisticated later
    }
    
    func testDeeplyNestedMarkers() {
        let input = "Text [outer [middle [inner] middle] outer] more text"
        let expected = "Text more text"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testMixedNestedMarkers() {
        let input = "Start [bracket (paren inside bracket) bracket] and (paren [bracket inside paren] paren) end"
        let expected = "Start and end"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testRealWorldExample() {
        let input = "So I was thinking [laughter] about this problem (coughing) and then [background music] I realized [applause] the solution was simple (whispers)"
        let expected = "So I was thinking about this problem and then I realized the solution was simple"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, expected)
    }
    
    func testPerformance() {
        let longText = String(repeating: "Hello [BLANK_AUDIO] world [Music] and (crying) text (applause) ", count: 1000)
        
        measure {
            _ = SpeechToTextService.cleanTranscriptionText(longText)
        }
    }
}