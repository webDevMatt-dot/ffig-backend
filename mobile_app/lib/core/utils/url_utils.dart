String normalizeUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }

  return 'https://$trimmed';
}
