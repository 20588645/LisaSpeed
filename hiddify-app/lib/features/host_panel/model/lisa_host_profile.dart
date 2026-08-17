import 'package:hiddify/features/profile/model/profile_entity.dart';

/// LisaHost VPS quota belongs to the local Lisa profile, not every
/// subscription the user happens to have connected.
bool isLisaHostProfile(ProfileEntity? profile) {
  final name = profile?.name.trim().toLowerCase() ?? '';
  if (name.isEmpty) return false;
  if (name.contains('丽莎')) return true;
  final compact = name.replaceAll(RegExp(r'\s+'), '');
  return compact.contains('lisahost') || compact.contains('lisa主机');
}
