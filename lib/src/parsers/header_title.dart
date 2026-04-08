String resolveDocumentHeaderTitle({
  String? author,
  String? headerTitle,
  String? title,
}) {
  final explicit = headerTitle?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final resolvedTitle = title?.trim() ?? '';
  final resolvedAuthor = author?.trim() ?? '';
  if (resolvedTitle.isNotEmpty && resolvedAuthor.isNotEmpty) {
    return '$resolvedTitle / $resolvedAuthor';
  }
  if (resolvedTitle.isNotEmpty) {
    return resolvedTitle;
  }
  return resolvedAuthor;
}
