import 'package:intl/intl.dart';

extension NumberExtensions on num {
  String toCurrency({String symbol = '₦', int decimalDigits = 0}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(this);
  }

  String toCompact() {
    if (this >= 1000000000) return '${(this / 1000000000).toStringAsFixed(1)}B';
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}K';
    return toString();
  }
}
