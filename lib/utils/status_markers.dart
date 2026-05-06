enum StatusMarker {
  success('[OK]'),
  error('[FAIL]'),
  warning('[WARN]'),
  bullet('-'),
  successBullet('OK'),
  errorBullet('FAIL'),
  warningBullet('WARN');

  final String symbol;

  const StatusMarker(this.symbol);

  @override
  String toString() => symbol;
}
