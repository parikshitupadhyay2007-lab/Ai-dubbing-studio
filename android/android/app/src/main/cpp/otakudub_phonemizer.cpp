#include <jni.h>

#include <espeak-ng/speak_lib.h>

#include <mutex>
#include <string>
#include <vector>

namespace {

std::mutex phonemizerMutex;
bool initialized = false;

std::string toString(
    JNIEnv* env,
    jstring value
) {
    if (value == nullptr) {
        return {};
    }

    const char* chars = env->GetStringUTFChars(value, nullptr);

    if (chars == nullptr) {
        return {};
    }

    std::string result(chars);

    env->ReleaseStringUTFChars(value, chars);

    return result;
}

void throwJava(
    JNIEnv* env,
    const char* message
) {
    jclass exception = env->FindClass(
        "java/lang/IllegalStateException"
    );

    if (exception != nullptr) {
        env->ThrowNew(exception, message);
    }
}

}

extern "C"
JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativeInitialize(
    JNIEnv* env,
    jobject,
    jstring dataPath
) {
    std::lock_guard<std::mutex> lock(phonemizerMutex);

    if (initialized) {
        return JNI_TRUE;
    }

    const std::string path = toString(env, dataPath);

    if (path.empty()) {
        return JNI_FALSE;
    }

    const int result = espeak_Initialize(
        AUDIO_OUTPUT_SYNCHRONOUS,
        0,
        path.c_str(),
        0
    );

    initialized = result > 0;

    return initialized ? JNI_TRUE : JNI_FALSE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativePhonemize(
    JNIEnv* env,
    jobject,
    jstring input,
    jstring voiceName
) {
    std::lock_guard<std::mutex> lock(phonemizerMutex);

    if (!initialized) {
        throwJava(env, "eSpeak NG is not initialized.");
        return nullptr;
    }

    const std::string text = toString(env, input);
    const std::string voice = toString(env, voiceName);

    if (text.empty() || voice.empty()) {
        throwJava(env, "Text or voice identifier is empty.");
        return nullptr;
    }

    const espeak_ERROR voiceResult =
        espeak_SetVoiceByName(voice.c_str());

    if (voiceResult != EE_OK) {
        throwJava(env, "Requested eSpeak voice is unavailable.");
        return nullptr;
    }

    // eSpeak's phoneme conversion API expects a mutable
    // pointer and may advance it while processing text.
    std::vector<char> buffer(text.begin(), text.end());
    buffer.push_back('\0');

    const void* cursor = buffer.data();

    std::string output;

    constexpr int phonemeMode = 0x02;

    while (cursor != nullptr) {
        const char* phonemes = espeak_TextToPhonemes(
            &cursor,
            espeakCHARS_UTF8,
            phonemeMode
        );

        if (phonemes == nullptr) {
            throwJava(env, "eSpeak phoneme conversion failed.");
            return nullptr;
        }

        output += phonemes;
    }

    if (output.empty()) {
        throwJava(env, "eSpeak returned no phonemes.");
        return nullptr;
    }

    return env->NewStringUTF(output.c_str());
}

extern "C"
JNIEXPORT void JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativeShutdown(
    JNIEnv*,
    jobject
) {
    std::lock_guard<std::mutex> lock(phonemizerMutex);

    if (initialized) {
        espeak_Terminate();
        initialized = false;
    }
}
