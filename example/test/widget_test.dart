import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';
import 'package:kumihan_example/main.dart';

void main() {
  testWidgets('example app shows title', (tester) async {
    await tester.pumpWidget(
      KumihanExampleApp(
        samples: <ExampleSample>[
          ExampleSample(
            id: 'aozora',
            label: '青空形式',
            document: const KumihanAozoraParser(
              title: 'Sample',
            ).parse('［＃１字下げ］表示サンプル\n［＃改ページ］\n　以上、表示サンプルでした。'),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Kumihan'), findsOneWidget);
    expect(find.text('青空形式'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
