import 'package:matrix/matrix.dart' as matrix;

import '../permissions.dart';

class MatrixRoomPermissions extends Permissions {
  late matrix.Room room;

  MatrixRoomPermissions(this.room);

  @override
  bool get canBan => room.canBan;

  @override
  bool get canKick => room.canKick;

  @override
  bool get canSendMessage => room.canSendDefaultMessages;

  @override
  bool get canEditAvatar => room.canChangeStateEvent("m.room.avatar");

  @override
  bool get canEditName => room.canChangeStateEvent("m.room.name");

  @override
  bool get canEditTopic =>
      room.canChangeStateEvent(matrix.EventTypes.RoomTopic);

  @override
  bool get canEnableE2EE => room.canChangeStateEvent("m.room.encryption");

  @override
  bool get canEditRoomEmoticons => room.canSendDefaultStates;

  @override
  bool get canDeleteOtherUserMessages => room.canRedact;

  @override
  bool get canEditChildren =>
      room.canChangeStateEvent(matrix.EventTypes.SpaceChild);

  @override
  bool get canInviteUser => room.canInvite;

  @override
  bool get canChangeRoles => room.canChangePowerLevel;

  @override
  bool get canChangeVisibility =>
      room.canChangeStateEvent(matrix.EventTypes.RoomJoinRules);

  // Nickname security model:
  //
  // Server-side enforcement:
  //   Matrix homeservers enforce power levels for ALL state events. When a
  //   client calls setRoomStateWithKey for "com.commet.nickname", the server
  //   checks the sender's power level against:
  //     1. m.room.power_levels.events["com.commet.nickname"] (if configured)
  //     2. m.room.power_levels.state_default (fallback, typically 50)
  //   If the sender lacks sufficient power, the server rejects with 403.
  //
  // Client-side enforcement:
  //   The Matrix protocol does NOT support per-state-key power level
  //   restrictions. The "only your own nickname" rule is enforced client-side
  //   by only showing the option for self (isSelf) when the user has basic
  //   nickname permission. A user with a different Matrix client could
  //   bypass this if the event's power level is set low enough (e.g., 0)
  //   to allow them to send the state event.
  //
  // To allow regular users to set their own nicknames, room admins should
  // configure the power level for "com.commet.nickname" to 0 (the default
  // in the permissions page). Moderators (PL >= 50) can set any user's
  // nickname; regular users can only set their own (client-side restriction).

  @override
  bool get canSetNicknames => room.canChangeStateEvent("com.commet.nickname");

  @override
  bool get canSetOtherUserNicknames =>
      canSetNicknames && room.ownPowerLevel >= 50;
}
