import 'package:commet/client/client.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  test("Rich presence room type has user-facing label and icon", () {
    expect(RoomType.richPresence.string, "Rich Presence");
    expect(RoomType.richPresence.icon, Icons.sports_esports);
  });
}
