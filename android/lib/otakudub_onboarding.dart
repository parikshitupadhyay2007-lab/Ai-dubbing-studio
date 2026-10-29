import 'dart:async';
import 'otakudub_agreement.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingAgreementVersion = otakuDubAgreementVersion;
const onboardingAgreement = otakuDubAgreement;

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
  bool finishing = false;
  SharedPreferences? preferences;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    preferences = prefs;
    if (prefs.getString('accepted_agreement_version') == onboardingAgreementVersion) {
      if (prefs.getBool('intro_completed_$onboardingAgreementVersion') == true) {
        widget.onFinished();
      } else {
        _startIntro();
      }
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _accept() async {
    if (!accepted) return;
    final saved = await preferences!.setString('accepted_agreement_version', onboardingAgreementVersion);
    if (!mounted || !saved) return;
    _startIntro();
  }

  void _startIntro() {
    if (!mounted) return;
    setState(() { loading = false; intro = true; elapsed = 0; });
    animation.forward(from: 0);
    clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (elapsed >= 19) { timer.cancel(); _finishIntro(); return; }
      setState(() => elapsed++);
    });
  }

  Future<void> _finishIntro() async {
    if (finishing) return;
    finishing = true;
    clock?.cancel();
    final saved = await preferences!.setBool('intro_completed_$onboardingAgreementVersion', true);
    if (mounted && saved) widget.onFinished();
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
            onPressed: elapsed >= 10 && !finishing ? _finishIntro : null, child: const Text('SKIP INTRO'))),
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
