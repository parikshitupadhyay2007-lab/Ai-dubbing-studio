package co.parikshit.otakudub

import java.io.File
import java.io.RandomAccessFile
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Lightweight, fully offline speaker clustering.
 *
 * Input:
 *   16 kHz, mono, signed 16-bit PCM WAV.
 *
 * This is an acoustic baseline, not a trained speaker-embedding
 * model. Short, noisy or overlapping speech may remain unknown.
 */
object SpeakerDiarizer {

    private const val SAMPLE_RATE = 16000
    private const val MIN_SPEECH_SECONDS = 0.45
    private const val MAX_SPEAKERS = 12
    private const val MATCH_THRESHOLD = 0.22
    private const val MIN_MATCH_MARGIN = 0.035
    private const val MIN_NEW_SPEAKER_DISTANCE = 0.30

    private data class VoiceProfile(
        val features: DoubleArray,
        var observations: Int = 1
    )

    fun identify(
        wavPath: String,
        segments: List<Map<String, Any?>>,
        embeddingExtractor: SpeakerFeatureExtractor? = null,
        embeddingMatchThreshold: Double? = null,
        embeddingNewSpeakerThreshold: Double? = null
    ): List<Map<String, Any?>> {
        if (embeddingExtractor != null) {
            require(embeddingMatchThreshold != null &&
                embeddingNewSpeakerThreshold != null &&
                embeddingMatchThreshold.isFinite() &&
                embeddingNewSpeakerThreshold.isFinite() &&
                embeddingMatchThreshold > 0.0 &&
                embeddingNewSpeakerThreshold > embeddingMatchThreshold &&
                embeddingNewSpeakerThreshold <= 2.0) {
                "Trained speaker embeddings require calibrated match/new-speaker thresholds."
            }
        }

        val samples = readWav(wavPath)
        // Process in chronological order: speaker profiles should be learned
        // from earlier audio, not from arbitrary incoming list order.
        // Restore the original order before returning results to Flutter.
        val ordered = segments.withIndex().sortedWith(
            compareBy<IndexedValue<Map<String, Any?>>> {
                (it.value["start"] as? Number)?.toDouble() ?: Double.POSITIVE_INFINITY
            }.thenBy { it.index }
        )
        val profiles = mutableListOf<VoiceProfile>()
        var embeddingDimensions: Int? = null
        val observations = arrayOfNulls<DoubleArray>(segments.size)

        // Sweep both directions instead of checking every pair of segments.
        // Preserve the original 50 ms tolerance for boundary-level overlap.
        // This keeps overlap detection linear after chronological sorting.
        val overlapsByIndex = BooleanArray(segments.size)
        var latestPriorEnd = Double.NEGATIVE_INFINITY
        for (entry in ordered) {
            val start = (entry.value["start"] as? Number)?.toDouble()
                ?: Double.POSITIVE_INFINITY
            val end = (entry.value["end"] as? Number)?.toDouble()
                ?: Double.NEGATIVE_INFINITY
            if (latestPriorEnd > start + 0.05) overlapsByIndex[entry.index] = true
            if (end > latestPriorEnd) latestPriorEnd = end
        }
        var earliestNextStart = Double.POSITIVE_INFINITY
        for (entry in ordered.asReversed()) {
            val start = (entry.value["start"] as? Number)?.toDouble()
                ?: Double.POSITIVE_INFINITY
            val end = (entry.value["end"] as? Number)?.toDouble()
                ?: Double.NEGATIVE_INFINITY
            if (earliestNextStart < end - 0.05) overlapsByIndex[entry.index] = true
            if (start < earliestNextStart) earliestNextStart = start
        }

        val identified = ordered.map { entry ->
            val segment = entry.value

            val start = (segment["start"] as? Number)
                ?.toDouble() ?: 0.0

            val end = (segment["end"] as? Number)
                ?.toDouble() ?: start

            val text = segment["original"]
                ?.toString()?.trim().orEmpty()

            val first = (start * SAMPLE_RATE)
                .toInt().coerceIn(0, samples.size)

            val last = (end * SAMPLE_RATE)
                .toInt().coerceIn(first, samples.size)

            val clip = if (last > first) {
                samples.copyOfRange(first, last)
            } else {
                FloatArray(0)
            }

            // Overlapping speech contaminates acoustic identity features.
            // Keep the segment unresolved rather than training a profile on
            // two characters speaking simultaneously.
            val overlaps = overlapsByIndex[entry.index]
            val features = if (
                !overlaps && text.isNotEmpty() &&
                clip.size >=
                    (MIN_SPEECH_SECONDS * SAMPLE_RATE).toInt()
            ) {
                if (embeddingExtractor == null) {
                    extractFeatures(clip)
                } else {
                    SpeakerFeatureValidation.normalizedOrNull(
                        embeddingExtractor.extract(clip)
                    )
                }
            } else {
                null
            }

            var speakerId = "unknown"
            var confidence = 0.0

            if (features != null && embeddingExtractor != null) {
                val expected = embeddingDimensions
                if (expected == null) {
                    embeddingDimensions = features.size
                } else {
                    require(features.size == expected) {
                        "Speaker embedding dimension changed between segments."
                    }
                }
            }

            if (features != null) {
                observations[entry.index] = features.copyOf()

                var bestIndex = -1
                var bestDistance = Double.MAX_VALUE
                var secondDistance = Double.MAX_VALUE

                profiles.forEachIndexed { index, profile ->
                    val distance = if (embeddingExtractor == null) {
                        distance(features, profile.features)
                    } else {
                        SpeakerFeatureValidation.cosineDistance(features, profile.features)
                    }

                    if (distance < bestDistance) {
                        secondDistance = bestDistance
                        bestDistance = distance
                        bestIndex = index
                    } else if (distance < secondDistance) {
                        secondDistance = distance
                    }
                }

                val matchThreshold = if (embeddingExtractor == null) MATCH_THRESHOLD else embeddingMatchThreshold!!
                val newSpeakerThreshold = if (embeddingExtractor == null) MIN_NEW_SPEAKER_DISTANCE else embeddingNewSpeakerThreshold!!
                if (
                    bestIndex >= 0 &&
                    bestDistance < matchThreshold &&
                    secondDistance - bestDistance >= MIN_MATCH_MARGIN
                ) {
                    val profile = profiles[bestIndex]

                    val count = profile.observations
                    val weight = 1.0 / (count + 1)

                    for (i in features.indices) {
                        profile.features[i] =
                            profile.features[i] * (1.0 - weight) +
                            features[i] * weight
                    }

                    // Cosine centroids must stay unit-normalized after each
                    // update; otherwise repeated matches change the metric.
                    if (embeddingExtractor != null) {
                        val normalized = SpeakerFeatureValidation.normalizedOrNull(
                            profile.features
                        ) ?: throw IllegalStateException(
                            "Updated speaker centroid is invalid."
                        )
                        normalized.copyInto(profile.features)
                    }
                    profile.observations++

                    speakerId = "speaker_${bestIndex + 1}"

                    confidence = (
                        1.0 - bestDistance / matchThreshold
                    ).coerceIn(0.0, 0.85)

                } else if (
                    // An ambiguous match to two existing speakers must not
                    // create a fictitious third character identity.
                    // The gap between a failed match and a genuinely new
                    // identity is uncertain: do not create a new speaker
                    // until the nearest existing profile is clearly distant.
                    bestDistance >= newSpeakerThreshold &&
                    profiles.size < MAX_SPEAKERS
                ) {
                    profiles.add(
                        VoiceProfile(features.copyOf())
                    )

                    speakerId = "speaker_${profiles.size}"

                    // A newly discovered voice has not yet been
                    // independently confirmed by another segment.
                    confidence = 0.35
                }
            }

            segment.toMutableMap().apply {
                put("speaker_id", speakerId)
                put("speaker_confidence", confidence)
            }.toMap()
        }

        // A second *acoustic* pass lets early uncertain lines benefit from
        // speaker profiles learned from later, clearer dialogue. Do not use
        // chronology, silence, or nearest-neighbour guessing as identity proof.
        // Overlapping segments and invalid/short embeddings remain unresolved.
        val restored = restoreOrder(ordered, identified).toMutableList()
        val matchThreshold = if (embeddingExtractor == null) MATCH_THRESHOLD else embeddingMatchThreshold!!
        for (index in restored.indices) {
            if (restored[index]["speaker_id"] != "unknown" || overlapsByIndex[index]) continue
            val features = observations[index] ?: continue
            val distances = profiles.map { profile ->
                if (embeddingExtractor == null) distance(features, profile.features)
                else SpeakerFeatureValidation.cosineDistance(features, profile.features)
            }.withIndex().sortedBy { it.value }
            val best = distances.firstOrNull() ?: continue
            val second = distances.getOrNull(1)?.value ?: Double.POSITIVE_INFINITY
            if (best.value < matchThreshold &&
                second - best.value >= MIN_MATCH_MARGIN) {
                restored[index] = restored[index].toMutableMap().apply {
                    put("speaker_id", "speaker_${best.index + 1}")
                    put("speaker_confidence",
                        (1.0 - best.value / matchThreshold).coerceIn(0.0, 0.75))
                }
            }
        }
        return restored
    }

    private fun restoreOrder(
        ordered: List<IndexedValue<Map<String, Any?>>>,
        results: List<Map<String, Any?>>
    ): List<Map<String, Any?>> {
        val restored = arrayOfNulls<Map<String, Any?>>(results.size)
        ordered.forEachIndexed { index, entry ->
            restored[entry.index] = results[index]
        }
        return restored.map { requireNotNull(it) }
    }

    private fun readWav(path: String): FloatArray {
        val file = File(path)

        require(file.isFile) {
            "Speaker analysis WAV file is missing."
        }

        RandomAccessFile(file, "r").use { wav ->

            require(wav.length() >= 44) {
                "Invalid WAV file."
            }

            val header = ByteArray(44)
            wav.readFully(header)

            require(
                String(header, 0, 4, Charsets.US_ASCII) == "RIFF" &&
                String(header, 8, 4, Charsets.US_ASCII) == "WAVE" &&
                String(header, 12, 4, Charsets.US_ASCII) == "fmt " &&
                String(header, 36, 4, Charsets.US_ASCII) == "data"
            ) {
                "Expected a standard PCM WAV file."
            }

            fun uint16(offset: Int): Int =
                (header[offset].toInt() and 255) or
                ((header[offset + 1].toInt() and 255) shl 8)

            fun uint32(offset: Int): Long =
                (header[offset].toLong() and 255L) or
                ((header[offset + 1].toLong() and 255L) shl 8) or
                ((header[offset + 2].toLong() and 255L) shl 16) or
                ((header[offset + 3].toLong() and 255L) shl 24)

            require(
                uint16(20) == 1 &&
                uint16(22) == 1 &&
                uint32(24) == SAMPLE_RATE.toLong() &&
                uint16(34) == 16
            ) {
                "Speaker analysis requires 16 kHz mono PCM16."
            }

            val dataSize = uint32(40)

            require(
                dataSize > 0 &&
                dataSize % 2L == 0L &&
                dataSize <= wav.length() - 44L &&
                dataSize / 2L <= Int.MAX_VALUE
            ) {
                "Invalid WAV audio length."
            }

            val result = FloatArray((dataSize / 2).toInt())

            // Read PCM in blocks instead of making two file reads per sample.
            val block = ByteArray(65536)
            var written = 0
            while (written < result.size) {
                val count = min(block.size / 2, result.size - written)
                wav.readFully(block, 0, count * 2)
                for (i in 0 until count) {
                    val value = (block[i * 2].toInt() and 255) or
                        ((block[i * 2 + 1].toInt() and 255) shl 8)
                    val signed = if (value >= 32768) value - 65536 else value
                    result[written + i] = signed / 32768f
                }
                written += count
            }

            return result
        }
    }

    private fun extractFeatures(
        audio: FloatArray
    ): DoubleArray? {

        val frameSize = 400
        val hop = 160

        if (audio.size < frameSize * 8) return null

        val energies = mutableListOf<Double>()
        val crossings = mutableListOf<Double>()
        val differences = mutableListOf<Double>()

        var offset = 0

        while (offset + frameSize <= audio.size) {

            var energy = 0.0
            var crossingCount = 0
            var difference = 0.0

            var previous = audio[offset].toDouble()

            for (i in 0 until frameSize) {
                val value = audio[offset + i].toDouble()

                energy += value * value

                if (
                    i > 0 &&
                    (value >= 0.0) != (previous >= 0.0)
                ) {
                    crossingCount++
                }

                if (i > 0) {
                    difference += abs(value - previous)
                }

                previous = value
            }

            val rms = sqrt(energy / frameSize)

            if (rms > 0.012) {
                energies.add(rms)
                crossings.add(
                    crossingCount.toDouble() / frameSize
                )
                differences.add(
                    difference / (frameSize - 1)
                )
            }

            offset += hop
        }

        if (energies.size < 12) return null

        fun mean(values: List<Double>): Double =
            values.average()

        fun deviation(values: List<Double>): Double {
            val average = mean(values)

            return sqrt(
                values.map {
                    (it - average) * (it - average)
                }.average()
            )
        }

        val energy = mean(energies)
        val zcr = mean(crossings)
        val variation = mean(differences)

        return doubleArrayOf(
            (ln(1.0 + energy * 100.0) / 4.0)
                .coerceIn(0.0, 1.0),
            (zcr * 4.0).coerceIn(0.0, 1.0),
            (variation * 8.0).coerceIn(0.0, 1.0),
            (deviation(energies) * 10.0)
                .coerceIn(0.0, 1.0),
            (deviation(crossings) * 8.0)
                .coerceIn(0.0, 1.0)
        )
    }

    private fun distance(
        a: DoubleArray,
        b: DoubleArray
    ): Double {

        var total = 0.0

        val weights = doubleArrayOf(
            0.10,
            0.30,
            0.35,
            0.10,
            0.15
        )

        for (i in a.indices) {
            val difference = a[i] - b[i]

            total += weights[i] *
                difference * difference
        }

        return sqrt(total)
    }
}
