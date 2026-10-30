"""Acquire real pretrained text-emotion inference for dialogue-context research.

Text emotion is one evidence channel, NOT vocal performance recognition.
No synthetic model weights or fake classifications are used.
"""
import hashlib
import json
import os
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from huggingface_hub import HfApi
from transformers import AutoModelForSequenceClassification, AutoTokenizer

REPO = "j-hartmann/emotion-english-distilroberta-base"
revision = HfApi().model_info(REPO).sha
assert revision and len(revision) == 40
out = Path(os.environ.get("MODEL_OUTPUT", "model_artifacts"))
out.mkdir(parents=True, exist_ok=True)
tokenizer = AutoTokenizer.from_pretrained(REPO, revision=revision)
model = AutoModelForSequenceClassification.from_pretrained(
    REPO, revision=revision, use_safetensors=True).eval()
class Emotion(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, input_ids, attention_mask):
        return self.m(input_ids=input_ids, attention_mask=attention_mask).logits
wrapper = Emotion(model).eval()
encoded = tokenizer("I am happy to see you.", max_length=64, padding="max_length",
                    truncation=True, return_tensors="pt")
target = out / "dialogue_text_emotion.onnx"
with torch.no_grad():
    expected = wrapper(encoded["input_ids"], encoded["attention_mask"]).numpy()
    torch.onnx.export(wrapper,
        (encoded["input_ids"], encoded["attention_mask"]), str(target),
        input_names=["input_ids", "attention_mask"], output_names=["logits"],
        opset_version=17, dynamo=False)
onnx.checker.check_model(str(target))
actual = ort.InferenceSession(str(target), providers=["CPUExecutionProvider"]).run(
    ["logits"], {k: v.numpy() for k, v in encoded.items()})[0]
np.testing.assert_allclose(actual, expected, rtol=1e-3, atol=1e-4)
assert actual.shape == (1, model.config.num_labels)
sha = hashlib.sha256(target.read_bytes()).hexdigest()
manifest = {
    "schema": "otakudub_specialist_model_v1", "role": "emotion_performance",
    "model_id": REPO, "upstream_revision": revision,
    "model_name": target.name, "sha256": sha,
    "rights_basis": "licensed",
    "rights_receipt": f"https://huggingface.co/{REPO}",
    "preprocessing_id": "distilroberta_dialogue_text_64_v1",
    "inputs": ["input_ids", "attention_mask"], "outputs": ["logits"],
    "input_shape": [1, 64], "output_shape": [1, model.config.num_labels],
    "labels": model.config.id2label,
    "tokenizer": {"vocab_file": "vocab.json", "merges_file": "merges.txt"},
    "onnx_cpu_equivalence_checked": True, "android_device_checked": False,
    "vocal_emotion_verified": False, "professional_accuracy_verified": False,
    "scope": "English dialogue text emotion cue; never assert actual voice delivery",
}
for filename in ("vocab.json", "merges.txt", "tokenizer.json"):
    source = tokenizer.save_pretrained(str(out))
assert (out / "tokenizer.json").exists()
(out / "specialist_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
