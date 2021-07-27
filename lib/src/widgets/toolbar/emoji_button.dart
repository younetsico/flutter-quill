import 'package:flutter/material.dart';

import '../../../flutter_quill.dart';

class EmojiButton extends StatefulWidget {
  const EmojiButton({
    required this.icon,
    required this.controller,
    this.iconSize = kDefaultIconSize,
    Key? key,
  }) : super(key: key);

  final IconData icon;
  final double iconSize;
  final QuillController controller;

  @override
  _EmojiButtonState createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<EmojiButton> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTheme = theme.iconTheme.color;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isEmojiKeyboardActive,
      builder: (_, isActive, child) {
        return QuillIconButton(
          highlightElevation: 1.0,
          hoverElevation: 1,
          size: widget.iconSize * kIconButtonFactor,
          fillColor: isActive
              ? theme.toggleableActiveColor
              : theme.canvasColor,
          icon: Icon(widget.icon,
              size: widget.iconSize,
              color: isActive
                  ? theme.primaryIconTheme.color
                  : theme.iconTheme.color),
          onPressed: () => widget.controller
              .sendToolbarAction(CustomToolbarAction(ToolbarEvent.togglEmoji)),
        );
      },
    );
  }
}
