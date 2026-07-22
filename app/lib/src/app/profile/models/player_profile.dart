import 'package:kolkhoz_app/src/app/settings/settings.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.seatID,
    this.userID,
    this.displayName,
    this.avatarURL,
    this.stats = defaultProfileStats,
  });

  final int seatID;
  final String? userID;
  final String? displayName;
  final String? avatarURL;
  final KolkhozProfileStats stats;

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;
}
