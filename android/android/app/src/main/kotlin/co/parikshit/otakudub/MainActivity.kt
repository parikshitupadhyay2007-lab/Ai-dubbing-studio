package co.parikshit.otakudub

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
            "co.parikshit.otakudub/production_office").setMethodCallHandler { call, result ->
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
