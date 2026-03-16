abstract class Permissions {
  bool get canChangeRoles => false;

  bool get canBan => false;

  bool get canKick => false;

  bool get canSendMessage => false;

  bool get canEditName => false;

  bool get canEditAvatar => false;

  bool get canEditTopic => false;

  bool get canEditAnything =>
      (canEditName || canEditAvatar || canChangeNotificationSettings);

  bool get canEditAppearance => (canEditAvatar || canEditName);

  bool get canEnableE2EE => false;

  bool get canChangeVisibility => false;

  bool get canEditRoomSecurity => canEnableE2EE;

  bool get canChangeNotificationSettings => true;

  bool get canUserEditMessages => true;

  bool get canDeleteOtherUserMessages => true;

  bool get canEditRoomEmoticons => true;

  bool get canEditChildren => true;

  bool get canInviteUser => true;

  /// Whether the current user can set channel-scoped nicknames at all
  /// (including their own). This checks the server-enforced power level
  /// for the nickname state event type.
  bool get canSetNicknames => false;

  /// Whether the current user can set OTHER users' nicknames.
  /// This is a higher privilege than [canSetNicknames] and typically
  /// requires moderator-level power (PL >= 50).
  bool get canSetOtherUserNicknames => false;
}
