/// Document verification result for the Trust Center portal.
class DocumentVerificationResult {
  const DocumentVerificationResult({
    required this.isValid,
    required this.status,
    required this.message,
  });

  final bool isValid;
  final String status;
  final String message;
}

/// Heuristic verification against sample certificate numbers from CMS.
DocumentVerificationResult verifyDocument(String reference) {
  final normalized = reference.trim().toUpperCase();
  if (normalized.isEmpty) {
    return const DocumentVerificationResult(
      isValid: false,
      status: 'Invalid reference',
      message: 'Please enter a certificate or document reference number.',
    );
  }

  const validRefs = {
    'RC-XXXXXXX': 'Corporate Affairs Commission — Active registration',
    'REDAN-2018-042': 'REDAN membership — Valid until Jun 2026',
    'ISO-9001-2024-HDH': 'ISO 9001 certification — Valid until Jan 2027',
    'NSC-HSE-2025-118': 'Health & Safety certification — Valid until Feb 2026',
  };

  for (final entry in validRefs.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
      return DocumentVerificationResult(
        isValid: true,
        status: 'Verified authentic',
        message: entry.value,
      );
    }
  }

  return const DocumentVerificationResult(
    isValid: false,
    status: 'Not found',
    message: 'No matching document in HD Homes registry. Contact legal@hdhomes.ng for assistance.',
  );
}
