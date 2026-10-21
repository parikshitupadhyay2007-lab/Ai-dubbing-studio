#include <jni.h>
#include <android/log.h>

#include <algorithm>
#include <mutex>
#include <string>
#include <vector>

#include "llama.h"

#define LOG_TAG "OtakuDubNative"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

std::mutex engine_mutex;

llama_model* model = nullptr;
llama_context* context = nullptr;

std::string to_string(JNIEnv* env, jstring value) {
    if (value == nullptr) return "";

    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) return "";

    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);

    return result;
}

void release_engine() {
    if (context != nullptr) {
        llama_free(context);
        context = nullptr;
    }

    if (model != nullptr) {
        llama_model_free(model);
        model = nullptr;
    }
}

} // namespace

extern "C"
JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeLoadModel(
    JNIEnv* env,
    jobject,
    jstring modelPath
) {
    std::lock_guard<std::mutex> lock(engine_mutex);

    release_engine();

    std::string path = to_string(env, modelPath);

    if (path.empty()) {
        LOGE("Model path is empty");
        return JNI_FALSE;
    }

    llama_backend_init();

    llama_model_params modelParams =
        llama_model_default_params();

    modelParams.n_gpu_layers = 0;
    modelParams.use_mmap = true;

    model = llama_model_load_from_file(
        path.c_str(),
        modelParams
    );

    if (model == nullptr) {
        LOGE("Failed to load GGUF model");
        return JNI_FALSE;
    }

    llama_context_params contextParams =
        llama_context_default_params();

    contextParams.n_ctx = 2048;
    contextParams.n_batch = 512;
    contextParams.n_threads = 4;
    contextParams.n_threads_batch = 4;

    context = llama_init_from_model(
        model,
        contextParams
    );

    if (context == nullptr) {
        LOGE("Failed to create llama context");
        release_engine();
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeGenerate(
    JNIEnv* env,
    jobject,
    jstring promptText,
    jint maxTokens
) {
    std::lock_guard<std::mutex> lock(engine_mutex);

    if (model == nullptr || context == nullptr) {
        return env->NewStringUTF(
            "ERROR: OtakuMind model is not loaded."
        );
    }

    std::string prompt = to_string(env, promptText);

    if (prompt.empty()) {
        return env->NewStringUTF("");
    }

    const llama_vocab* vocab =
        llama_model_get_vocab(model);

    int required = -llama_tokenize(
        vocab,
        prompt.c_str(),
        static_cast<int>(prompt.size()),
        nullptr,
        0,
        true,
        true
    );

    if (required <= 0 || required >= 1800) {
        return env->NewStringUTF(
            "ERROR: Invalid or excessively long prompt."
        );
    }

    std::vector<llama_token> tokens(required);

    int tokenCount = llama_tokenize(
        vocab,
        prompt.c_str(),
        static_cast<int>(prompt.size()),
        tokens.data(),
        required,
        true,
        true
    );

    if (tokenCount <= 0) {
        return env->NewStringUTF(
            "ERROR: Tokenization failed."
        );
    }

    llama_memory_clear(
        llama_get_memory(context),
        true
    );

    llama_batch batch = llama_batch_get_one(
        tokens.data(),
        tokenCount
    );

    if (llama_decode(context, batch) != 0) {
        return env->NewStringUTF(
            "ERROR: Prompt evaluation failed."
        );
    }

    llama_sampler_chain_params samplerParams =
        llama_sampler_chain_default_params();

    llama_sampler* sampler =
        llama_sampler_chain_init(samplerParams);

    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_temp(0.7f)
    );

    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_dist(1234)
    );

    std::string output;

    const int limit = std::clamp(
        static_cast<int>(maxTokens),
        1,
        512
    );

    for (int i = 0; i < limit; ++i) {
        llama_token token =
            llama_sampler_sample(sampler, context, -1);

        if (llama_vocab_is_eog(vocab, token)) {
            break;
        }

        llama_sampler_accept(sampler, token);

        char piece[256];

        int length = llama_token_to_piece(
            vocab,
            token,
            piece,
            sizeof(piece),
            0,
            true
        );

        if (length > 0) {
            output.append(piece, length);
        }

        llama_batch nextBatch =
            llama_batch_get_one(&token, 1);

        if (llama_decode(context, nextBatch) != 0) {
            LOGE("Token evaluation failed");
            break;
        }
    }

    llama_sampler_free(sampler);

    return env->NewStringUTF(output.c_str());
}

extern "C"
JNIEXPORT void JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeRelease(
    JNIEnv*,
    jobject
) {
    std::lock_guard<std::mutex> lock(engine_mutex);
    release_engine();
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeIsLoaded(
    JNIEnv*,
    jobject
) {
    std::lock_guard<std::mutex> lock(engine_mutex);

    return model != nullptr && context != nullptr
        ? JNI_TRUE
        : JNI_FALSE;
}
