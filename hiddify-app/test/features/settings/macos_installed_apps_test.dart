import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/data/macos_installed_apps.dart';

void main() {
  test('pathForMacBundleName ignores empty names', () {
    expect(pathForMacBundleName(''), isNull);
    expect(pathForMacBundleName('   '), isNull);
  });

  test('pathForMacBundleName returns null for missing apps', () {
    expect(pathForMacBundleName('DefinitelyNotAnApp_LisaSpeed_xyz'), isNull);
  });
}
