import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumihan/kumihan.dart';

import 'example_models.dart';

class ExampleControlsDialog extends StatelessWidget {
  const ExampleControlsDialog({
    super.key,
    required this.controller,
    required this.samples,
    required this.selectedSampleId,
    required this.themePresets,
    required this.selectedThemePresetId,
    required this.selectedTextureId,
    required this.selectedThemeIsCustom,
    required this.fontSize,
    required this.pagePadding,
    required this.showTitle,
    required this.showPageNumber,
    required this.draftTheme,
    required this.panelColor,
    required this.themeNameController,
    required this.paperColorController,
    required this.textColorController,
    required this.linkColorController,
    required this.internalLinkColorController,
    required this.captionColorController,
    required this.rubyColorController,
    required this.textureOptions,
    required this.onClose,
    required this.onSampleChanged,
    required this.onSelectThemePreset,
    required this.onSelectTexture,
    required this.onSaveThemePreset,
    required this.onDeleteTheme,
    required this.onFontSizeChanged,
    required this.onUseCustomPaddingChanged,
    required this.onPagePaddingChanged,
    required this.onShowTitleChanged,
    required this.onShowPageNumberChanged,
    required this.onPaperColorChanged,
    required this.onTextColorChanged,
    required this.onLinkColorChanged,
    required this.onInternalLinkColorChanged,
    required this.onCaptionColorChanged,
    required this.onRubyColorChanged,
  });

  final KumihanController controller;
  final List<ExampleSample> samples;
  final String selectedSampleId;
  final List<ExampleThemePreset> themePresets;
  final String selectedThemePresetId;
  final String selectedTextureId;
  final bool selectedThemeIsCustom;
  final double fontSize;
  final EdgeInsets? pagePadding;
  final bool showTitle;
  final bool showPageNumber;
  final KumihanThemeData draftTheme;
  final Color panelColor;
  final TextEditingController themeNameController;
  final TextEditingController paperColorController;
  final TextEditingController textColorController;
  final TextEditingController linkColorController;
  final TextEditingController internalLinkColorController;
  final TextEditingController captionColorController;
  final TextEditingController rubyColorController;
  final List<ExamplePaperTextureOption> textureOptions;
  final VoidCallback onClose;
  final ValueChanged<String?> onSampleChanged;
  final ValueChanged<String?> onSelectThemePreset;
  final ValueChanged<String?> onSelectTexture;
  final VoidCallback onSaveThemePreset;
  final VoidCallback onDeleteTheme;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onUseCustomPaddingChanged;
  final ValueChanged<EdgeInsets> onPagePaddingChanged;
  final ValueChanged<bool> onShowTitleChanged;
  final ValueChanged<bool> onShowPageNumberChanged;
  final ValueChanged<String> onPaperColorChanged;
  final ValueChanged<String> onTextColorChanged;
  final ValueChanged<String> onLinkColorChanged;
  final ValueChanged<String> onInternalLinkColorChanged;
  final ValueChanged<String> onCaptionColorChanged;
  final ValueChanged<String> onRubyColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useCustomPadding = pagePadding != null;
    final effectivePadding =
        pagePadding ?? const EdgeInsets.fromLTRB(28, 28, 28, 28);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 24,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Controls',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'サンプル切替、ページ移動、縦横切替、テーマ編集をこのポップアップに集約しています。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: '閉じる',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final snapshot = controller.snapshot;
                  final spread =
                      snapshot.spreadMode == KumihanSpreadMode.doublePage
                      ? '見開き'
                      : '単ページ';
                  final mode =
                      snapshot.writingMode == KumihanWritingMode.vertical
                      ? '縦組み'
                      : '横組み';

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        label: 'Page',
                        value:
                            '${snapshot.currentPage + 1}/${snapshot.totalPages == 0 ? 1 : snapshot.totalPages}',
                      ),
                      _InfoPill(label: 'Mode', value: mode),
                      _InfoPill(label: 'Spread', value: spread),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Reader',
                panelColor: panelColor,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(selectedSampleId),
                        initialValue: selectedSampleId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Sample'),
                        items: samples
                            .map(
                              (sample) => DropdownMenuItem<String>(
                                value: sample.id,
                                child: Text(sample.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: onSampleChanged,
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.showFirstPage,
                      child: const Text('先頭'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.prev,
                      child: const Text('前へ'),
                    ),
                    FilledButton(
                      onPressed: controller.next,
                      child: const Text('次へ'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.showLastPage,
                      child: const Text('末尾'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.toggleWritingMode,
                      child: const Text('縦横切替'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.toggleSpread,
                      child: const Text('見開き切替'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.toggleShift1Page,
                      child: const Text('1頁ずらし'),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.toggleForceIndent,
                      child: const Text('強制字下げ'),
                    ),
                    _ReaderSlider(
                      label: '文字サイズ',
                      valueLabel: '${fontSize.toStringAsFixed(0)} px',
                      value: fontSize,
                      min: 12,
                      max: 36,
                      divisions: 24,
                      onChanged: onFontSizeChanged,
                    ),
                    SizedBox(
                      width: 300,
                      child: SwitchListTile.adaptive(
                        value: useCustomPadding,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('カスタム余白'),
                        subtitle: Text(
                          useCustomPadding ? '上下左右を個別に指定中' : '自動余白を使用中',
                        ),
                        onChanged: onUseCustomPaddingChanged,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: SwitchListTile.adaptive(
                        value: showTitle,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('タイトル表示'),
                        onChanged: onShowTitleChanged,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: SwitchListTile.adaptive(
                        value: showPageNumber,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ページ番号表示'),
                        onChanged: onShowPageNumberChanged,
                      ),
                    ),
                    _ReaderSlider(
                      label: '余白 上',
                      valueLabel:
                          '${effectivePadding.top.toStringAsFixed(0)} px',
                      value: effectivePadding.top,
                      min: 0,
                      max: 120,
                      divisions: 120,
                      onChanged: useCustomPadding
                          ? (value) => onPagePaddingChanged(
                              EdgeInsets.fromLTRB(
                                effectivePadding.left,
                                value,
                                effectivePadding.right,
                                effectivePadding.bottom,
                              ),
                            )
                          : null,
                    ),
                    _ReaderSlider(
                      label: '余白 下',
                      valueLabel:
                          '${effectivePadding.bottom.toStringAsFixed(0)} px',
                      value: effectivePadding.bottom,
                      min: 0,
                      max: 120,
                      divisions: 120,
                      onChanged: useCustomPadding
                          ? (value) => onPagePaddingChanged(
                              EdgeInsets.fromLTRB(
                                effectivePadding.left,
                                effectivePadding.top,
                                effectivePadding.right,
                                value,
                              ),
                            )
                          : null,
                    ),
                    _ReaderSlider(
                      label: '余白 左',
                      valueLabel:
                          '${effectivePadding.left.toStringAsFixed(0)} px',
                      value: effectivePadding.left,
                      min: 0,
                      max: 120,
                      divisions: 120,
                      onChanged: useCustomPadding
                          ? (value) => onPagePaddingChanged(
                              EdgeInsets.fromLTRB(
                                value,
                                effectivePadding.top,
                                effectivePadding.right,
                                effectivePadding.bottom,
                              ),
                            )
                          : null,
                    ),
                    _ReaderSlider(
                      label: '余白 右',
                      valueLabel:
                          '${effectivePadding.right.toStringAsFixed(0)} px',
                      value: effectivePadding.right,
                      min: 0,
                      max: 120,
                      divisions: 120,
                      onChanged: useCustomPadding
                          ? (value) => onPagePaddingChanged(
                              EdgeInsets.fromLTRB(
                                effectivePadding.left,
                                effectivePadding.top,
                                value,
                                effectivePadding.bottom,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Theme Studio',
                subtitle:
                    'Hex は #RRGGBB か #AARRGGBB で入力できます。保存するとプリセットとして再利用できます。',
                panelColor: panelColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(selectedThemePresetId),
                            initialValue: selectedThemePresetId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Theme preset',
                            ),
                            items: themePresets
                                .map(
                                  (preset) => DropdownMenuItem<String>(
                                    value: preset.id,
                                    child: Text(preset.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: onSelectThemePreset,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(selectedTextureId),
                            initialValue: selectedTextureId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Paper texture',
                            ),
                            items: textureOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.id,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: onSelectTexture,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: themeNameController,
                            decoration: const InputDecoration(
                              labelText: 'Theme name',
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: onSaveThemePreset,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(selectedThemeIsCustom ? '上書き保存' : '新規保存'),
                        ),
                        if (selectedThemeIsCustom)
                          OutlinedButton.icon(
                            onPressed: onDeleteTheme,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('削除'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ThemeColorField(
                          label: '紙色',
                          controller: paperColorController,
                          previewColor: draftTheme.paperColor,
                          onChanged: onPaperColorChanged,
                        ),
                        _ThemeColorField(
                          label: '文字色',
                          controller: textColorController,
                          previewColor: draftTheme.textColor,
                          onChanged: onTextColorChanged,
                        ),
                        _ThemeColorField(
                          label: '外部リンク',
                          controller: linkColorController,
                          previewColor: draftTheme.linkColor,
                          onChanged: onLinkColorChanged,
                        ),
                        _ThemeColorField(
                          label: '内部リンク',
                          controller: internalLinkColorController,
                          previewColor: draftTheme.internalLinkColor,
                          onChanged: onInternalLinkColorChanged,
                        ),
                        _ThemeColorField(
                          label: 'キャプション',
                          controller: captionColorController,
                          previewColor: draftTheme.captionColor,
                          onChanged: onCaptionColorChanged,
                        ),
                        _ThemeColorField(
                          label: 'ルビ',
                          controller: rubyColorController,
                          previewColor: draftTheme.rubyColor,
                          onChanged: onRubyColorChanged,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.panelColor,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color panelColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ThemeColorField extends StatelessWidget {
  const _ThemeColorField({
    required this.label,
    required this.controller,
    required this.previewColor,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Color previewColor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderSlider extends StatelessWidget {
  const _ReaderSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $valueLabel', style: theme.textTheme.bodyMedium),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
