import 'dart:convert';
import 'dart:io';

import 'otakumind_online_research.dart';
import 'production_office.dart';
import 'research_continuity.dart';

/// Coordinates Department 01 without pretending reference metadata proves identity.
class OtakuMindResearchDirector {
  OtakuMindResearchDirector(this.office, {required this.onlineEnabled,
      OtakuMindOnlineResearch? online})
      : online = online ?? OtakuMindOnlineResearch(enabled: onlineEnabled);
  final ProductionOffice office;
  final bool onlineEnabled;
  final OtakuMindOnlineResearch online;

  /// Only a deliberately entered title is transmitted. No dialogue, frames,
  /// file paths, hashes, episode footage, or extracted user content is sent.
  Future<Map<String, dynamic>> run({
    required IntakeRecord intake,
    required List<SceneEvidence> observedEvidence,
    String? userProvidedAnimeTitle,
  }) async {
    final department = ResearchContinuity(office);
    final manifest = await department.createResearchManifest(intake, observedEvidence);
    Map<String, dynamic>? reference;
    String researchState = 'offline_no_reference';
    if (onlineEnabled && userProvidedAnimeTitle != null &&
        userProvidedAnimeTitle.trim().isNotEmpty) {
      try {
        reference = await online.searchAnime(userProvidedAnimeTitle);
        researchState = 'unverified_external_reference';
      } catch (error) {
        researchState = 'network_lookup_failed';
        // Failure remains visible, but does not corrupt the local artifact.
        reference = {'error': error.runtimeType.toString()};
      }
    }
    final receipt = Map<String, dynamic>.from(manifest['upstream_handoff'] as Map);
    if (!await office.verifyHandoff(intake, receipt)) {
      throw StateError('Upstream intake changed during research');
    }
    final revised = <String, dynamic>{
      ...manifest,
      'internet_enabled': onlineEnabled,
      'internet_research_status': researchState,
      if (reference != null) 'external_reference': reference,
      'identity_claims': <Object>[],
      'model_coverage': {
        'anime_recognition': 'unavailable',
        'scene_segmentation': 'unavailable',
        'visual_understanding': 'unavailable',
        'character_recognition': 'unavailable',
        'context_research': reference != null && !reference.containsKey('error')
            ? 'metadata_only' : 'unavailable',
        'continuity_intelligence': 'validation_only',
      },
      'approved': false,
      'status': 'awaiting_models_and_review',
    };
    final file = File('${(await office.root).path}/${intake.id}/research_manifest.json');
    final temp = File('${file.path}.part');
    await temp.writeAsString(jsonEncode(revised), flush: true);
    if (!await office.verifyHandoff(intake, receipt)) {
      await temp.delete();
      throw StateError('Upstream intake changed before research commit');
    }
    await temp.rename(file.path);
    return revised;
  }
}
