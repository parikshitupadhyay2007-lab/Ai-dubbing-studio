
#include <jni.h>
#include <android/log.h>
#include <whisper.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include <vector>

namespace {

std::mutex whisperMutex;

std::string javaString(JNIEnv* env, jstring value) {
    if (!value) return "";

    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (!chars) return "";

    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);

    return result;
}

uint16_t read16(const unsigned char* p) {
    return uint16_t(p[0]) |
           (uint16_t(p[1]) << 8);
}

uint32_t read32(const unsigned char* p) {
    return uint32_t(p[0]) |
           (uint32_t(p[1]) << 8) |
           (uint32_t(p[2]) << 16) |
           (uint32_t(p[3]) << 24);
}

bool loadWav(
    const std::string& path,
    std::vector<float>& samples
) {
    std::ifstream file(path, std::ios::binary);

    if (!file) return false;

    unsigned char header[12];

    if (!file.read(
        reinterpret_cast<char*>(header), 12
    )) return false;

    if (std::memcmp(header, "RIFF", 4) != 0 ||
        std::memcmp(header + 8, "WAVE", 4) != 0) {
        return false;
    }

    bool validFormat = false;
    bool foundData = false;

    uint32_t dataSize = 0;
    std::streampos dataPosition{};

    while (file) {
        unsigned char chunk[8];

        if (!file.read(
            reinterpret_cast<char*>(chunk), 8
        )) break;

        uint32_t size = read32(chunk + 4);

        if (std::memcmp(chunk, "fmt ", 4) == 0) {
            if (size < 16) return false;

            unsigned char fmt[16];

            if (!file.read(
                reinterpret_cast<char*>(fmt), 16
            )) return false;

            const uint16_t encoding = read16(fmt);
            const uint16_t channels = read16(fmt + 2);
            const uint32_t rate = read32(fmt + 4);
            const uint16_t bits = read16(fmt + 14);

            validFormat =
                encoding == 1 &&
                channels == 1 &&
                rate == 16000 &&
                bits == 16;

            file.seekg(size - 16, std::ios::cur);
        } else if (std::memcmp(chunk, "data", 4) == 0) {
            dataPosition = file.tellg();
            dataSize = size;
            foundData = true;
            break;
        } else {
            file.seekg(size, std::ios::cur);
        }

        if (size & 1) {
            file.seekg(1, std::ios::cur);
        }
    }

    if (!validFormat || !foundData ||
        dataSize == 0 || dataSize % 2 != 0) {
        return false;
    }

    file.clear();
    file.seekg(dataPosition);

    // Decode directly into the inference buffer in small blocks. Avoid a
    // second full-length PCM16 allocation (roughly 44 MB for 23 minutes).
    samples.resize(dataSize / 2);
    unsigned char block[32768];
    size_t written = 0;
    while (written < samples.size()) {
        const size_t count = std::min<size_t>(sizeof(block) / 2,
                                              samples.size() - written);
        if (!file.read(reinterpret_cast<char*>(block),
                       static_cast<std::streamsize>(count * 2))) return false;
        for (size_t i = 0; i < count; ++i) {
            samples[written + i] =
                static_cast<int16_t>(read16(block + i * 2)) / 32768.0f;
        }
        written += count;
    }

    return true;
}

} // namespace

extern "C"
JNIEXPORT jobject JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeTranscribeWav(
    JNIEnv* env,
    jobject,
    jstring modelPath,
    jstring wavPath,
    jstring language
) {
    std::lock_guard<std::mutex> lock(whisperMutex);

    const std::string model = javaString(env, modelPath);
    const std::string wav = javaString(env, wavPath);
    const std::string lang = javaString(env, language);

    std::vector<float> audio;

    if (!loadWav(wav, audio)) {
        jclass errorClass = env->FindClass(
            "java/lang/IllegalArgumentException"
        );

        env->ThrowNew(
            errorClass,
            "Whisper requires mono 16 kHz PCM16 WAV audio."
        );

        return nullptr;
    }

    whisper_context_params contextParams =
        whisper_context_default_params();

    whisper_context* context =
        whisper_init_from_file_with_params(
            model.c_str(),
            contextParams
        );

    if (!context) {
        jclass errorClass = env->FindClass(
            "java/lang/IllegalStateException"
        );

        env->ThrowNew(
            errorClass,
            "Could not load the Whisper model."
        );

        return nullptr;
    }

    whisper_full_params params =
        whisper_full_default_params(
            WHISPER_SAMPLING_GREEDY
        );

    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.translate = false;
    params.n_threads = 4;
    params.no_context = true;
    params.single_segment = false;

    params.language =
        lang.empty() || lang == "auto" || lang == "unknown"
            ? nullptr
            : lang.c_str();

    // Bound each inference call to 30 seconds rather than feeding the entire
    // movie to Whisper at once. Keep the model loaded across chunks.
    constexpr size_t chunkSamples = 30 * 16000;
    if (audio.empty()) {
        whisper_free(context);
        env->ThrowNew(env->FindClass("java/lang/IllegalArgumentException"), "Decoded audio is empty.");
        return nullptr;
    }

    jclass arrayListClass = env->FindClass(
        "java/util/ArrayList"
    );

    jmethodID arrayListConstructor =
        env->GetMethodID(
            arrayListClass,
            "<init>",
            "()V"
        );

    jmethodID addMethod = env->GetMethodID(
        arrayListClass,
        "add",
        "(Ljava/lang/Object;)Z"
    );

    jobject segments = env->NewObject(
        arrayListClass,
        arrayListConstructor
    );

    jclass mapClass = env->FindClass(
        "java/util/HashMap"
    );

    jmethodID mapConstructor = env->GetMethodID(
        mapClass,
        "<init>",
        "()V"
    );

    jmethodID putMethod = env->GetMethodID(
        mapClass,
        "put",
        "(Ljava/lang/Object;Ljava/lang/Object;)"
        "Ljava/lang/Object;"
    );

    jclass doubleClass = env->FindClass(
        "java/lang/Double"
    );

    jmethodID doubleConstructor = env->GetMethodID(
        doubleClass,
        "<init>",
        "(D)V"
    );

    std::string detectedLanguage = lang;
    const bool automaticLanguage = lang.empty() || lang == "auto" || lang == "unknown";
    if (automaticLanguage) detectedLanguage.clear();
    for (size_t offset = 0; offset < audio.size(); offset += chunkSamples) {
        const size_t length = std::min(chunkSamples, audio.size() - offset);
        const int status = whisper_full(context, params, audio.data() + offset,
                                        static_cast<int>(length));
        if (status != 0) {
            whisper_free(context);
            env->ThrowNew(env->FindClass("java/lang/IllegalStateException"),
                          "Offline Whisper failed while processing an audio chunk.");
            return nullptr;
        }
        if (automaticLanguage && detectedLanguage.empty()) {
            const int languageId = whisper_full_lang_id(context);
            const char* code = languageId >= 0 ? whisper_lang_str(languageId) : nullptr;
            if (!code || !*code) {
                whisper_free(context);
                env->ThrowNew(env->FindClass("java/lang/IllegalStateException"),
                              "Whisper did not detect a source language.");
                return nullptr;
            }
            detectedLanguage = code;
            // Subsequent chunks must use the same detected language instead of
            // re-detecting independently and silently mixing language outputs.
            params.language = detectedLanguage.c_str();
        }
        const double timeOffset = static_cast<double>(offset) / 16000.0;
        const int count = whisper_full_n_segments(context);
        for (int i = 0; i < count; ++i) {
        jobject segment = env->NewObject(
            mapClass,
            mapConstructor
        );

        auto put = [&](const char* key, jobject value) {
            jstring javaKey = env->NewStringUTF(key);

            env->CallObjectMethod(
                segment,
                putMethod,
                javaKey,
                value
            );

            env->DeleteLocalRef(javaKey);
            env->DeleteLocalRef(value);
        };

        const double start =
            whisper_full_get_segment_t0(context, i) / 100.0 + timeOffset;

        const double end =
            whisper_full_get_segment_t1(context, i) / 100.0 + timeOffset;

        const char* text =
            whisper_full_get_segment_text(context, i);

        put(
            "start",
            env->NewObject(
                doubleClass,
                doubleConstructor,
                start
            )
        );

        put(
            "end",
            env->NewObject(
                doubleClass,
                doubleConstructor,
                end
            )
        );

        put(
            "original",
            env->NewStringUTF(text ? text : "")
        );

        env->CallBooleanMethod(
            segments,
            addMethod,
            segment
        );

        env->DeleteLocalRef(segment);
        }
    }

    whisper_free(context);

    jobject response = env->NewObject(mapClass, mapConstructor);
    auto putResponse = [&](const char* key, jobject value) {
        jstring javaKey = env->NewStringUTF(key);
        env->CallObjectMethod(response, putMethod, javaKey, value);
        env->DeleteLocalRef(javaKey);
        env->DeleteLocalRef(value);
    };
    putResponse("segments", segments);
    putResponse("language", env->NewStringUTF(detectedLanguage.c_str()));
    return response;
}
