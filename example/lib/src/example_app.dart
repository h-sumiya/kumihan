import 'package:flutter/material.dart';

import 'example_home.dart';
import 'example_models.dart';

class KumihanExampleApp extends StatelessWidget {
  const KumihanExampleApp({super.key, required this.samples})
    : assert(samples.length > 0);

  final List<ExampleSample> samples;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kumihan Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: KumihanExampleHome(samples: samples),
    );
  }
}
