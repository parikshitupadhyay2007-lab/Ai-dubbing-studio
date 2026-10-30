import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ai_dubbing_studio/main.dart';

void main() {
  testWidgets('new shell has four tabs and the department tracker is honest', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OtakuShell()));
    expect(find.text('OTAKUDUB'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Departments'), findsOneWidget);
    await tester.tap(find.text('Departments'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 11 verified · 0 valid intakes'), findsOneWidget);
    expect(find.text('READY FOR INTAKE · NO VERIFIED RUN'), findsOneWidget);
    expect(find.text('Production Office'), findsOneWidget);
    await tester.tap(find.text('Production Office'));
    await tester.pumpAndSettle();
    expect(find.text('WORK & ARTIFACTS'), findsWidgets);
    expect(find.text('INDEPENDENT REVIEW'), findsWidgets);
    expect(find.text('ACTUAL RESULTS'), findsWidgets);
    expect(find.text('HANDOFF'), findsWidgets);
  });
}
