package anini.aninitools.ui.sensor

import kotlin.math.*

object MusicNoteUtils {
    
    // Note names in order within an octave
    private val NOTE_NAMES = arrayOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    
    // A4 = 440 Hz is our reference note (the 9th note in the 4th octave)
    private const val A4_FREQUENCY = 440.0
    private const val A4_NOTE_NUMBER = 69 // MIDI note number for A4
    
    /**
     * Converts a frequency in Hz to the closest musical note
     * @param frequency The frequency in Hz
     * @return A NoteInfo object containing note name, octave, and tuning accuracy
     */
    fun frequencyToNote(frequency: Double): NoteInfo? {
        if (frequency <= 0) return null
        
        // Calculate the MIDI note number using the formula: n = 69 + 12 * log2(f/440)
        val noteNumber = round(69 + 12 * log2(frequency / A4_FREQUENCY)).toInt()
        
        // Calculate octave (C4 = octave 4)
        val octave = (noteNumber / 12) - 1
        
        // Get note name within the octave
        val noteIndex = noteNumber % 12
        val noteName = NOTE_NAMES[noteIndex]
        
        // Calculate the exact frequency this note should have
        val exactFrequency = A4_FREQUENCY * 2.0.pow((noteNumber - A4_NOTE_NUMBER) / 12.0)
        
        // Calculate cents deviation (100 cents = 1 semitone)
        val cents = (1200 * log2(frequency / exactFrequency)).toInt()
        
        // Determine tuning status
        val tuningStatus = when {
            abs(cents) <= 5 -> TuningStatus.IN_TUNE
            cents > 5 -> TuningStatus.SHARP
            else -> TuningStatus.FLAT
        }
        
        return NoteInfo(noteName, octave, cents, tuningStatus, exactFrequency)
    }
    
    /**
     * Formats a note for display
     * @param noteInfo The note information
     * @param showCents Whether to show cent deviation
     * @return Formatted string like "A4" or "A4 (+12¢)"
     */
    fun formatNote(noteInfo: NoteInfo, showCents: Boolean = false): String {
        val baseNote = "${noteInfo.noteName}${noteInfo.octave}"
        
        return if (showCents && noteInfo.cents != 0) {
            val centSign = if (noteInfo.cents > 0) "+" else ""
            "$baseNote ($centSign${noteInfo.cents}¢)"
        } else {
            baseNote
        }
    }
    
    /**
     * Gets a tuning indicator for the note
     * @param noteInfo The note information
     * @return A visual indicator of tuning accuracy
     */
    fun getTuningIndicator(noteInfo: NoteInfo): String {
        return when (noteInfo.tuningStatus) {
            TuningStatus.IN_TUNE -> "♪"
            TuningStatus.SHARP -> "♯"
            TuningStatus.FLAT -> "♭"
        }
    }
}

data class NoteInfo(
    val noteName: String,
    val octave: Int,
    val cents: Int,
    val tuningStatus: TuningStatus,
    val exactFrequency: Double
)

enum class TuningStatus {
    IN_TUNE,
    SHARP,
    FLAT
} 