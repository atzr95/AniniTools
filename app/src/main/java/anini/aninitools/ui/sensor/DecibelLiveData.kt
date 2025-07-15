package anini.aninitools.ui.sensor

import androidx.lifecycle.LiveData
import anini.aninitools.ui.sensor.AudioSource.AudioReceiver
import anini.aninitools.ui.sensor.AudioSource.SAMPLE_RATE_IN_HZ
import java.util.*
import kotlin.math.abs

class DecibelLiveData : LiveData<List<Any>>() {

    private val audioSource = AudioSource()
    private var audiofreqReceiver: AudioReceiver? = null
    private var calibratedDecibels: Double = 0.0
    private var calibratedFrequency: Double = 0.0


    override fun onActive() {
        super.onActive()

        audiofreqReceiver = object : AudioReceiver {
            private val audioAnalyzer: AudioAnalyzer = AudioAnalyzer(SAMPLE_RATE_IN_HZ)
            private val audioAnalyzerBuffer = ShortArray(AudioAnalyzer.BUFFER_SIZE)
            private var audioAnalyzerBufferOffset = 0
            private var previousFrequency: Double? = null

            override fun onReceiveAudio(audioSourceBuffer: ShortArray) {
                var audioSourceBufferOffset = 0

                val uncalibratedDecibels = SoundUtils.calculateUncalibratedDecibels(
                    audioSourceBuffer,
                    audioSourceBuffer.size
                )
                if (isValidReading(uncalibratedDecibels)) {
                    calibratedDecibels = uncalibratedDecibels
                }

                while (audioSourceBufferOffset < audioSourceBuffer.size) { // Repeat the previous frequency value while we collect and analyze new data.
                    if (previousFrequency != null) {
                        calibratedFrequency = previousFrequency as Double
                    }

                    val lengthToCopy =
                        (audioSourceBuffer.size - audioSourceBufferOffset).coerceAtMost(
                            audioAnalyzerBuffer.size - audioAnalyzerBufferOffset
                        )

                    System.arraycopy(
                        audioSourceBuffer,
                        audioSourceBufferOffset,
                        audioAnalyzerBuffer,
                        audioAnalyzerBufferOffset,
                        lengthToCopy
                    )
                    audioAnalyzerBufferOffset += lengthToCopy
                    audioSourceBufferOffset += lengthToCopy

                    // If audioAnalyzerBuffer is full, analyze it.

                    if (audioAnalyzerBufferOffset == audioAnalyzerBuffer.size) {
                        var frequency: Double? =
                            audioAnalyzer.detectFundamentalFrequency(audioAnalyzerBuffer)

                        if (frequency == null) { // Unable to detect frequency, likely due to low volume.
                            calibratedFrequency = 0.0
                        } else if (isDrasticSpike(frequency)) {
                            // Avoid drastic changes that show as spikes in the graph between notes
                            // being played on an instrument. If the new value is more than 50%
                            // different from the previous value, skip it.
                            // Note that since we set previousFrequency to frequency below, we
                            // will never skip two consecutive values.
                            frequency = null
                        } else {
                            calibratedFrequency = frequency
                        }
                        previousFrequency = frequency
                        // Since we've analyzed that buffer, set the offset back to 0.
                        audioAnalyzerBufferOffset = 0
                    }
                }
            }

            private fun isDrasticSpike(frequency: Double): Boolean {
                return (previousFrequency != null && abs(frequency - previousFrequency!!) / previousFrequency!! > 0.50)
            }
        }

        audioSource.registerAudioReceiver(audiofreqReceiver)


        // Update the elapsed time every second.
        Timer().schedule(object : TimerTask() {
            override fun run() {
                val noteInfo = if (calibratedFrequency > 0) {
                    MusicNoteUtils.frequencyToNote(calibratedFrequency)
                } else null
                postValue(listOf(calibratedDecibels, calibratedFrequency, noteInfo) as List<Any>?)
            }
        }, 1, 550)


    }

    override fun onInactive() {
        super.onInactive()
        audioSource.unregisterAudioReceiver(audiofreqReceiver)
    }

    private fun isValidReading(reading: Double): Boolean {
        return reading > -Double.MAX_VALUE
    }
}