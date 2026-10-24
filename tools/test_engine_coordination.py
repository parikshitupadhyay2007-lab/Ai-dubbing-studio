"""Static cross-engine contract checks: fail before multi-GB model downloads."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT / path).read_text(encoding="utf-8")
class EngineCoordination(unittest.TestCase):
    def test_supertonic_installer_uses_native_directory(self):
        flutter = source("android/lib/services/offline_engine.dart")
        native = source("android/android/app/src/main/kotlin/co/parikshit/otakudub/MainActivity.kt")
        self.assertIn("invokeMethod<String>('supertonicModelDirectory')", flutter)
        self.assertIn('"supertonicModelDirectory" ->', native)
        self.assertIn('File(filesDir, "supertonic3")', native)
        self.assertIn("await _installSupertonic();", flutter)
        self.assertEqual(flutter.count("Future<void> _installSupertonic()"), 1)
        self.assertEqual(flutter.count("Future<Map<String, dynamic>> synthesize("), 1)
    def test_pipeline_does_not_gate_on_piper(self):
        pipeline = source("android/lib/services/dubbing_pipeline.dart")
        caster = source("android/lib/services/character_voice_caster.dart")
        self.assertNotIn("VoiceCatalog.installedModel(", pipeline)
        self.assertNotIn("VoiceInstallationRegistry", pipeline)
        self.assertIn("VoiceCatalog.supertonicStyle", pipeline)
        self.assertIn("VoiceCatalog.supertonicStyle", caster)
        self.assertIn("director.translateLine", pipeline)
        self.assertIn("director.refineBatch", pipeline)
        self.assertIn("director.verifyBeforeSynthesis", pipeline)
        self.assertIn("speakerId != before.speakerId", source("android/lib/services/otakumind_director.dart"))
        self.assertIn("Synthesis omitted dialogue segments.", pipeline)
    def test_native_four_stage_and_routing(self):
        native = source("android/android/app/src/main/kotlin/co/parikshit/otakudub/MainActivity.kt")
        graph = source("android/android/app/src/main/java/co/parikshit/otakudub/SupertonicReference.java")
        self.assertIn("SupertonicSpeechSynthesizer(", native)
        for stage in ["duration_predictor.onnx", "text_encoder.onnx",
                      "vector_estimator.onnx", "vocoder.onnx"]:
            self.assertIn(stage, graph)
        for method in ['"transcribe" ->', '"identifySpeakers" ->', '"translate" ->',
                       '"refineDialogue" ->', '"synthesize" ->', '"mixDialogue" ->',
                       '"separateSoundtrack" ->', '"mixSoundtrack" ->', '"exportVideo" ->']:
            self.assertIn(method, native)
    def test_release_audits_all_supertonic_files(self):
        workflow = source(".github/workflows/build-apk.yml")
        self.assertIn("audit_supertonic3_assets.py --directory", workflow)
        self.assertIn("audit_supertonic3_assets.py --apk", workflow)
        self.assertIn('cp -a "$BACKUP/java" android/app/src/main/java', workflow)
        self.assertIn("dart analyze --fatal-infos", workflow)
if __name__ == "__main__": unittest.main()
