package com.sidescreen.app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

class AudioPlayer {
    private var audioTrack: AudioTrack? = null
    @Volatile private var isPlaying = false
    private val lock = Any()
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var playThread: Thread? = null

    companion object {
        private const val TAG = "AudioPlayer"
        private const val SAMPLE_RATE = 48000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_STEREO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // Max queue size to limit latency / drift.
        // At 48kHz, stereo, 16-bit, each packet (e.g. 1024 frames) is 4096 bytes (~21.3ms).
        // 6 packets is ~128ms max buffering latency.
        private const val MAX_QUEUE_SIZE = 6
    }

    fun start() {
        synchronized(lock) {
            if (isPlaying) return
            try {
                val minBufferSize = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
                // Use a slightly larger buffer (e.g. 2x min size) to prevent audio stuttering/underruns.
                val bufferSize = minBufferSize * 2

                audioTrack = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AUDIO_FORMAT)
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(CHANNEL_CONFIG)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                    .build()

                audioTrack?.play()
                isPlaying = true
                audioQueue.clear()

                playThread = Thread {
                    while (isPlaying) {
                        try {
                            val data = audioQueue.poll(100, TimeUnit.MILLISECONDS) ?: continue
                            synchronized(lock) {
                                if (isPlaying) {
                                    audioTrack?.write(data, 0, data.size)
                                }
                            }
                        } catch (e: InterruptedException) {
                            break
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in audio play thread", e)
                        }
                    }
                }.apply {
                    name = "AudioPlayerThread"
                    priority = Thread.MAX_PRIORITY
                    start()
                }

                Log.d(TAG, "AudioTrack started successfully (bufferSize=$bufferSize, lowLatencyEnabled=true)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start AudioTrack", e)
            }
        }
    }

    fun write(data: ByteArray, offset: Int, size: Int) {
        if (!isPlaying) return
        val pcm = if (offset == 0 && size == data.size) {
            data
        } else {
            data.copyOfRange(offset, offset + size)
        }

        // Bounded queue: drop oldest packet if we accumulate too many to prevent audio lag/drift
        while (audioQueue.size >= MAX_QUEUE_SIZE) {
            audioQueue.poll()
        }
        audioQueue.offer(pcm)
    }

    fun stop() {
        synchronized(lock) {
            isPlaying = false
        }
        playThread?.interrupt()
        try {
            playThread?.join(500)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        playThread = null
        audioQueue.clear()

        synchronized(lock) {
            try {
                audioTrack?.let { track ->
                    if (track.state == AudioTrack.STATE_INITIALIZED) {
                        try {
                            track.stop()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping AudioTrack", e)
                        }
                    }
                    track.release()
                }
                audioTrack = null
                Log.d(TAG, "AudioTrack stopped and released")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop AudioTrack", e)
            }
        }
    }
}
