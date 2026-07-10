import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String toDisplayDate() => DateFormat('dd MMM yyyy').format(this);

  String toDisplayDateTime() => DateFormat('dd MMM yyyy, HH:mm').format(this);

  String toRelative() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
