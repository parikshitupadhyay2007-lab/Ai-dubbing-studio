
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

    std::vector<int16_t> pcm(dataSize / 2);

    if (!file.read(
        reinterpret_cast<char*>(pcm.data()),
        dataSize
    )) return false;

    samples.resize(pcm.size());

    for (size_t i = 0; i < pcm.size(); ++i) {
        samples[i] = pcm[i] / 32768.0f;
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

    const int status = whisper_full(
        context,
        params,
        audio.data(),
        static_cast<int>(audio.size())
    );

    if (status != 0) {
        whisper_free(context);

        jclass errorClass = env->FindClass(
            "java/lang/IllegalStateException"
        );

        env->ThrowNew(
            errorClass,
            "Offline Whisper transcription failed."
        );

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

    const int count =
        whisper_full_n_segments(context);

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
            whisper_full_get_segment_t0(context, i) / 100.0;

        const double end =
            whisper_full_get_segment_t1(context, i) / 100.0;

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

    whisper_free(context);

    return segments;
}
