package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Test

class TranscriptTextTest {
    @Test fun appendsRecognitionWithoutLeadingWhitespace() {
        assertEquals("First phrase second phrase", appendTranscript(" First phrase ", " second phrase "))
    }

    @Test fun emptyRecognitionDoesNotAlterTranscript() {
        assertEquals("Existing words", appendTranscript("Existing words", "  "))
    }

    @Test fun insertsSpacingAtExistingWordBoundary() {
        assertEquals(" dictated", appendDictationSpacing("word", "dictated"))
    }

    @Test fun preservesExistingWhitespaceAndLeadingDictatedWhitespace() {
        assertEquals("dictated", appendDictationSpacing("word ", "dictated"))
        assertEquals(" dictated", appendDictationSpacing("word", " dictated"))
    }

    @Test fun separatesDictationFromExistingWordAfterCursor() {
        assertEquals(" dictated ", appendDictationSpacing("word", "dictated", "next"))
    }

    @Test fun doesNotInsertSpaceBeforePunctuationAfterCursor() {
        assertEquals(" dictated", appendDictationSpacing("word", "dictated", "."))
    }
}
