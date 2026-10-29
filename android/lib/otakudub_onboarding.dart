import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingAgreementVersion = 'blackheart_otakudub_terms_v1_2026_10';
const onboardingAgreement = '''
OTAKUDUB — USER AGREEMENT AND IMPORTANT COPYRIGHT NOTICE

1. Welcome and purpose
OtakuDub is an AI-assisted dubbing platform presented by Blackheart. Its goal is to help users organise video production, analyse source material, prepare scripts, adapt dialogue, coordinate character voices, align performances, and review audiovisual results. Features may be experimental, incomplete, unavailable, or subject to further testing. A successful export does not guarantee that a video is accurate, professionally approved, or legally cleared for publication. Read this notice carefully before proceeding.

2. Your responsibility for source material
You must have the rights or necessary permission to import, reproduce, translate, adapt, dub, store, or otherwise process any video, soundtrack, script, character reference, or other material you provide. Copyright in an anime, its dialogue, animation, music, and underlying work usually belongs to third-party rights holders. Buying an episode, holding a streaming subscription, finding a clip online, or purchasing an OtakuDub subscription does not by itself give you permission to create or distribute a derivative work. Private experimentation may also be subject to applicable law. OtakuDub does not grant rights to any third-party anime.

3. Publication and sharing
Do not publish, upload, sell, broadcast, monetise, or share dubbed videos unless you have all permissions required for that specific use, including any relevant rights in the original audiovisual work, adaptation, translation, music, performances, and distribution. If you share a dubbed video without permission, you do so at your own legal and financial risk, subject to applicable law. Blackheart cannot provide a licence on behalf of an anime copyright owner and does not promise that a platform will accept or monetise your output. You are responsible for responding to legitimate rights-holder notices and observing the rules of any distribution service.

4. Commercial use and proposed revenue-sharing arrangement
A personal or lifetime OtakuDub purchase covers only the software access expressly described in its offer. It does not include an unrestricted commercial exploitation licence, ownership of the software, or any third-party anime rights. If you obtain all required permissions from the relevant anime rights holders and wish to use OtakuDub-generated dubbing commercially, Blackheart's proposed commercial programme requires a separate written commercial agreement providing Blackheart with fifty percent (50%) of the defined net profit attributable to that commercial dubbing project, including where you previously purchased a lifetime offer. This notice does not itself conclude that separate revenue-sharing agreement or authorise commercial distribution. The signed agreement must specify revenue sources, permitted deductions, accounting periods, reporting, audit arrangements, taxes, refunds, territory, duration, and termination. Do not begin commercial use in reliance on this notice alone. Contact Blackheart to negotiate and execute the applicable agreement before commercial release.

5. Accuracy and review
Automated transcription, anime recognition, scene interpretation, speaker attribution, translation, casting, speech synthesis, timing, and mixing can make mistakes. In particular, a system may misidentify a character, omit dialogue, mistranslate meaning, assign the wrong voice, or generate speech that does not match the intended emotion. Inspect original and dubbed material, review warnings, and correct errors before relying on an output. Where a department has not been independently verified, a preview, progress indicator, or export must not be interpreted as certification.

6. Content and acceptable use
Use OtakuDub lawfully and respect creators, performers, rights holders, and other users. Do not present an AI-generated voice or performance as a real person's authorised recording where that would be misleading or unlawful. Do not remove ownership notices, misrepresent a licence, fabricate permissions, or use the service to violate privacy or another person's rights. Any reference database or locally imported model should be used only within the rights and licence conditions applicable to it. You remain responsible for materials and outputs under your control.

7. Data and local operation
OtakuDub is being developed around an offline production workflow. Some optional integrations or later releases may have separate disclosures. Review permissions and any notices before enabling them. Keep copies of important projects and source files. App updates, device storage problems, interruptions, model incompatibility, or operating-system restrictions may affect local files or unfinished production. The app may save acceptance of this agreement on your device so that the introduction is not repeated on every launch. Clearing app data or installing a revised agreement may require acceptance again.

8. Model and feature availability
Models, reference indexes, and production departments may require additional local installation, validation, sufficient storage, or supported hardware. Availability varies by build. A feature shown in the interface may be locked until it has passed independent quality checks. Blackheart may revise implementation, safety checks, supported languages, and compatibility in future releases. Neither the interface nor promotional descriptions should be taken as a promise that all planned features are already operational.

9. Payments, lifetime access, and separate rights
Any lifetime offer must be interpreted according to its published purchase terms and applicable consumer law. It is not a purchase of Blackheart's intellectual property, a waiver of the separately negotiated commercial revenue-sharing programme, or a licence from third-party rights holders. Any actual commercial arrangement must be documented separately and should be reviewed before payment or distribution. Nothing in this notice excludes mandatory statutory rights or remedies that cannot lawfully be excluded.

10. Disputes and legal review
Copyright, contract, consumer, and privacy rules differ by jurisdiction. If you are unsure whether your intended use is permitted, seek permission from the relevant rights holder or qualified legal advice before publishing. If you are under the age required to enter a binding contract in your jurisdiction, obtain assistance from a parent or legal guardian. The proposed commercial profit-sharing provision should be reviewed by qualified counsel before launch and before Blackheart relies on it. Invalid or unenforceable language should not be interpreted as removing rights granted by applicable law.

11. Your acknowledgement
By selecting Agree and Continue, you acknowledge that you have read this notice, understand that OtakuDub does not supply anime distribution rights, and agree to use the software responsibly subject to applicable law. You also acknowledge that a separate written commercial agreement is required for the proposed fifty-percent net-profit arrangement; selecting this button does not by itself sign that separate agreement. If you do not agree, do not proceed. You can revisit the published terms and any revised notices when available.

Blackheart presents OtakuDub — Your Anime. Your Language.
''';

class OtakuDubOnboarding extends StatefulWidget {
  const OtakuDubOnboarding({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override
  State<OtakuDubOnboarding> createState() => _OtakuDubOnboardingState();
}

class _OtakuDubOnboardingState extends State<OtakuDubOnboarding>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool accepted = false;
  bool intro = false;
  late final AnimationController animation;
  Timer? clock;
  int elapsed = 0;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getString('accepted_agreement_version') == onboardingAgreementVersion) {
      widget.onFinished();
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _accept() async {
    if (!accepted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accepted_agreement_version', onboardingAgreementVersion);
    if (!mounted) return;
    setState(() { intro = true; elapsed = 0; });
    animation.forward(from: 0);
    clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (elapsed >= 19) { timer.cancel(); widget.onFinished(); return; }
      setState(() => elapsed++);
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (intro) {
      return Scaffold(body: SafeArea(child: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: animation, builder: (context, child) {
          final value = animation.value;
          return DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF100F19), Color(0xFF4C386E), Color(0xFF181324)])),
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(angle: value * 1.3, child: Transform.scale(
                scale: 0.8 + value * 1.8,
                child: Icon(Icons.auto_awesome, size: 260,
                  color: const Color(0xFFB9A2F4).withValues(alpha: .15)))),
              Opacity(opacity: (value * 6).clamp(0.0, 1.0), child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('BLACKHEART', style: TextStyle(fontSize: 17, letterSpacing: 5,
                    fontWeight: FontWeight.w900, color: Color(0xFFDDCFFF))),
                  const SizedBox(height: 12),
                  const Text('PRESENTS', style: TextStyle(letterSpacing: 4, color: Colors.white70)),
                  const SizedBox(height: 30),
                  Transform.scale(scale: .85 + value * .15, child: const Icon(
                    Icons.play_circle_fill_rounded, size: 88, color: Color(0xFFB9A2F4))),
                  const SizedBox(height: 20),
                  const Text('OTAKUDUB', style: TextStyle(fontSize: 42,
                    fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  const Text('YOUR ANIME. YOUR LANGUAGE.',
                    style: TextStyle(letterSpacing: 2, color: Color(0xFFDDCFFF))),
                  const SizedBox(height: 32),
                  const Text('AN AI DUBBING PLATFORM',
                    style: TextStyle(color: Colors.white70, letterSpacing: 2)),
                ])),
            ]));
        })),
        Positioned(left: 28, right: 28, bottom: 38, child: Column(children: [
          LinearProgressIndicator(value: animation.value, color: const Color(0xFFB9A2F4)),
          const SizedBox(height: 12),
          Text(elapsed < 10 ? 'Introduction · Skip available in ${10 - elapsed}s'
              : 'Blackheart · OtakuDub', style: const TextStyle(color: Colors.white70)),
          if (elapsed >= 10) Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: widget.onFinished, child: const Text('SKIP INTRO'))),
        ])),
      ])));
    }
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child:
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('BLACKHEART  /  OTAKUDUB', style: TextStyle(
          color: Color(0xFFB9A2F4), letterSpacing: 2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Agreement & Copyright Notice', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Please read before using OtakuDub. Commercial use requires a separate written agreement.',
          style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        Expanded(child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF24202F),
            borderRadius: BorderRadius.circular(14)),
          child: const SingleChildScrollView(child: SelectableText(onboardingAgreement,
            style: TextStyle(height: 1.55, fontSize: 13))))),
        CheckboxListTile(value: accepted, onChanged: (value) =>
          setState(() => accepted = value ?? false),
          title: const Text('I have read and agree to the notice', style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading),
        FilledButton(onPressed: accepted ? _accept : null,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB9A2F4),
            foregroundColor: const Color(0xFF101014)),
          child: const Text('AGREE AND CONTINUE')),
      ]))));
  }
}
