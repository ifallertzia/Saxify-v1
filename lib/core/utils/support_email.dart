/// Android uses ACTION_SENDTO extras; other platforms use a mailto URI.
/// Uri(queryParameters:) uses form encoding (spaces become '+'), which Gmail
/// has been known to display literally. Encode each component as %20 instead.
class SupportEmail {
  const SupportEmail({required this.to, required this.category, required this.details});

  final String to;
  final String category;
  final String details;

  String get subject => 'Saxify feedback: $category';

  String get body => <String>[
    'Hi Saxify team,',
    '',
    'Topic: $category',
    '',
    'What happened:',
    details.trim().isEmpty ? 'Please describe the issue or suggestion here.' : details.trim(),
    '',
    'Error examples:',
    '- Playback stopped while the phone was locked.',
    '- Search results were unrelated or a download did not finish.',
    '',
    'Suggestions:',
    '- I would like Saxify to improve: ',
    '',
    'Device / Android version (optional): ',
  ].join('\n');

  Uri get mailto => Uri(
    scheme: 'mailto',
    path: to,
    query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );

  Uri get gmailWeb => Uri.parse(
    'https://mail.google.com/mail/?view=cm&fs=1'
    '&to=${Uri.encodeComponent(to)}'
    '&su=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}
