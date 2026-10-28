# Eleven-department gated replacement architecture

This implements the **orchestration contract and handoff gates**, not the eleven production AI engines. A department reaches 100% only once its actual output artifact passes *every* required check and the next department independently approves that exact artifact digest. The orchestration cannot bypass a failed check, skip a department, reuse stale approval or mark a full job complete before Delivery receives external acceptance.

| Order | Department | Independently reviewed by |
|---|---|---|
| 00 | Production Office | 01 Research & Continuity |
| 01 | Research & Continuity | 02 Original Script |
| 02 | Original Script | 03 Translation & Adaptation |
| 03 | Translation & Adaptation | 04 Script Supervision |
| 04 | Script Supervision | 05 Casting & Performance Direction |
| 05 | Casting & Performance Direction | 06 Voice Performance |
| 06 | Voice Performance | 07 ADR & Timing |
| 07 | ADR & Timing | 08 Sound Post-production |
| 08 | Sound Post-production | 09 Quality Control |
| 09 | Quality Control | 10 Delivery |
| 10 | Delivery | External acceptance |

For Department 03, checks require *both* original semantic intent and natural, conversational, performable Hindi/English dialogue, plus character consistency and duration constraints. Department 04 must perform independent semantic and fluency review; matching duration never excuses mistranslation. Any failure returns work to the responsible department; progression is blocked.

Engine adapters, model manifests, actual media validation and on-device Android integration must be built and demonstrated separately. A synthetic passing check is **not proof of actual output quality**. Preserve legacy app entrypoints until verified integration passes. Run orchestration tests with `python -m unittest discover -s tests -p 'test_departmental_pipeline.py'` from `backend`.
