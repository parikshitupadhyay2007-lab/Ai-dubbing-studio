"""Acquire publicly licensed DINOv2-S weights and export a single-vector ONNX.
Run in GitHub Actions; never substitutes test data for pretrained weights.
"""
import hashlib
import json
import os
from pathlib import Path

import torch
from huggingface_hub import HfApi
from transformers import AutoImageProcessor, AutoModel

REPO = "facebook/dinov2-small"
out = Path(os.environ.get("MODEL_OUTPUT", "model_artifacts"))
out.mkdir(parents=True, exist_ok=True)
info = HfApi().model_info(REPO)
revision = info.sha
assert revision and len(revision) == 40
processor = AutoImageProcessor.from_pretrained(REPO, revision=revision)
model = AutoModel.from_pretrained(REPO, revision=revision, use_safetensors=True)
model.eval()

class ClsEmbedding(torch.nn.Module):
    def __init__(self, encoder):
        super().__init__()
        self.encoder = encoder

    def forward(self, pixel_values):
        return self.encoder(pixel_values=pixel_values).last_hidden_state[:, 0, :]

wrapper = ClsEmbedding(model).eval()
size = processor.size
height = size.get("height", size.get("shortest_edge"))
width = size.get("width", size.get("shortest_edge"))
assert processor.crop_size.get("height") == processor.crop_size.get("width") == 224, f"Unexpected processor crop: {processor.crop_size}"
assert processor.do_normalize and processor.do_rescale
assert abs(processor.rescale_factor - 1 / 255) < 1e-9
assert processor.do_resize and processor.do_center_crop
assert processor.image_mean and processor.image_std
target = out / "dinov2_small_cls.onnx"
dummy = torch.zeros(1, 3, 224, 224)
with torch.no_grad():
    expected = wrapper(dummy).numpy()
    torch.onnx.export(wrapper, (dummy,), str(target),
        input_names=["pixel_values"], output_names=["embedding"],
        opset_version=17, dynamo=False)
import onnx
import onnxruntime as ort
onnx.checker.check_model(str(target))
session = ort.InferenceSession(str(target), providers=["CPUExecutionProvider"])
actual = session.run(["embedding"], {"pixel_values": dummy.numpy()})[0]
import numpy as np
np.testing.assert_allclose(actual, expected, rtol=1e-3, atol=1e-4)
assert actual.shape == (1, 384)
sha = hashlib.sha256(target.read_bytes()).hexdigest()
manifest = {
    "model_id": REPO, "upstream_revision": revision,
    "license": "apache-2.0",
    "license_source": "https://huggingface.co/facebook/dinov2-small",
    "artifact": target.name, "sha256": sha,
    "input_name": "pixel_values", "input_shape": [1, 3, 224, 224],
    "output_name": "embedding", "output_shape": [1, 384],
    "preprocessing": {
        "resize": size, "center_crop": processor.crop_size,
        "rescale_factor": processor.rescale_factor,
        "mean": processor.image_mean, "std": processor.image_std,
        "layout": "RGB_CHW",
    },
    "onnx_cpu_equivalence_checked": True,
    "android_device_checked": False,
    "anime_identity_accuracy_checked": False,
}
(out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
