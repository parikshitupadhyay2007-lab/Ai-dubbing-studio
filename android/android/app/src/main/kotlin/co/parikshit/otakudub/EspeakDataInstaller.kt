
package co.parikshit.otakudub

import android.content.Context
import java.io.File
import java.io.IOException

/**
 * Installs bundled eSpeak NG data into private app storage.
 *
 * Returns the PARENT directory containing espeak-ng-data,
 * as required by espeak_Initialize().
 */
object EspeakDataInstaller {

    private const val ASSET_ROOT = "espeak-ng-data"
    private const val INSTALL_VERSION = "1.52.0-1"

    private val requiredFiles = listOf(
        "phondata",
        "phonindex",
        "phontab",
        "intonations",
        "en_dict",
        "hi_dict"
    )

    @Synchronized
    fun install(context: Context): File {
        val parent = File(context.filesDir, "otakudub/espeak")
        val destination = File(parent, ASSET_ROOT)
        val marker = File(destination, ".install-version")

        if (
            marker.isFile &&
            marker.readText() == INSTALL_VERSION &&
            isValid(destination)
        ) {
            return parent
        }

        parent.mkdirs()

        val temporary = File(parent, "espeak-ng-data.tmp")

        if (temporary.exists()) {
            temporary.deleteRecursively()
        }

        temporary.mkdirs()

        try {
            copyAssets(
                context,
                ASSET_ROOT,
                temporary
            )

            check(isValid(temporary)) {
                "Bundled eSpeak NG data is incomplete."
            }

            File(
                temporary,
                ".install-version"
            ).writeText(INSTALL_VERSION)

            if (destination.exists()) {
                check(destination.deleteRecursively()) {
                    "Cannot replace previous eSpeak NG data."
                }
            }

            check(temporary.renameTo(destination)) {
                "Cannot install eSpeak NG data."
            }

            return parent

        } catch (error: Exception) {
            temporary.deleteRecursively()
            throw IOException(
                "Failed to install offline language data.",
                error
            )
        }
    }

    private fun copyAssets(
        context: Context,
        assetPath: String,
        destination: File
    ) {
        val children = context.assets.list(assetPath)
            ?: throw IOException(
                "Cannot read asset path: $assetPath"
            )

        if (children.isEmpty()) {
            destination.parentFile?.mkdirs()

            context.assets.open(assetPath).use { input ->
                destination.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            return
        }

        check(destination.isDirectory || destination.mkdirs()) {
            "Cannot create directory: ${destination.path}"
        }

        for (child in children) {
            copyAssets(
                context,
                "$assetPath/$child",
                File(destination, child)
            )
        }
    }

    private fun isValid(directory: File): Boolean {
        if (!directory.isDirectory) return false

        return requiredFiles.all { name ->
            val file = File(directory, name)
            file.isFile && file.length() > 0L
        }
    }
}
