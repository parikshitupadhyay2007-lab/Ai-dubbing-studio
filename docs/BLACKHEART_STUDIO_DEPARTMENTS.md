# Blackheart Virtual Dubbing Studio — Department Contract v1

Status: architecture specification, not a claim of runtime implementation. Owner: OtakuMind (production director).

## Non-negotiable production rules
1. Every department receives versioned inputs and emits a versioned, auditable deliverable with provenance, confidence, errors, and source segment IDs.
2. A department never approves its own deliverable. Its designated downstream reviewer checks the output against upstream evidence, not just the previous department's assertions.
3. Original media, source transcription, timecodes and approved meaning constraints remain immutable. Proposed changes create revisions.
4. Rejected work returns with machine-readable reason codes and a bounded retry budget. Repeated unchanged proposals count as failure, not progress.
5. Unknown or contradictory evidence is recorded as uncertainty. No hallucinated script, character identity, translation, or emotion may be silently promoted to fact.
6. A timing constraint never authorises a change of meaning. If no faithful fit exists, preserve the line, mark unresolved and block professional-ready approval.
7. Online references are optional, provenance-labelled, permission-aware context, never a substitute for the imported media or proof of script rights.
8. Final export approval requires independent end-to-end QC. A technically generated file is not automatically a professional-ready dub.

## Department handoff matrix

| Stage | Department / AI professionals | Required deliverable | Independent evaluator | Rejection route |
| --- | --- | --- | --- | --- |
| 0 | Production Office — OtakuMind director and manager | Project manifest: source, target, rights/usage declarations, media metadata, model readiness, revision log | Intake validator | Return to intake |
| 1 | Research & Continuity — anime researcher | Evidence-linked scene, episode, character and glossary hypotheses; uncertainty flags | Script & Language Department | Research revision or proceed without unverified references |
| 2 | Original Script — transcription specialist | Immutable source-language utterances, timestamps, overlap and confidence, subtitle provenance | Script Supervisor | Retranscribe/flag uncertain span |
| 3 | Translation & Adaptation — professional translator and human-style dialogue writer | Source-grounded meaning record, natural performable target dialogue, distinct alternatives, protected facts/names/negation/intent and scene-appropriate register | Independent Script Supervisor evaluates semantic fidelity AND natural spoken performance | Re-translate/rewrite; no approval for literal-but-robotic or fluent-but-inaccurate dialogue |
| 4 | Script Supervision — semantic and continuity reviewer | Per-line acceptance, meaning/omission/addition/terminology findings and signed script revision | OtakuMind director checks evidence and coverage | Return to Stage 3; unresolved means no approval |
| 5 | Casting & Performance Direction — casting and acting directors | Speaker-to-character evidence, stable voice map, scene-grounded delivery instructions | Script Supervisor checks speaker/scene alignment | Recast/re-direct |
| 6 | Voice Performance — synthesis specialist | Versioned audio takes, voice/model metadata, measured durations, pronunciation checks | ADR Department | Request new take |
| 7 | ADR & Timing — dialogue editor and LipFit engineer | Alignment map, measured fit, approved take IDs, documented adaptation requests | Script Supervisor verifies any wording change; QC checks sync | Return to Stage 3 for wording or Stage 6 for performance |
| 8 | Sound Post-production — dialogue and mixing engineers | Mix stems, soundtrack preservation checks, peak/loudness/artifact measurements | Independent QC | Remix/re-separate |
| 9 | Independent Quality Control — audiovisual reviewer | Full-episode issue ledger covering meaning, casting, acting, timing, completeness and sound | OtakuMind verifies all findings closed and evidence present | Route to responsible department |
| 10 | Delivery — production office | Export, manifest, QC report, unresolved-issue status | Release gate independent of exporter | Block professional-ready release |

## Department 03 — Professional Translation & Dialogue Adaptation

**Mission:** Write the dialogue a real person would naturally speak in the target language, while preserving the original character's actual meaning and dramatic intention. It is neither word-for-word translation nor free rewriting.

Two distinct roles collaborate:
1. **Translator** records the source utterance's meaning, intent, register, relationships, protected names and terms, negation, facts, uncertainty and scene context. The original dialogue is the authority; optional reference material is labelled by provenance.
2. **Dialogue adaptation writer** drafts idiomatic, conversational Hindi or English suitable for the character, situation and intended performance. Use natural sentence structure, contractions or code-switching only where appropriate to character and locale. Avoid stiff calques, generic AI phrasing, needless exposition, and uniformly formal speech.

Required per-line deliverables:
- Original line and timestamps; source meaning record with protected facts and intent.
- Primary natural spoken adaptation and at least one genuinely distinct alternative when duration or performance needs it.
- Character voice/register notes, emotional subtext grounded in the scene, terminology decisions, and explicit uncertainty.
- Estimated performance considerations; actual timing is measured later by Voice Performance and ADR, never inferred solely from character count.

**Two independent acceptance axes:** (A) semantic fidelity: no changed negation, speaker intention, facts, names, relationships, omissions or invented information; (B) human conversational quality: idiomatic, character-consistent, speakable dialogue without robotic literalism. Passing only one axis is a rejection. The Script Supervisor checks source meaning independently and evaluates the adaptation in scene context; ADR checks actual performed timing. Any later LipFit rewrite returns through the same two-axis review. When no faithful natural line fits, mark unresolved instead of distorting the story.

## Structured handoff envelope
Every department artifact must include:
- project_id, segment_ids, department, artifact_type, revision, parent_revision
- input_artifact_ids and original_media/source-time references
- payload, evidence references, confidence and limitations
- reviewer_department, review_status (pending/approved/rejected/unresolved), reason_codes
- tool/model version, generated_at, immutable checksum where available

## Critical cross-department gates
- Translation: form, language and source-copy checks are necessary but insufficient; independent meaning verification must examine negation, names, facts, relationships, intent and omissions. If verification cannot be established, mark unresolved.
- LipFit: adaptation candidates must be meaning-approved before synthesis; use actual generated WAV duration. Unchanged rewrites must not be retried as successful alternatives. Never silently shorten or speed up beyond approved performance limits.
- Casting: metadata or pitch alone cannot certify character identity. Cross-check acoustic speaker evidence with visual and scene evidence; uncertain identities stay uncertain.
- QC: sample checks are useful during work, but full-episode review is required before a professional-ready claim.

## Implementation order
P0: versioned handoff/review state, independent semantic gate, adaptation/ADR rejection loop.
P1: evidence-backed casting and acting review, measured sound and timing QC.
P2: full-episode audiovisual review, release report and director dashboard.

The pipeline may generate a diagnostic preview with unresolved issues, clearly labelled as such; it must not label that preview a professionally approved final dub.
