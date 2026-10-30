"""Acquire a real pretrained DETR person detector and export its ONNX tensors.

This is a generic person detector, not a validated anime character recognizer.
Pins the upstream revision, checks ONNX parity and publishes only model artifacts.
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
from transformers import DetrForObjectDetection, DetrImageProcessor

REPO = "facebook/detr-resnet-50"
out = Path(os.environ.get("MODEL_OUTPUT", "model_artifacts"))
out.mkdir(parents=True, exist_ok=True)
revision = HfApi().model_info(REPO).sha
assert revision and len(revision) == 40
processor = DetrImageProcessor.from_pretrained(REPO, revision=revision)
model = DetrForObjectDetection.from_pretrained(REPO, revision=revision).eval()
assert model.config.id2label[1] == "person", "Unexpected person class mapping"

class Detector(torch.nn.Module):
    def __init__(self, detector):
        super().__init__()
        self.detector = detector
    def forward(self, pixel_values):
        output = self.detector(pixel_values=pixel_values)
        return output.logits, output.pred_boxes

wrapper = Detector(model).eval()
# Fixed 800x800 inference contract, deliberately not claimed to be phone-optimised.
dummy = torch.zeros(1, 3, 800, 800, dtype=torch.float32)
target = out / "detr_resnet50_person.onnx"
with torch.no_grad():
    expected = wrapper(dummy)
    torch.onnx.export(wrapper, (dummy,), str(target),
                      input_names=["pixel_values"],
                      output_names=["class_logits", "normalized_boxes"],
                      opset_version=17, dynamo=False)
onnx.checker.check_model(str(target))
session = ort.InferenceSession(str(target), providers=["CPUExecutionProvider"])
actual = session.run(None, {"pixel_values": dummy.numpy()})
for got, wanted in zip(actual, expected):
    np.testing.assert_allclose(got, wanted.numpy(), rtol=2e-3, atol=2e-4)
assert actual[0].shape == (1, 100, 92)
assert actual[1].shape == (1, 100, 4)
sha = hashlib.sha256(target.read_bytes()).hexdigest()
manifest = {
    "schema": "otakudub_specialist_model_v1",
    "role": "character_detector",
    "model_id": REPO,
    "upstream_revision": revision,
    "model_name": target.name,
    "sha256": sha,
    "rights_basis": "apache-2.0",
    "rights_receipt": "https://huggingface.co/facebook/detr-resnet-50",
    "preprocessing_id": "detr_rgb_800_square_imagenet_v1",
    "inputs": ["pixel_values"],
    "outputs": ["class_logits", "normalized_boxes"],
    "input_shape": [1, 3, 800, 800],
    "output_shapes": [[1, 100, 92], [1, 100, 4]],
    "person_class_id": 1,
    "onnx_cpu_equivalence_checked": True,
    "android_device_checked": False,
    "anime_detection_accuracy_checked": False,
    "notes": "General-purpose person proposals only; must reject unsupported anime identities.",
}
(out / "specialist_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
