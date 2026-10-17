import SwiftUI
import Testing
@testable import Stitch

struct SetTargetInputTests {
    // Each tuple becomes one run: (characters, modifiers, refused).
    @Test(arguments: [
        ("5", [], false),
        ("a", [], true),
        (" ", [], true),
        (",", [], true),
        ("+", [], true),
        // Shift+5 types "%": Shift alone is not a shortcut, so the character is checked.
        ("%", .shift, true),
        // Arabic-Indic one: a digit, but not ASCII.
        ("\u{0661}", [], true),
        // Paste and select all are shortcuts and must reach the field.
        ("v", .command, false),
        ("a", .command, false),
        // Keys that type no text: Delete (either code), Return, Tab, up arrow, and no characters at all.
        ("\u{7F}", [], false),
        ("\u{8}", [], false),
        ("\r", [], false),
        ("\t", [], false),
        ("\u{F700}", [], false),
        ("", [], false),
    ] as [(String, EventModifiers, Bool)])
    func keyPressFilterRefusesOnlyNonDigitText(characters: String, modifiers: EventModifiers, refused: Bool) {
        #expect(SetTargetView.refusesKeyPress(characters: characters, modifiers: modifiers) == refused)
    }
}
