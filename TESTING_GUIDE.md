# Talkies Windows - Testing Guide for Display Fixes

## Overview

This guide provides detailed test cases for verifying that the waveform visualizer and live transcript display are working correctly.

## Test Environment Setup

### Prerequisites
- Windows 10 or Windows 11
- .NET 8.0 runtime
- Working microphone
- Talkies Windows application built and ready to run
- Whisper.net model downloaded (ggml-base.bin minimum)

### Starting the Application
```bash
cd talkies/talkies_windows/talkies.windows
dotnet run
```

---

## Feature 1: Waveform Visualizer Tests

### Test 1.1: Waveform Appears on Startup
**Objective**: Verify the waveform control loads and is visible

**Steps**:
1. Launch the Talkies Windows application
2. Look at the left sidebar under "Audio Input" section

**Expected Result**: 
- A dark rectangular area (60px height) appears below "Audio Input" label
- The area should have a subtle border
- Background should be dark (#1a1a1a)

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**: 
- If no area appears, check that `WaveformVisualizer.xaml` is properly compiled
- Verify the namespace mapping in MainWindow.xaml is correct: `xmlns:local="clr-namespace:Talkies.Windows.Controls"`

---

### Test 1.2: Waveform Updates During Recording - Quiet Audio
**Objective**: Verify waveform responds to quiet audio input

**Steps**:
1. Click "Start Recording"
2. Speak very quietly into the microphone
3. Observe the waveform area for 5 seconds
4. Click "Stop Recording"

**Expected Result**:
- Small blue/cyan bars appear briefly while speaking
- Bars are short height (reflecting low audio level)
- Bars animate from right to left as time progresses
- No bars appear during silence

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- If no bars appear, check microphone volume settings
- Test with microphone sensitivity at normal level (50-75%)

---

### Test 1.3: Waveform Updates During Recording - Normal Audio
**Objective**: Verify waveform responds to normal speech audio

**Steps**:
1. Click "Start Recording"
2. Speak at normal volume into the microphone
3. Observe the waveform for 10 seconds
4. Click "Stop Recording"

**Expected Result**:
- Animated blue/cyan bars appear during speech
- Bars have medium height (reflecting normal audio level)
- Bars smoothly animate left and fade out
- Gradient effect visible (darker on left, brighter on right)
- Opacity gradually increases from left to right

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Normal speech volume should reach 50-70% of waveform height
- Look for smooth animation without flicker

---

### Test 1.4: Waveform Updates During Recording - Loud Audio
**Objective**: Verify waveform responds to loud audio input

**Steps**:
1. Click "Start Recording"
2. Speak very loudly or create loud noise near microphone
3. Observe the waveform for 5 seconds
4. Click "Stop Recording"

**Expected Result**:
- Tall blue/cyan bars appear (nearly full height of waveform area)
- Bars reach 80-90% of available height
- Gradient effect is most vibrant with tall bars
- Waveform clears after stop recording

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Very loud audio should approach but not exceed 100% height
- If bars seem cut off, verify canvas height calculation

---

### Test 1.5: Waveform Clears After Stop Recording
**Objective**: Verify waveform clears when recording stops

**Steps**:
1. Start recording and speak for a few seconds
2. Stop recording
3. Observe the waveform area
4. Wait 2 seconds

**Expected Result**:
- Bars gradually disappear as they age
- Waveform area becomes empty after ~1-2 seconds
- No artifacts or ghost bars remain

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- The audio level queue should clear naturally as old levels age out

---

### Test 1.6: Waveform Resizes with Window
**Objective**: Verify waveform adapts to window resizing

**Steps**:
1. Start recording and speak
2. While recording, resize the window:
   - Drag right edge to make wider
   - Drag right edge to make narrower
   - Maximize window
   - Restore window
3. Stop recording

**Expected Result**:
- Waveform bars adjust width smoothly
- More bars visible when wider
- Fewer bars visible when narrower
- No crashes or visual glitches
- Bars continue updating during resize

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- This tests the `SizeChanged` event handler
- Waveform should remain fluid and responsive

---

## Feature 2: Live Transcript Display Tests

### Test 2.1: Transcript Section Appears
**Objective**: Verify transcript area is visible on startup

**Steps**:
1. Launch the application
2. Look at the right side of the window

**Expected Result**:
- A large panel appears with "Live Transcript" header
- Below header are export buttons: "Export SRT", "Export TXT", "Export VTT"
- Large dark area below buttons (for transcript content)

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Transcript area should occupy the right half of the window
- Should have dark background (#252525)

---

### Test 2.2: Single Segment Appears After Transcription
**Objective**: Verify transcript displays correctly for short recording

**Steps**:
1. Click "Start Recording"
2. Say one sentence: "The quick brown fox jumps over the lazy dog"
3. Click "Stop Recording"
4. Wait for transcription to complete (may take 10-30 seconds)
5. Observe the transcript area

**Expected Result**:
- One segment box appears with:
  - Blue timestamp on left (e.g., "00:00:00.000")
  - White text on right showing the transcribed sentence
  - Dark background for the segment
  - 12px padding inside the segment
  - 8px bottom margin between segments

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Timestamp format: `HH:MM:SS.mmm`
- Text should be the actual transcribed content
- Segment should have rounded corners

---

### Test 2.3: Multiple Segments Appear
**Objective**: Verify transcript displays multiple segments correctly

**Steps**:
1. Click "Start Recording"
2. Say: "Hello world" (pause 1 second)
3. Say: "This is a test" (pause 1 second)
4. Say: "Of the transcript display" 
5. Click "Stop Recording"
6. Wait for transcription to complete

**Expected Result**:
- Multiple segments appear, one per phrase
- Each segment shows:
  - Timestamp increasing from left to right
  - Correct text for each phrase
  - Proper white color for all text
  - Even spacing between segments (8px bottom margin)
- Segments stack vertically from top to bottom
- No overlapping text

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Whisper.net may group phrases differently than expected
- All text should be clearly readable on dark background

---

### Test 2.4: Transcript Scrolling
**Objective**: Verify transcript can be scrolled when content exceeds visible area

**Steps**:
1. Record a long speech: ~2-3 minutes continuous talking
2. Wait for transcription to complete
3. Scroll inside the transcript area:
   - Scroll up to see earlier segments
   - Scroll down to see later segments
   - Scroll to bottom

**Expected Result**:
- Vertical scrollbar appears on the right side
- All segments are accessible by scrolling
- Scrolling is smooth and responsive
- Text remains readable while scrolling
- Timestamps are always visible

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Horizontal scrolling should be disabled
- ScrollViewer should auto-show vertical scrollbar when needed

---

### Test 2.5: Transcript Text Wrapping
**Objective**: Verify long text lines wrap properly

**Steps**:
1. Record a very long sentence without pauses: "This is a very long sentence that contains many words and should wrap across multiple lines in the transcript display when the text exceeds the available width"
2. Wait for transcription
3. Observe the transcript segment

**Expected Result**:
- Text wraps to multiple lines within the segment
- All text is visible (none cut off)
- Line spacing is consistent (18px line height)
- Text remains aligned to the left within the text column

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- TextWrapping should be set to "Wrap" in XAML
- LineHeight should maintain readability

---

### Test 2.6: Clear Command Clears Transcript
**Objective**: Verify Clear button removes all transcript content

**Steps**:
1. Record and transcribe something
2. Verify transcript appears
3. Click "Clear" button in left sidebar
4. Observe transcript area

**Expected Result**:
- All segment boxes disappear from transcript area
- Transcript area is now empty (except for scrollbars if visible)
- Export buttons become disabled (grayed out)
- No artifacts or ghost segments remain

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Clear should only be enabled when `CanSave` is true
- This tests the `Clear()` command in MainViewModel

---

## Feature 3: Integration Tests

### Test 3.1: Waveform and Transcript Together
**Objective**: Verify both features work simultaneously

**Steps**:
1. Click "Start Recording"
2. While recording, observe both:
   - Waveform bars animating on the left
   - (wait for later to see transcript)
3. Speak normally for 10-15 seconds
4. Stop Recording
5. Wait for transcription
6. Verify transcript appears with waveform history visible

**Expected Result**:
- Waveform animates smoothly during recording
- No lag or stuttering while waveform updates
- Transcript appears correctly after transcription completes
- Both features work without interfering with each other

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- This is the primary use case
- Monitor CPU usage to ensure waveform isn't causing bottlenecks

---

### Test 3.2: Export Functions with Populated Transcript
**Objective**: Verify export buttons work with transcript data

**Steps**:
1. Record and transcribe something short (2-3 sentences)
2. Verify transcript appears
3. Click "Export SRT" button
4. Choose a location and verify file is created
5. Open the file and verify format

**Expected Result**:
- File dialog appears asking for save location
- File is created with `.srt` extension
- Format is valid SubRip (includes sequence numbers, timestamps, text)
- All segments are included in export

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- SRT format: `1\n00:00:00,000 --> 00:00:05,000\nText content\n`
- Repeat test for "Export TXT" and "Export VTT"

---

### Test 3.3: Different Microphones
**Objective**: Verify waveform and transcript work with different microphones

**Steps**:
1. In left sidebar, select a different microphone from the dropdown
2. Record something
3. Observe waveform and transcript

**Expected Result**:
- Waveform animates with the selected microphone's input
- Transcript transcribes audio from selected microphone correctly
- No crashes when switching microphones
- Audio levels reflect the selected microphone's gain

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Test with at least 2 different microphone inputs if available
- This verifies the microphone selection works end-to-end

---

### Test 3.4: Different Languages
**Objective**: Verify transcript displays correctly for different languages

**Steps**:
1. Select "Spanish" (or another language) from Language dropdown
2. Record a Spanish phrase: "Hola, ¿cómo estás?"
3. Wait for transcription
4. Observe transcript

**Expected Result**:
- Transcript appears with Spanish text
- Special characters (á, é, í, ó, ú, ñ, etc.) display correctly
- Text is white and readable
- Timestamp is correct

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Test at least 1-2 non-English languages
- Verifies UTF-8 text handling in UI

---

### Test 3.5: Window Resize - Full Integration
**Objective**: Verify both features adapt to window resize

**Steps**:
1. Start recording and speak
2. While waveform is animating:
   - Drag window edge to make narrower (400px width minimum)
   - Drag window edge to make wider (1200px)
   - Drag top/bottom edges
3. Stop recording
4. Resize again while transcript displays

**Expected Result**:
- Waveform continues animating smoothly during resize
- Waveform bars adjust count based on available width
- Transcript reflows to new width
- All text remains visible and readable
- No crashes or visual glitches

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Window has minimum width of 900px and height of 600px
- Both features should respect these constraints

---

## Regression Tests

### Test R.1: Settings Persistence
**Objective**: Verify app saves and loads settings

**Steps**:
1. Change model to "small"
2. Change language to "Spanish"
3. Enable LLM Enhancement
4. Close the application
5. Reopen the application
6. Check the settings

**Expected Result**:
- All settings are preserved from previous session
- Model remains "small"
- Language remains "Spanish"
- LLM Enhancement is still enabled

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Settings are stored in `AppData` or local JSON file
- This ensures settings don't interfere with display fixes

---

### Test R.2: Recording Functionality
**Objective**: Verify basic recording still works

**Steps**:
1. Click "Start Recording"
2. Speak for a few seconds
3. Click "Stop Recording"
4. Wait for transcription

**Expected Result**:
- "Start Recording" button is disabled while recording
- "Stop Recording" button is enabled while recording
- Buttons swap state correctly
- Transcription initiates and completes
- No errors in logs

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Check Logger output for any errors
- This is the core functionality

---

## Performance Tests

### Test P.1: Long Recording Waveform Performance
**Objective**: Verify waveform doesn't cause lag during long recording

**Steps**:
1. Open Task Manager and monitor CPU usage
2. Click "Start Recording"
3. Let it record for 1 minute while speaking periodically
4. Observe waveform animation smoothness
5. Check CPU usage

**Expected Result**:
- Waveform updates smoothly without stuttering
- CPU usage from waveform stays below 10%
- Memory usage is stable (no leaks)
- No lag in UI responsiveness

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- On slower machines, may see CPU peaks up to 15% during waveform updates
- If CPU is high, waveform throttling may be needed (update in TODO)

---

### Test P.2: Large Transcript Performance
**Objective**: Verify transcript display handles large content

**Steps**:
1. Record a long audio (5+ minutes)
2. Wait for transcription to complete
3. Scroll through transcript smoothly
4. Monitor CPU usage

**Expected Result**:
- Transcript displays all segments
- Scrolling is smooth and responsive
- No significant CPU spike
- Memory usage is reasonable (< 100MB for 5min recording)

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
- Large transcripts (1000+ segments) may benefit from `VirtualizingStackPanel`
- Current implementation should handle normal use cases (< 500 segments)

---

## Summary Test Report

| Feature | Test Case | Result | Notes |
|---------|-----------|--------|-------|
| Waveform | 1.1 Appears on startup | ☐ Pass ☐ Fail | |
| Waveform | 1.2 Quiet audio | ☐ Pass ☐ Fail | |
| Waveform | 1.3 Normal audio | ☐ Pass ☐ Fail | |
| Waveform | 1.4 Loud audio | ☐ Pass ☐ Fail | |
| Waveform | 1.5 Clears after stop | ☐ Pass ☐ Fail | |
| Waveform | 1.6 Resizes with window | ☐ Pass ☐ Fail | |
| Transcript | 2.1 Section appears | ☐ Pass ☐ Fail | |
| Transcript | 2.2 Single segment | ☐ Pass ☐ Fail | |
| Transcript | 2.3 Multiple segments | ☐ Pass ☐ Fail | |
| Transcript | 2.4 Scrolling | ☐ Pass ☐ Fail | |
| Transcript | 2.5 Text wrapping | ☐ Pass ☐ Fail | |
| Transcript | 2.6 Clear command | ☐ Pass ☐ Fail | |
| Integration | 3.1 Together | ☐ Pass ☐ Fail | |
| Integration | 3.2 Export functions | ☐ Pass ☐ Fail | |
| Integration | 3.3 Different microphones | ☐ Pass ☐ Fail | |
| Integration | 3.4 Different languages | ☐ Pass ☐ Fail | |
| Integration | 3.5 Window resize | ☐ Pass ☐ Fail | |
| Regression | R.1 Settings | ☐ Pass ☐ Fail | |
| Regression | R.2 Recording | ☐ Pass ☐ Fail | |
| Performance | P.1 Waveform | ☐ Pass ☐ Fail | |
| Performance | P.2 Transcript | ☐ Pass ☐ Fail | |

**Overall Result**: ☐ All Pass ☐ Some Failures ☐ Critical Issues

**Sign-off**: __________________ Date: __________

**Tester Notes**:
```
