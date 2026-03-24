import '../kumihan_document.dart';

abstract interface class KumihanDocumentParser<T> {
  KumihanDocument parse(T input);
}

class KumihanAozoraParser implements KumihanDocumentParser<String> {
  const KumihanAozoraParser({
    this.author,
    this.headerTitle,
    this.includeCover = false,
    this.title,
  });

  final String? author;
  final String? headerTitle;
  final bool includeCover;
  final String? title;

  @override
  KumihanDocument parse(String input) {
    final blocks = <KumihanBlock>[];
    final documentTitle = title?.trim() ?? '';
    final documentAuthor = author?.trim() ?? '';

    if (includeCover &&
        (documentTitle.isNotEmpty || documentAuthor.isNotEmpty)) {
      blocks.add(
        KumihanCoverBlock(
          title: documentTitle.isNotEmpty ? documentTitle : documentAuthor,
          credit: documentTitle.isNotEmpty && documentAuthor.isNotEmpty
              ? documentAuthor
              : null,
        ),
      );
    }

    final normalized = input
        .replaceAll(RegExp(r'(\r\n|\r)'), '\n')
        .replaceFirst(RegExp(r'\n$'), '');
    if (normalized.isEmpty) {
      return KumihanDocument(
        blocks: blocks,
        headerTitle: _resolvedHeaderTitle(documentTitle, documentAuthor),
      );
    }

    for (final rawLine in normalized.split('\n')) {
      var line = rawLine;
      var keepWithPrevious = false;
      if (line.startsWith('‌')) {
        keepWithPrevious = true;
        line = line.substring(1);
      }

      final leadingCommands = <String>[];
      while (line.startsWith('［＃')) {
        final end = line.indexOf('］');
        if (end < 0) {
          break;
        }
        leadingCommands.add(line.substring(0, end + 1));
        line = line.substring(end + 1);
      }

      if (line.isEmpty && leadingCommands.isNotEmpty) {
        for (final command in leadingCommands) {
          blocks.add(KumihanCommandBlock(command));
        }
        continue;
      }

      blocks.add(
        KumihanParagraphBlock(
          children: line.isEmpty
              ? const <KumihanInline>[]
              : <KumihanInline>[KumihanRawInline(line)],
          keepWithPrevious: keepWithPrevious,
          leadingCommands: leadingCommands,
        ),
      );
    }

    return KumihanDocument(
      blocks: blocks,
      headerTitle: _resolvedHeaderTitle(documentTitle, documentAuthor),
    );
  }

  String _resolvedHeaderTitle(String documentTitle, String documentAuthor) {
    final explicit = headerTitle?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (documentTitle.isEmpty) {
      return documentAuthor;
    }
    if (documentAuthor.isEmpty) {
      return documentTitle;
    }
    return '$documentTitle / $documentAuthor';
  }
}
