import 'package:flutter/widgets.dart';

import 'src/example_app.dart';
import 'src/example_data.dart';

export 'src/example_app.dart';
export 'src/example_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KumihanExampleApp(samples: await loadExampleSamples()));
}
