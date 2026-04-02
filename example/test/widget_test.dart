import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan_example/main.dart';

void main() {
  testWidgets('example app shows title', (tester) async {
    await tester.pumpWidget(const KumihanExampleApp());

    await tester.pump();

    expect(find.text('kumihan example'), findsOneWidget);
    expect(find.text('ファイルを選択'), findsOneWidget);
    expect(find.text('DSL'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
