import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/host_panel/model/lisa_host_profile.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';

void main() {
  LocalProfileEntity local(String name) => LocalProfileEntity(
        id: '1',
        active: true,
        name: name,
        lastUpdate: DateTime(2026, 8, 16),
      );

  test('Lisa host local profiles match', () {
    expect(isLisaHostProfile(local('Lisa主机')), isTrue);
    expect(isLisaHostProfile(local('丽莎主机')), isTrue);
    expect(isLisaHostProfile(local('LisaHost')), isTrue);
  });

  test('other subscriptions do not match', () {
    expect(
      isLisaHostProfile(
        RemoteProfileEntity(
          id: '2',
          active: true,
          name: 'Code分享',
          url: 'https://example.com/sub',
          lastUpdate: DateTime(2026, 8, 16),
        ),
      ),
      isFalse,
    );
    expect(isLisaHostProfile(local('机场备用')), isFalse);
    expect(isLisaHostProfile(null), isFalse);
  });
}
