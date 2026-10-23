
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

constexpr int CONTEXT_SIZE = 2048;
constexpr int MAX_GENERATION = 512;

std::mutex engineMutex;
llama_model* model = nullptr;
llama_context* context = nullptr;

std::string fromJava(JNIEnv* env, jstring value) {
    if (!value) return "";

    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (!chars) return "";

    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}

jstring error(JNIEnv* env, const char* message) {
    LOGE("%s", message);
    return env->NewStringUTF(message);
}

void releaseEngine() {
    if (context) {
        llama_free(context);
        context = nullptr;
    }

    if (model) {
        llama_model_free(model);
        model = nullptr;
    }
}

std::string tokenPiece(
    const llama_vocab* vocab,
    llama_token token
) {
    std::vector<char> buffer(256);

    int length = llama_token_to_piece(
        vocab,
        token,
        buffer.data(),
        static_cast<int>(buffer.size()),
        0,
        true
    );

    if (length < 0) {
        buffer.resize(static_cast<size_t>(-length));

        length = llama_token_to_piece(
            vocab,
            token,
            buffer.data(),
            static_cast<int>(buffer.size()),
            0,
            true
        );
    }

    if (length <= 0) return "";

    return std::string(buffer.data(), length);
}

} // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeLoadModel(
    JNIEnv* env,
    jobject,
    jstring modelPath
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    releaseEngine();

    const std::string path = fromJava(env, modelPath);

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

    if (!model) {
        LOGE("Failed to load GGUF model");
        return JNI_FALSE;
    }

    llama_context_params contextParams =
        llama_context_default_params();

    contextParams.n_ctx = CONTEXT_SIZE;
    contextParams.n_batch = 512;
    contextParams.n_threads = 4;
    contextParams.n_threads_batch = 4;

    context = llama_init_from_model(
        model,
        contextParams
    );

    if (!context) {
        LOGE("Failed to initialize inference context");
        releaseEngine();
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeGenerate(
    JNIEnv* env,
    jobject,
    jstring promptText,
    jint maxTokens
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    if (!model || !context) {
        return error(env, "ERROR: OtakuMind model is not loaded.");
    }

    const std::string userPrompt = fromJava(env, promptText);

    if (userPrompt.empty()) {
        return env->NewStringUTF("");
    }

    // Use the model's own GGUF chat template, not an improvised raw
    // completion. An absent or unsupported template must fail closed.
    const char* chatTemplate = llama_model_chat_template(model, nullptr);
    if (!chatTemplate || !*chatTemplate) {
        return error(env, "ERROR: Model has no chat template.");
    }
    const llama_chat_message messages[] = {
        {"system", "You are OtakuMind, an accurate offline dialogue translator. Follow the user's output format. Never output internal reasoning."},
        {"user", userPrompt.c_str()}
    };
    const int32_t formattedSize = llama_chat_apply_template(
        chatTemplate, messages, 2, true, nullptr, 0
    );
    if (formattedSize <= 0 || formattedSize > 32768) {
        return error(env, "ERROR: Unsupported or oversized model chat template.");
    }
    std::vector<char> formatted(static_cast<size_t>(formattedSize) + 1, '\\0');
    const int32_t actualSize = llama_chat_apply_template(
        chatTemplate, messages, 2, true,
        formatted.data(), static_cast<int32_t>(formatted.size())
    );
    if (actualSize != formattedSize) {
        return error(env, "ERROR: Could not apply model chat template.");
    }
    const std::string prompt(formatted.data(), static_cast<size_t>(actualSize));

    const llama_vocab* vocab =
        llama_model_get_vocab(model);

    const int requestedTokens = std::clamp(
        static_cast<int>(maxTokens),
        1,
        MAX_GENERATION
    );

    const int required = -llama_tokenize(
        vocab,
        prompt.c_str(),
        static_cast<int>(prompt.size()),
        nullptr,
        0,
        true,
        true
    );

    if (required <= 0) {
        return error(env, "ERROR: Invalid prompt.");
    }

    if (required + requestedTokens > CONTEXT_SIZE) {
        return error(
            env,
            "ERROR: Prompt exceeds available context space."
        );
    }

    std::vector<llama_token> tokens(required);

    const int tokenCount = llama_tokenize(
        vocab,
        prompt.c_str(),
        static_cast<int>(prompt.size()),
        tokens.data(),
        static_cast<int>(tokens.size()),
        true,
        true
    );

    if (tokenCount <= 0) {
        return error(env, "ERROR: Tokenization failed.");
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
        return error(env, "ERROR: Prompt evaluation failed.");
    }

    llama_sampler_chain_params samplerParams =
        llama_sampler_chain_default_params();

    llama_sampler* sampler =
        llama_sampler_chain_init(samplerParams);

    if (!sampler) {
        return error(env, "ERROR: Sampler initialization failed.");
    }

    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_temp(0.2f)
    );

    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_dist(1234)
    );

    std::string output;

    for (int i = 0; i < requestedTokens; ++i) {
        const llama_token token =
            llama_sampler_sample(sampler, context, -1);

        if (llama_vocab_is_eog(vocab, token)) {
            break;
        }

        llama_sampler_accept(sampler, token);

        output += tokenPiece(vocab, token);

        // No additional decode is necessary after the final token.
        if (i + 1 == requestedTokens) {
            break;
        }

        llama_token nextToken = token;

        llama_batch nextBatch =
            llama_batch_get_one(&nextToken, 1);

        if (llama_decode(context, nextBatch) != 0) {
            LOGE("Generation stopped: token evaluation failed");
            break;
        }
    }

    llama_sampler_free(sampler);

    return env->NewStringUTF(output.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeRelease(
    JNIEnv*,
    jobject
) {
    std::lock_guard<std::mutex> lock(engineMutex);
    releaseEngine();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_co_parikshit_otakudub_MainActivity_nativeIsLoaded(
    JNIEnv*,
    jobject
) {
    std::lock_guard<std::mutex> lock(engineMutex);

    return (model && context) ? JNI_TRUE : JNI_FALSE;
}
