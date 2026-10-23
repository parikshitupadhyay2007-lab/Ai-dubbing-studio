package co.parikshit.otakudub

import java.text.Normalizer
import java.util.Locale

/**
 * Explicit, project-curated pronunciation substitutions for Piper input.
 * Entries are NOT generated from guesses: provide an approved spoken form for
 * each target language. Match complete terms, longest first, case-insensitively.
 * This is a text pronunciation aid, not a phoneme-level guarantee.
 */
internal data class PronunciationEntry(
    val written: String,
    val spoken: String,
    val language: String
) {
    init {
        require(language == "hi" || language == "en")
        require(written.isNotBlank() && spoken.isNotBlank())
        require(written.length <= 100 && spoken.length <= 160)
        require(!written.contains('\n') && !spoken.contains('\n'))
        require(!written.any { it.isISOControl() } && !spoken.any { it.isISOControl() })
    }
}

internal class PronunciationGlossary(entries: List<PronunciationEntry>) {
    private val byLanguage = entries.groupBy { it.language }.mapValues { (_, values) ->
        require(values.map { it.written.lowercase(Locale.ROOT) }.toSet().size == values.size) {
            "Duplicate pronunciation glossary terms"
        }
        values.sortedByDescending { it.written.length }
    }

    fun apply(text: String, language: String): String {
        val entries = byLanguage[language] ?: return text
        if (entries.isEmpty() || text.isEmpty()) return text
        // One pass against original input avoids recursively rewriting the
        // spoken forms or changing substrings inside character names.
        val matches = entries.map { entry ->
            val term = Regex.escape(entry.written)
            val boundaryStart = if (entry.written.first().isLetterOrDigit()) "(?<![\\p{L}\\p{N}])" else ""
            val boundaryEnd = if (entry.written.last().isLetterOrDigit()) "(?![\\p{L}\\p{N}])" else ""
            entry to Regex(boundaryStart + term + boundaryEnd, RegexOption.IGNORE_CASE)
        }
        val out = StringBuilder()
        var position = 0
        while (position < text.length) {
            val candidate = matches.mapNotNull { (entry, pattern) ->
                pattern.find(text, position)?.takeIf { it.range.first == position }?.let { entry to it }
            }.maxByOrNull { it.second.value.length }
            if (candidate == null) {
                out.append(text[position])
                position++
            } else {
                out.append(candidate.first.spoken)
                position = candidate.second.range.last + 1
            }
        }
        return Normalizer.normalize(out.toString(), Normalizer.Form.NFC)
    }
}
