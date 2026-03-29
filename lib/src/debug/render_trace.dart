import 'package:flutter/foundation.dart';

import '../kumihan_types.dart';

typedef KumihanRenderCommandSink = void Function(KumihanRenderCommand command);

@immutable
class KumihanRenderTrace {
  const KumihanRenderTrace({
    required this.currentPage,
    required this.writingMode,
    required this.commands,
  });

  final int currentPage;
  final KumihanWritingMode writingMode;
  final List<KumihanRenderCommand> commands;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'currentPage': currentPage,
      'writingMode': writingMode.name,
      'commands': commands.map((command) => command.toJson()).toList(),
    };
  }
}

@immutable
class KumihanRenderCommand {
  const KumihanRenderCommand({
    required this.kind,
    this.role,
    this.text,
    this.translateX = 0,
    this.translateY = 0,
    this.localX = 0,
    this.localY = 0,
    this.width = 0,
    this.height = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.data = const <String, Object?>{},
  });

  final String kind;
  final String? role;
  final String? text;
  final double translateX;
  final double translateY;
  final double localX;
  final double localY;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind,
      if (role != null) 'role': role,
      if (text != null) 'text': text,
      'translateX': translateX,
      'translateY': translateY,
      'localX': localX,
      'localY': localY,
      'width': width,
      'height': height,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
      if (data.isNotEmpty) 'data': data,
    };
  }
}
