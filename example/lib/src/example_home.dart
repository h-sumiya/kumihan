import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart';

import 'example_controls_dialog.dart';
import 'example_data.dart';
import 'example_models.dart';
import 'example_theme_utils.dart';

class KumihanExampleHome extends StatefulWidget {
  const KumihanExampleHome({super.key, required this.samples});

  final List<ExampleSample> samples;

  @override
  State<KumihanExampleHome> createState() => _KumihanExampleHomeState();
}

class _KumihanExampleHomeState extends State<KumihanExampleHome> {
  // ── KumihanCanvas に渡す状態 ──────────────────────────────────────
  final KumihanController _controller = KumihanController();
  final AssetImage _coverImage = const AssetImage('assets/cover.png');
  KumihanLayoutData _layout = const KumihanLayoutData();
  late KumihanThemeData _draftTheme;
  // ─────────────────────────────────────────────────────────────────

  late String _selectedSampleId;
  late List<ExampleThemePreset> _themePresets;
  late String _selectedThemePresetId;
  int _nextCustomThemeId = 1;
  bool _controlsOpen = false;

  final TextEditingController _themeNameController = TextEditingController();
  final TextEditingController _paperColorController = TextEditingController();
  final TextEditingController _textColorController = TextEditingController();
  final TextEditingController _linkColorController = TextEditingController();
  final TextEditingController _internalLinkColorController =
      TextEditingController();
  final TextEditingController _captionColorController = TextEditingController();
  final TextEditingController _rubyColorController = TextEditingController();

  ExampleSample get _selectedSample =>
      widget.samples.firstWhere((s) => s.id == _selectedSampleId);

  ExampleThemePreset get _selectedThemePreset =>
      _themePresets.firstWhere((p) => p.id == _selectedThemePresetId);

  String get _selectedTextureId => textureIdFor(_draftTheme.paperTexture);

  bool get _selectedThemeIsCustom => !_selectedThemePreset.builtIn;

  @override
  void initState() {
    super.initState();
    _selectedSampleId = widget.samples.first.id;
    _themePresets = List<ExampleThemePreset>.of(builtinThemePresets);
    _selectedThemePresetId = _themePresets.first.id;
    _draftTheme = _themePresets.first.theme;
    _syncThemeEditors(name: _themePresets.first.label);
  }

  @override
  void dispose() {
    _controller.dispose();
    _themeNameController.dispose();
    _paperColorController.dispose();
    _textColorController.dispose();
    _linkColorController.dispose();
    _internalLinkColorController.dispose();
    _captionColorController.dispose();
    _rubyColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shellTheme = buildExampleShellTheme(_draftTheme);
    final panelColor = blendExampleColor(
      _draftTheme.paperColor,
      shellTheme.colorScheme.surface,
      _draftTheme.isDark ? 0.18 : 0.62,
    );

    return Theme(
      data: shellTheme,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildViewerArea()),
                  _buildBottomBar(),
                ],
              ),
            ),
            if (_controlsOpen) _buildControlsOverlay(panelColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final snapshot = _controller.snapshot;
        final mode = snapshot.writingMode == KumihanWritingMode.vertical
            ? '縦組み'
            : '横組み';
        final spread = snapshot.spreadMode == KumihanSpreadMode.doublePage
            ? '見開き'
            : '単ページ';
        final page =
            '${snapshot.currentPage + 1} / ${snapshot.totalPages == 0 ? 1 : snapshot.totalPages}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Text(
                'Kumihan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                children: [
                  _InfoPill(value: _selectedSample.label),
                  _InfoPill(value: mode),
                  _InfoPill(value: spread),
                  _InfoPill(label: 'p', value: page),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewerArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _buildNavButton(
            icon: Icons.chevron_left,
            onPressed: _controller.prev,
            tooltip: '前へ',
          ),
          const SizedBox(width: 8),
          // ── KumihanCanvas ──────────────────────────────────────────
          Expanded(child: _buildKumihanCanvas()),
          // ──────────────────────────────────────────────────────────
          const SizedBox(width: 8),
          _buildNavButton(
            icon: Icons.chevron_right,
            onPressed: _controller.next,
            tooltip: '次へ',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // KumihanCanvas の使い方はこのメソッドを参照してください。
  // controller / document / theme / layout の 4 つが主要パラメータです。
  Widget _buildKumihanCanvas() {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _draftTheme.textColor.withValues(
              alpha: _draftTheme.isDark ? 0.28 : 0.16,
            ),
            blurRadius: 24,
            offset: const Offset(2, 8),
          ),
        ],
      ),
      child: KumihanCanvas(
        controller: _controller,
        coverImage: _coverImage,
        document: _selectedSample.document,
        imageLoader: loadExampleImage,
        layout: _layout,
        theme: _draftTheme,
        onExternalOpen: (value) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('外部リンクを開く'),
              content: Text('URL: $value'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        foregroundColor: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: _openControls,
            icon: const Icon(Icons.tune),
            label: const Text('設定'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(Color panelColor) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeControls,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: _draftTheme.isDark ? 0.56 : 0.34,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ExampleControlsDialog(
                  controller: _controller,
                  samples: widget.samples,
                  selectedSampleId: _selectedSampleId,
                  themePresets: _themePresets,
                  selectedThemePresetId: _selectedThemePresetId,
                  selectedTextureId: _selectedTextureId,
                  selectedThemeIsCustom: _selectedThemeIsCustom,
                  fontSize: _layout.fontSize,
                  pageMarginScale: _layout.pageMarginScale,
                  draftTheme: _draftTheme,
                  panelColor: panelColor,
                  themeNameController: _themeNameController,
                  paperColorController: _paperColorController,
                  textColorController: _textColorController,
                  linkColorController: _linkColorController,
                  internalLinkColorController: _internalLinkColorController,
                  captionColorController: _captionColorController,
                  rubyColorController: _rubyColorController,
                  textureOptions: examplePaperTextureOptions,
                  onClose: _closeControls,
                  onSampleChanged: _selectSample,
                  onSelectThemePreset: _selectThemePreset,
                  onSelectTexture: _selectTexture,
                  onSaveThemePreset: _saveThemePreset,
                  onDeleteTheme: _deleteSelectedTheme,
                  onFontSizeChanged: (value) {
                    setState(() {
                      _layout = _layout.copyWith(fontSize: value);
                    });
                  },
                  onPageMarginScaleChanged: (value) {
                    setState(() {
                      _layout = _layout.copyWith(pageMarginScale: value);
                    });
                  },
                  onPaperColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.paperColor,
                      apply: (color) =>
                          _draftTheme = _draftTheme.copyWith(paperColor: color),
                    );
                  },
                  onTextColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.textColor,
                      apply: (color) =>
                          _draftTheme = _draftTheme.copyWith(textColor: color),
                    );
                  },
                  onLinkColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.linkColor,
                      apply: (color) =>
                          _draftTheme = _draftTheme.copyWith(linkColor: color),
                    );
                  },
                  onInternalLinkColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.internalLinkColor,
                      apply: (color) => _draftTheme = _draftTheme.copyWith(
                        internalLinkColor: color,
                      ),
                    );
                  },
                  onCaptionColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.captionColor,
                      apply: (color) => _draftTheme = _draftTheme.copyWith(
                        captionColor: color,
                      ),
                    );
                  },
                  onRubyColorChanged: (value) {
                    _updateColor(
                      value,
                      currentColor: _draftTheme.rubyColor,
                      apply: (color) =>
                          _draftTheme = _draftTheme.copyWith(rubyColor: color),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openControls() {
    setState(() {
      _controlsOpen = true;
    });
  }

  void _closeControls() {
    setState(() {
      _controlsOpen = false;
    });
  }

  void _selectSample(String? value) {
    if (value == null || value == _selectedSampleId) {
      return;
    }
    setState(() {
      _selectedSampleId = value;
    });
    _controller.showFirstPage();
  }

  void _selectThemePreset(String? value) {
    if (value == null || value == _selectedThemePresetId) {
      return;
    }
    _loadPreset(value);
  }

  void _selectTexture(String? value) {
    if (value == null || value == _selectedTextureId) {
      return;
    }
    final texture = textureOptionFor(value);
    setState(() {
      _draftTheme = _draftTheme.copyWith(paperTexture: texture.image);
    });
  }

  void _updateColor(
    String value, {
    required Color currentColor,
    required void Function(Color color) apply,
  }) {
    final parsed = tryParseHexColor(value);
    if (parsed == null || parsed == currentColor) {
      return;
    }
    setState(() {
      apply(parsed);
    });
  }

  void _loadPreset(String presetId) {
    final preset = _themePresets.firstWhere((item) => item.id == presetId);
    setState(() {
      _selectedThemePresetId = preset.id;
      _draftTheme = preset.theme;
      _syncThemeEditors(name: preset.label);
    });
  }

  void _saveThemePreset() {
    final trimmedName = _themeNameController.text.trim();
    final label = trimmedName.isEmpty
        ? 'カスタム $_nextCustomThemeId'
        : trimmedName;
    final shouldOverwrite = _selectedThemeIsCustom;
    final presetId = shouldOverwrite
        ? _selectedThemePresetId
        : 'custom_${_nextCustomThemeId++}';
    final preset = ExampleThemePreset(
      id: presetId,
      label: label,
      theme: _draftTheme,
    );

    setState(() {
      final index = _themePresets.indexWhere((item) => item.id == presetId);
      if (index >= 0) {
        _themePresets[index] = preset;
      } else {
        _themePresets = <ExampleThemePreset>[..._themePresets, preset];
      }
      _selectedThemePresetId = preset.id;
      _syncThemeEditors(name: preset.label);
    });
  }

  void _deleteSelectedTheme() {
    if (!_selectedThemeIsCustom) {
      return;
    }
    setState(() {
      _themePresets = _themePresets
          .where((preset) => preset.id != _selectedThemePresetId)
          .toList(growable: false);
      final fallback = _themePresets.first;
      _selectedThemePresetId = fallback.id;
      _draftTheme = fallback.theme;
      _syncThemeEditors(name: fallback.label);
    });
  }

  void _syncThemeEditors({required String name}) {
    _themeNameController.text = name;
    _paperColorController.text = formatHexColor(_draftTheme.paperColor);
    _textColorController.text = formatHexColor(_draftTheme.textColor);
    _linkColorController.text = formatHexColor(_draftTheme.linkColor);
    _internalLinkColorController.text = formatHexColor(
      _draftTheme.internalLinkColor,
    );
    _captionColorController.text = formatHexColor(_draftTheme.captionColor);
    _rubyColorController.text = formatHexColor(_draftTheme.rubyColor);
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.value, this.label});

  final String? label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label == null ? value : '$label: $value',
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}
