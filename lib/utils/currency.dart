const defaultUsdToKhrRate = 4100.0;

String formatUsd(double value) => '\$${value.toStringAsFixed(2)}';

String formatRiel(double usd, double rate) {
  final digits = (usd * rate).round().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => ',',
  );
  return '$formatted ៛';
}

String formatDualCurrency(double usd, double rate, {bool showRiel = true}) =>
    showRiel ? '${formatUsd(usd)} · ${formatRiel(usd, rate)}' : formatUsd(usd);
