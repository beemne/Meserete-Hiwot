import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/widgets/qr.dart';

void main() {
  test('reads the member uuid from a scanned QR (link or bare uuid), ignores anything else', () {
    const id = '3f2b8c1e-9a4d-4e7f-b0c2-1d5e6f7a8b9c';
    expect(memberUuidFromQr('https://mh.hersolan.pro/u/$id'), id);
    expect(memberUuidFromQr(id.toUpperCase()), id);
    expect(memberUuidFromQr('  $id  '), id);
    expect(memberUuidFromQr('https://example.com/not-a-member'), isNull);
    expect(memberUuidFromQr(null), isNull);
  });
}
