import 'dart:async';

import 'package:commet/client/components/user_presence/user_presence_component.dart';
import 'package:commet/client/components/user_presence/user_presence_lifecycle_watcher.dart';
import 'package:commet/client/matrix/components/read_receipts/matrix_read_receipt_component.dart';
import 'package:commet/client/matrix/components/typing_indicators/matrix_typing_indicators_component.dart';
import 'package:commet/client/matrix/components/user_presence/matrix_rich_presence.dart';
import 'package:commet/client/matrix/matrix_client.dart';
import 'package:commet/client/matrix/matrix_room.dart';
import 'package:commet/debug/log.dart';
import 'package:commet/utils/in_memory_cache.dart';
import 'package:matrix/matrix.dart';

class MatrixUserPresenceComponent
    implements UserPresenceComponent<MatrixClient> {
  @override
  MatrixClient client;

  StreamController<(String, UserPresence)> _controller =
      StreamController.broadcast();

  late InMemoryCache<DateTime> lastSeen;
  final Map<String, UserPresenceMessage> _knownRichPresence = {};

  MatrixUserPresenceComponent(this.client) {
    client.matrixClient.onPresenceChanged.stream.listen(changed);

    client.matrixClient.onSync.stream.listen(onSync);
    lastSeen = InMemoryCache(
        maxRetention: Duration(minutes: 2),
        pollFrequency: Duration(seconds: 100));
    lastSeen.onRemove.listen(onLastSeenRemoved);
    unawaited(refreshKnownRichPresenceFromRooms());

    UserPresenceLifecycleWatcher().init();
  }

  @override
  bool get usePublicReadReceipts {
    var publicReadReceipts = client
        .matrixClient
        .accountData[MatrixReadReceiptComponent.publicReadReceiptsKey]
        ?.content["enabled"];
    return publicReadReceipts is bool ? publicReadReceipts : true;
  }

  @override
  Future<void> setUsePublicReadReceipts(bool value) async {
    await client.matrixClient.setAccountData(
      client.matrixClient.userID!,
      MatrixReadReceiptComponent.publicReadReceiptsKey,
      {"enabled": value},
    );
    client.matrixClient.receiptsPublicByDefault = value;
  }

  @override
  bool get typingIndicatorEnabled {
    var publicTypingIndicator = client
        .matrixClient
        .accountData[MatrixTypingIndicatorsComponent.publicTypingIndicatorKey]
        ?.content["enabled"];
    return publicTypingIndicator is bool ? publicTypingIndicator : true;
  }

  @override
  Future<void> setTypingIndicatorEnabled(bool value) async =>
      await client.matrixClient.setAccountData(
        client.matrixClient.userID!,
        MatrixTypingIndicatorsComponent.publicTypingIndicatorKey,
        {"enabled": value},
      );

  @override
  Future<UserPresence> getUserPresence(String userId) async {
    final presence = await client.matrixClient.fetchCurrentPresence(userId);

    if (presence.presence == PresenceType.offline &&
        presence.statusMsg == null &&
        presence.lastActiveTimestamp == null) {
      var seen = lastSeen.get(userId);
      if (seen != null) {
        if (DateTime.now().difference(seen).inSeconds < 120) {
          return UserPresence(UserPresenceStatus.online);
        }
      }
    }

    var result = convertPresence(presence);
    if (result.message == null) {
      var richPresence = getKnownRichPresence(userId);
      if (richPresence != null) {
        result = UserPresence(result.status, message: richPresence);
      }
    }

    return result;
  }

  UserPresence convertPresence(CachedPresence presence) {
    final status = switch (presence.presence) {
      PresenceType.offline => UserPresenceStatus.offline,
      PresenceType.online => UserPresenceStatus.online,
      PresenceType.unavailable => UserPresenceStatus.unavailable,
    };

    UserPresenceMessage? message = null;

    if (presence.statusMsg != null) {
      message = UserPresenceMessage(
          presence.statusMsg!, PresenceMessageType.userCustom);
    }

    return UserPresence(status, message: message);
  }

  void changed(CachedPresence event) {
    _controller.add((event.userid, convertPresence(event)));
  }

  @override
  Stream<(String, UserPresence)> get onPresenceChanged => _controller.stream;

  @override
  Future<void> setStatus(UserPresenceStatus status,
      {String? message, bool clearMessage = false}) async {
    final self = client.self!.identifier;

    final current = await client.matrixClient.getPresence(self);
    final statusMessage = clearMessage ? null : message ?? current.statusMsg;

    await client.matrixClient.setPresence(
        self,
        statusMsg: statusMessage,
        switch (status) {
          UserPresenceStatus.offline => PresenceType.offline,
          UserPresenceStatus.unknown => PresenceType.offline,
          UserPresenceStatus.online => PresenceType.online,
          UserPresenceStatus.unavailable => PresenceType.unavailable,
        });

    await broadcastRichPresenceStatus(statusMessage);
  }

  void onSync(SyncUpdate event) {
    bool shouldRefreshRichPresence = false;

    if (event.rooms?.join != null) {
      for (var update in event.rooms!.join!.entries) {
        handleEvents(update.value.ephemeral);
        handleEvents(update.value.state);
        handleTimelineUpdate(update.value.timeline);
        if (isRichPresenceRoom(update.key)) {
          shouldRefreshRichPresence = true;
        }
      }
    }

    if (event.rooms?.leave?.isNotEmpty == true ||
        event.rooms?.invite?.isNotEmpty == true) {
      shouldRefreshRichPresence = true;
    }

    if (shouldRefreshRichPresence) {
      unawaited(refreshKnownRichPresenceFromRooms());
    }
  }

  void handleEvents(List<BasicEvent>? events) {
    if (events == null) return;
    var time = DateTime.now();

    for (var event in events) {
      try {
        if (event.type == "m.typing") {
          handleTyping(event, time);
          return;
        }

        if (event.type == "m.receipt") {
          handleReadReceipt(event);
          return;
        }

        if (event.type == "m.room.member") {
          handleRoomMemberEvent(event);
          return;
        }
      } catch (_) {}
    }
  }

  void handleTyping(BasicEvent event, DateTime time) {
    for (var id in event.content["user_ids"] as List<dynamic>) {
      sawUser(id, time);
    }
  }

  void handleReadReceipt(BasicEvent event) {
    for (var event in event.content.values) {
      var read = (event as Map<String, dynamic>)["m.read"];
      if (read == null) continue;

      for (var entry in (read as Map<String, dynamic>).entries) {
        var value = entry.value as Map<String, dynamic>;

        if (value.containsKey("ts")) {
          sawUser(entry.key,
              DateTime.fromMicrosecondsSinceEpoch((value["ts"] as int) * 1000));
        }
      }
    }
  }

  void handleTimelineUpdate(TimelineUpdate? timeline) async {
    if (timeline?.events == null) return;

    for (var event in timeline!.events!) {
      sawUser(event.senderId, event.originServerTs);
    }
  }

  void sawUser(String id, DateTime timestamp) async {
    final presence = await client.matrixClient
        .fetchCurrentPresence(id, fetchOnlyFromCached: true);

    if (presence.presence != PresenceType.offline ||
        presence.statusMsg != null) {
      return;
    }

    if (DateTime.now().difference(timestamp).inSeconds < 60) {
      var seen = lastSeen.get(id);

      if (seen == null) {
        lastSeen.put(id, timestamp);
      } else {
        if (timestamp.isAfter(seen)) {
          lastSeen.put(id, timestamp);
        }
      }

      _controller.add((id, UserPresence(UserPresenceStatus.online)));
    }
  }

  void onLastSeenRemoved(String event) async {
    final presence = await client.matrixClient
        .fetchCurrentPresence(event, fetchOnlyFromCached: true);
    if (presence.presence == PresenceType.offline) {
      _controller.add((event, UserPresence(UserPresenceStatus.offline)));
    }
  }

  void handleRoomMemberEvent(BasicEvent event) {}

  UserPresenceMessage? getKnownRichPresence(String userId) {
    return _knownRichPresence[userId];
  }

  bool isRichPresenceRoom(String roomId) {
    final room = client.getRoom(roomId);
    if (room is! MatrixRoom) {
      return false;
    }

    return room.matrixRoom.getState(EventTypes.RoomCreate)?.content["type"] ==
        richPresenceRoomType;
  }

  Future<void> broadcastRichPresenceStatus(String? statusMessage) async {
    final self = client.self?.identifier;
    if (self == null) {
      return;
    }

    final content = {
      if (statusMessage != null && statusMessage.trim().isNotEmpty)
        "status": statusMessage,
    };

    final tasks = [
      for (var room in client.rooms.whereType<MatrixRoom>())
        if (isRichPresenceRoom(room.identifier))
          client.matrixClient.setRoomStateWithKey(
              room.identifier, richPresenceStateEventType, self, content)
    ];

    await Future.wait(tasks);
    await refreshKnownRichPresenceFromRooms();
  }

  Future<void> refreshKnownRichPresenceFromRooms() async {
    final previous = Map<String, UserPresenceMessage>.from(_knownRichPresence);
    final next = <String, UserPresenceMessage>{};

    for (var room in client.rooms.whereType<MatrixRoom>()) {
      if (!isRichPresenceRoom(room.identifier)) {
        continue;
      }

      final state = room.matrixRoom.states[richPresenceStateEventType];
      if (state == null) {
        continue;
      }

      for (var event in state.values) {
        final status = event.content["status"];
        if (status is! String || status.trim().isEmpty) {
          continue;
        }

        final userId = event.stateKey;
        if (userId == null || userId.isEmpty || userId != event.senderId) {
          continue;
        }

        next[userId] =
            UserPresenceMessage(status, PresenceMessageType.userCustom);
      }
    }

    _knownRichPresence
      ..clear()
      ..addAll(next);

    await emitRichPresenceDiff(previous, next);
  }

  Future<void> emitRichPresenceDiff(Map<String, UserPresenceMessage> previous,
      Map<String, UserPresenceMessage> next) async {
    final changedIds = <String>{...previous.keys, ...next.keys}
        .where((userId) =>
            previous.containsKey(userId) != next.containsKey(userId) ||
            previous[userId]?.message != next[userId]?.message)
        .toList();

    final updates = await Future.wait(changedIds.map((userId) async {
      UserPresence presence;
      try {
        final cached = await client.matrixClient
            .fetchCurrentPresence(userId, fetchOnlyFromCached: true);
        presence = convertPresence(cached);
      } catch (e, s) {
        Log.onError(e, s,
            content:
                "Failed to fetch cached presence while diffing rich presence");
        presence = UserPresence(UserPresenceStatus.unknown);
      }

      final richPresence = next[userId];
      if (presence.message == null && richPresence != null) {
        presence = UserPresence(presence.status, message: richPresence);
      }

      return (userId, presence);
    }));

    for (var update in updates) {
      var userId = update.$1;
      var presence = update.$2;
      _controller.add((userId, presence));
    }
  }
}
