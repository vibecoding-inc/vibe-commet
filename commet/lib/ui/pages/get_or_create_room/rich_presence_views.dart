import 'package:flutter/material.dart';
import 'package:tiamat/tiamat.dart' as tiamat;

class RichPresenceCreatorDescription extends StatelessWidget {
  const RichPresenceCreatorDescription({super.key});

  @override
  Widget build(BuildContext context) {
    return tiamat.Text.labelLow(
      "A dedicated channel type for sharing rich presence status updates with everyone in the channel.",
    );
  }
}
