
#include <mutex>
#include <string>
#include <vector>

#include <jni.h>
#include <espeak-ng/speak_lib.h>

namespace {

std::mutex engineMutex;
bool engineInitialized = false;

std::string fromJavaString(
    JNIEnv* env,
    jstring value
) {
    if (value == nullptr) {
        return {};
    }

    const char* chars = env->GetStringUTFChars(
        value,
        nullptr
    );

    if (chars == nullptr) {
        return {};
    }

    std::string result(chars);

    env->ReleaseStringUTFChars(value, chars);

    return result;
}

void throwError(
    JNIEnv* env,
    const char* message
) {
    jclass exceptionClass = env->FindClass(
        "java/lang/IllegalStateException"
    );

    if (exceptionClass != nullptr) {
        env->ThrowNew(exceptionClass, message);
        env->DeleteLocalRef(exceptionClass);
    }
}

} // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativeInitialize(
    JNIEnv* env,
    jclass,
    jstring dataPath
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    if (engineInitialized) {
        return JNI_TRUE;
    }

    const std::string path = fromJavaString(
        env,
        dataPath
    );

    if (path.empty()) {
        return JNI_FALSE;
    }

    const int sampleRate = espeak_Initialize(
        AUDIO_OUTPUT_SYNCHRONOUS,
        0,
        path.c_str(),
        0
    );

    if (sampleRate <= 0) {
        return JNI_FALSE;
    }

    engineInitialized = true;

    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativePhonemize(
    JNIEnv* env,
    jclass,
    jstring input,
    jstring voiceName
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    if (!engineInitialized) {
        throwError(
            env,
            "eSpeak NG has not been initialized."
        );

        return nullptr;
    }

    const std::string text = fromJavaString(
        env,
        input
    );

    const std::string voice = fromJavaString(
        env,
        voiceName
    );

    if (text.empty() || voice.empty()) {
        throwError(
            env,
            "Text and voice must not be empty."
        );

        return nullptr;
    }

    if (
        espeak_SetVoiceByName(voice.c_str()) != EE_OK
    ) {
        throwError(
            env,
            "The requested eSpeak voice is unavailable."
        );

        return nullptr;
    }

    std::vector<char> buffer(
        text.begin(),
        text.end()
    );

    buffer.push_back('\0');

    const void* cursor = buffer.data();

    std::string phonemeOutput;

    constexpr int MAX_CLAUSES = 4096;

    int clauseCount = 0;

    while (cursor != nullptr) {

        if (++clauseCount > MAX_CLAUSES) {
            throwError(
                env,
                "Phonemization exceeded the clause limit."
            );

            return nullptr;
        }

        const void* previousCursor = cursor;

        const char* phonemes = espeak_TextToPhonemes(
            &cursor,
            espeakCHARS_UTF8,
            espeakPHONEMES_IPA
        );

        if (phonemes == nullptr) {
            throwError(
                env,
                "eSpeak phoneme conversion failed."
            );

            return nullptr;
        }

        phonemeOutput.append(phonemes);

        if (cursor == previousCursor) {
            throwError(
                env,
                "eSpeak phonemization did not advance."
            );

            return nullptr;
        }
    }

    if (phonemeOutput.empty()) {
        throwError(
            env,
            "Phonemization returned empty output."
        );

        return nullptr;
    }

    return env->NewStringUTF(
        phonemeOutput.c_str()
    );
}

extern "C" JNIEXPORT void JNICALL
Java_co_parikshit_otakudub_OfflinePhonemizer_nativeShutdown(
    JNIEnv*,
    jclass
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    if (engineInitialized) {
        espeak_Terminate();
        engineInitialized = false;
    }
}

