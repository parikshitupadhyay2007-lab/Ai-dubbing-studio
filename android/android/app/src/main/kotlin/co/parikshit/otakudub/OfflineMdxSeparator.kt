package co.parikshit.otakudub

import java.io.File
import java.security.MessageDigest

/**
 * Offline, chunked complex-spectrogram source separation.
 *
 * This implementation accepts ONLY an explicitly verified instrumental
 * checkpoint. Shape compatibility alone cannot establish stem polarity,
 * normalization, or the model's training-time transform.
 *
 * Export integration must remain fail-closed until checkpoint-specific
 * reference parity and Android audio tests pass.
 */
class OfflineMdxSeparator(
    private val config: SeparationModelConfig,
    private val profile: SeparationMdxProfile,
    private val expectedCheckpointSha256: String
) : BackgroundAudioSeparator {

    override fun separate(request: SeparationRequest): SeparationResult {
        request.validate()
        require(expectedCheckpointSha256.matches(Regex("[0-9a-fA-F]{64}"))) {
            "A trusted SHA-256 for the verified instrumental checkpoint is required."
        }
        val digest = MessageDigest.getInstance("SHA-256")
        File(request.modelPath).inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        val actualHash = digest.digest().joinToString("") {
            "%02x".format(it.toInt() and 0xff)
        }
        require(actualHash.equals(expectedCheckpointSha256, ignoreCase = true)) {
            "Separation checkpoint SHA-256 does not match the trusted reference."
        }
        require(File(config.modelPath).canonicalFile ==
            File(request.modelPath).canonicalFile) {
            "The separation request differs from the verified checkpoint."
        }
        require(config.sampleRate == profile.sampleRate &&
            config.channels == profile.channels &&
            config.outputNames.size == 1) {
            "Model metadata does not match the configured MDX profile."
        }

        val inputShape = profile.inputShape.toList()
        require(config.inputShape == inputShape &&
            config.outputShapes.single() == inputShape) {
            "This implementation requires a static [1,4,F,T] MDX contract."
        }

        val work = File(request.outputDirectory, "intermediate")
        check(work.isDirectory || work.mkdirs()) {
            "Unable to create separation workspace."
        }
        val decoded = File(work, "decoded.wav")
        val resampled = File(work, "model_rate.wav")
        val instrumental = File(request.outputDirectory, "instrumental.wav")
        val vocals = File(request.outputDirectory, "vocals.wav")

        try {
            val audio = SeparationAudioDecoder.decode(
                request.sourceMediaPath, decoded.absolutePath
            )
            val source = if (audio.sampleRate == profile.sampleRate) {
                decoded
            } else {
                SeparationAudioResampler.resample(
                    decoded.absolutePath,
                    resampled.absolutePath,
                    profile.sampleRate
                )
                resampled
            }

            // For centered STFT, N=(T-1)*hop yields exactly T frames.
            val chunkFramesLong =
                (profile.timeFrames.toLong() - 1L) * profile.hopSize
            require(chunkFramesLong in 1..Int.MAX_VALUE.toLong()) {
                "Unsupported MDX chunk size."
            }
            val chunkFrames = chunkFramesLong.toInt()
            val overlapFrames = chunkFrames / 10

            SeparationOnnxRunner(config).use { runner ->
                SeparationAudioChunkReader(
                    source.absolutePath, chunkFrames, overlapFrames
                ).use { reader ->
                    require(reader.sampleRate == profile.sampleRate) {
                        "Source WAV sample rate does not match model."
                    }
                    SeparationWavWriter(
                        instrumental.absolutePath, profile.sampleRate
                    ).use { musicWriter ->
                        SeparationWavWriter(
                            vocals.absolutePath, profile.sampleRate
                        ).use { vocalsWriter ->
                            SeparationOverlapAdd(musicWriter).use { musicJoin ->
                                SeparationOverlapAdd(vocalsWriter).use { vocalsJoin ->
                                    var chunk = reader.nextChunk()
                                    while (chunk != null) {
                                        val spectrum = SeparationStft.transform(
                                            chunk.left, chunk.right,
                                            profile.stftConfig
                                        )
                                        val tensor = SeparationSpectrogramTensor.prepare(
                                            spectrum, profile.tensorConfig
                                        )
                                        require(tensor.shape.contentEquals(profile.inputShape)) {
                                            "STFT framing differs from the model contract."
                                        }
                                        val outputs = runner.run(
                                            tensor.values, tensor.shape
                                        )
                                        require(outputs.size == 1) {
                                            "Expected one predicted instrumental stem."
                                        }
                                        val prediction = SeparationOutputDecoder.decode(
                                            outputs.single(),
                                            chunkFrames,
                                            profile.stftConfig,
                                            SeparationOutputDecoder.Config(
                                                originalFrequencyBins =
                                                    profile.fftSize / 2 + 1,
                                                removeLowestBin =
                                                    profile.removeLowestBin,
                                                normalization =
                                                    profile.normalization
                                            )
                                        )
                                        val (musicL, musicR) =
                                            SeparationStft.inverse(prediction)
                                        val vocalL = FloatArray(chunkFrames) { i ->
                                            chunk.left[i] - musicL[i]
                                        }
                                        val vocalR = FloatArray(chunkFrames) { i ->
                                            chunk.right[i] - musicR[i]
                                        }
                                        musicJoin.append(
                                            chunk.startFrame, musicL, musicR,
                                            chunk.validFrames
                                        )
                                        vocalsJoin.append(
                                            chunk.startFrame, vocalL, vocalR,
                                            chunk.validFrames
                                        )
                                        chunk = reader.nextChunk()
                                    }
                                    musicJoin.finish()
                                    vocalsJoin.finish()
                                }
                            }
                            vocalsWriter.finish()
                        }
                        musicWriter.finish()
                    }
                }
            }
            val result = SeparationResult(
                vocals.absolutePath, instrumental.absolutePath,
                profile.sampleRate, 2
            )
            result.validate()
            return result
        } catch (error: Throwable) {
            instrumental.delete()
            vocals.delete()
            throw error
        } finally {
            decoded.delete()
            resampled.delete()
            work.delete()
        }
    }
}
