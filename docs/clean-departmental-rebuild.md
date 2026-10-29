# OtakuDub clean departmental rebuild (feature branch only)

The existing Flutter visual UI, project import/library, stored projects, branding, and Models screen are preserved. The Studio `generate()` entry point is disconnected from the legacy `DubbingPipeline`: it displays a rebuild message and does not execute the old engines. Existing project data is not deleted.

The new **Departments** tab is a read-only inspection surface. It shows eleven departments and separately labels historical saved transcript, translation and speaker assignments as **legacy/unverified**. No previous result can count as replacement-department approval.

## Acceptance sequence
Work only on one department at a time, starting with 00 Production Office. For every department:
1. State inputs, immutable output/artifact schema and expected failure modes.
2. Implement the real offline engine; prove model and resource provenance.
3. Implement an independent evaluator (not the producing model's own judgment).
4. Add unit, integration, adversarial and real-device tests and record results.
5. Test the handoff with all *already approved* prior departments, including resume and stale-checkpoint rejection.
6. Connect approved immutable outputs to the Departments page; keep missing evidence explicitly pending.
7. Advance only after measured acceptance criteria pass; no claim of perfect performance.

Future inspector records should include: timestamps, original and adapted dialogue; alternatives; source evidence and confidence; speaker identity; selected voice; model/version hash; review decision, reasons, retries, audio previews, QC and export status. Do not show fabricated placeholders as real output.

The preexisting backend prototype and native service source remain in Git history/worktree for reference; they are not approved or connected as production implementations. A later dedicated cleanup should remove obsolete code only after asset/build dependencies are inventoried and replacement architecture is tested.

The APK workflow still bundles old models and produces a legacy-era binary; do not call it a completed rebuilt dubbing product.
