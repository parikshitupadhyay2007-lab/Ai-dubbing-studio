package co.parikshit.otakudub

import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "co.parikshit.otakudub/department01_inference").setMethodCallHandler(
                Department01Inference(java.io.File(filesDir, "otakudub/models"))
            )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "co.parikshit.otakudub/production_office").setMethodCallHandler { call, result ->
            if (call.method == "sampleRgbFrame") {
                val path = call.argument<String>("path")
                val timestamp = call.argument<Number>("timestamp_ms")?.toLong()
                val size = call.argument<Int>("size")
                if (path.isNullOrBlank() || timestamp == null || timestamp < 0 ||
                    size == null || size !in 32..384) {
                    result.error("RGB_FRAME_REQUEST", "Invalid source, timestamp, or image size", null)
                    return@setMethodCallHandler
                }
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val duration = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    require(duration > 0 && timestamp <= duration) { "Frame outside source" }
                    val frame = retriever.getFrameAtTime(
                        timestamp * 1000L, MediaMetadataRetriever.OPTION_CLOSEST)
                        ?: error("Video frame unavailable")
                    try {
                        val resized = Bitmap.createScaledBitmap(frame, size, size, true)
                        try {
                            val pixels = IntArray(size * size)
                            resized.getPixels(pixels, 0, size, 0, 0, size, size)
                            val rgb = ByteArray(pixels.size * 3)
                            for (i in pixels.indices) {
                                val pixel = pixels[i]
                                rgb[i * 3] = (pixel shr 16).toByte()
                                rgb[i * 3 + 1] = (pixel shr 8).toByte()
                                rgb[i * 3 + 2] = pixel.toByte()
                            }
                            result.success(mapOf("timestamp_ms" to timestamp,
                                "width" to size, "height" to size,
                                "pixel_format" to "RGB_U8_INTERLEAVED",
                                "rgb" to rgb))
                        } finally { if (resized != frame) resized.recycle() }
                    } finally { frame.recycle() }
                } catch (e: Exception) {
                    result.error("RGB_FRAME_FAILED", e.message ?: "Cannot decode frame", null)
                } finally { retriever.release() }
                return@setMethodCallHandler
            }
            if (call.method == "sampleFrames") {
                val path = call.argument<String>("path")
                val requested = call.argument<List<Number>>("timestamps_ms")
                if (path.isNullOrBlank() || requested == null || requested.size > 240 || requested.any { it.toLong() < 0L }) {
                    result.error("FRAME_REQUEST", "Invalid path or timestamps (max 240)", null)
                    return@setMethodCallHandler
                }
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    if (duration <= 0L || requested.any { it.toLong() > duration }) {
                        result.error("FRAME_RANGE", "Frame timestamp outside media duration", null)
                        return@setMethodCallHandler
                    }
                    val samples = requested.map { timestamp ->
                        val frame = retriever.getFrameAtTime(timestamp.toLong() * 1000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        if (frame == null) {
                            mapOf<String, Any>("timestamp_ms" to timestamp.toLong(), "available" to false)
                        } else {
                            try {
                                val scaled = Bitmap.createScaledBitmap(frame, 8, 8, true)
                                try {
                                    val luma = (0 until 64).map { index ->
                                        val pixel = scaled.getPixel(index % 8, index / 8)
                                        val red = (pixel shr 16) and 255
                                        val green = (pixel shr 8) and 255
                                        val blue = pixel and 255
                                        (299 * red + 587 * green + 114 * blue) / 1000
                                    }
                                    mapOf<String, Any>("timestamp_ms" to timestamp.toLong(), "available" to true, "luma8x8" to luma)
                                } finally { scaled.recycle() }
                            } finally { frame.recycle() }
                        }
                    }
                    result.success(mapOf("duration_ms" to duration, "samples" to samples))
                } catch (e: Exception) {
                    result.error("FRAME_SAMPLING", e.message ?: "Could not sample frames", null)
                } finally { retriever.release() }
                return@setMethodCallHandler
            }
            if (call.method != "inspect") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("PATH", "A source file is required", null)
                return@setMethodCallHandler
            }
            try {
                val retriever = MediaMetadataRetriever()
                val extractor = MediaExtractor()
                try {
                    retriever.setDataSource(path)
                    extractor.setDataSource(path)
                    val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                    val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                    var video = false
                    var audio = false
                    val streams = mutableListOf<Map<String, Any>>()
                    for (index in 0 until extractor.trackCount) {
                        val format = extractor.getTrackFormat(index)
                        val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                        if (mime.startsWith("video/")) video = true
                        if (mime.startsWith("audio/")) audio = true
                        streams.add(mapOf("index" to index, "mime" to mime))
                    }
                    result.success(mapOf("duration_ms" to duration, "width" to width,
                        "height" to height, "has_video" to video, "has_audio" to audio,
                        "streams" to streams))
                } finally {
                    extractor.release()
                    retriever.release()
                }
            } catch (e: Exception) {
                result.error("MEDIA_INSPECTION", e.message ?: "Media inspection failed", null)
            }
        }
    }
}
