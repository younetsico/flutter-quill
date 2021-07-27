import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/models/documents/nodes/line.dart';
import 'package:flutter_quill/src/widgets/text_selection.dart';
import 'package:flutter_quill/src/widgets/viewer/simple_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/documents/nodes/leaf.dart' as leaf;

abstract class ViewerState extends State<QuillViewer> {
  RenderEditor? getRenderEditor();
}

abstract class ViewerSelectionGestureDetectorBuilderDelegate {
  GlobalKey<ViewerState> getEditableTextKey();

  bool getForcePressEnabled();

  bool getSelectionEnabled();
}

class ViewerSelectionGestureDetectorBuilder {
  ViewerSelectionGestureDetectorBuilder(this.delegate);

  final ViewerSelectionGestureDetectorBuilderDelegate delegate;
  bool shouldShowSelectionToolbar = true;

  ViewerState? getEditor() {
    return delegate.getEditableTextKey().currentState;
  }

  RenderEditor? getRenderEditor() {
    return getEditor()?.getRenderEditor();
  }

  void onTapDown(TapDownDetails details) {
    getRenderEditor()?.handleTapDown(details);

    final kind = details.kind;
    shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;
  }

  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.getForcePressEnabled());
    shouldShowSelectionToolbar = true;
    if (delegate.getSelectionEnabled()) {
      getRenderEditor()!.selectWordsInRange(
        details.globalPosition,
        null,
        SelectionChangedCause.forcePress,
      );
    }
  }

  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.getForcePressEnabled());
    getRenderEditor()!.selectWordsInRange(
      details.globalPosition,
      null,
      SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) {
      // getEditor()!.showToolbar();
    }
  }

  void onSingleTapUp(TapUpDetails details) {
    if (delegate.getSelectionEnabled()) {
      getRenderEditor()!.selectWordEdge(SelectionChangedCause.tap);
    }
  }

  void onSingleTapCancel() {}

  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.getSelectionEnabled()) {
      getRenderEditor()!.selectPositionAt(
        details.globalPosition,
        null,
        SelectionChangedCause.longPress,
      );
    }
  }

  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.getSelectionEnabled()) {
      getRenderEditor()!.selectPositionAt(
        details.globalPosition,
        null,
        SelectionChangedCause.longPress,
      );
    }
  }

  void onSingleLongTapEnd(LongPressEndDetails details) {
    if (shouldShowSelectionToolbar) {
      // getEditor()!.showToolbar();
    }
  }

  void onDoubleTapDown(TapDownDetails details) {
    if (delegate.getSelectionEnabled()) {
      getRenderEditor()!.selectWord(SelectionChangedCause.tap);
      if (shouldShowSelectionToolbar) {
        // getEditor()!.showToolbar();
      }
    }
  }

  void onDragSelectionStart(DragStartDetails details) {
    getRenderEditor()!.selectPositionAt(
      details.globalPosition,
      null,
      SelectionChangedCause.drag,
    );
  }

  void onDragSelectionUpdate(
      DragStartDetails startDetails, DragUpdateDetails updateDetails) {
    getRenderEditor()!.selectPositionAt(
      startDetails.globalPosition,
      updateDetails.globalPosition,
      SelectionChangedCause.drag,
    );
  }

  void onDragSelectionEnd(DragEndDetails details) {}

  Widget build(HitTestBehavior behavior, Widget child) {
    return EditorTextSelectionGestureDetector(
      onTapDown: onTapDown,
      onForcePressStart:
          delegate.getForcePressEnabled() ? onForcePressStart : null,
      onForcePressEnd: delegate.getForcePressEnabled() ? onForcePressEnd : null,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onDoubleTapDown: onDoubleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      behavior: behavior,
      child: child,
    );
  }
}

class QuillViewerSelectionGestureDetectorBuilder
    extends ViewerSelectionGestureDetectorBuilder {
  QuillViewerSelectionGestureDetectorBuilder(this._state) : super(_state);

  final QuillSimpleViewerState _state;

  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.getSelectionEnabled() && shouldShowSelectionToolbar) {
      // getEditor()!.showToolbar();
    }
  }

  @override
  void onForcePressEnd(ForcePressDetails details) {}

  @override
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    // if (_state.widget.onSingleLongTapMoveUpdate != null) {
    //   final renderEditor = getRenderEditor();
    //   if (renderEditor != null) {
    //     if (_state.widget.onSingleLongTapMoveUpdate!(
    //         details, renderEditor.getPositionForOffset)) {
    //       return;
    //     }
    //   }
    // }
    if (!delegate.getSelectionEnabled()) {
      return;
    }
    switch (Theme.of(_state.context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        getRenderEditor()?.selectPositionAt(
          details.globalPosition,
          null,
          SelectionChangedCause.longPress,
        );
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        getRenderEditor()?.selectWordsInRange(
          details.globalPosition - details.offsetFromOrigin,
          details.globalPosition,
          SelectionChangedCause.longPress,
        );
        break;
      default:
        throw 'Invalid platform';
    }
  }

  bool _onTapping(TapUpDetails details) {
    if (_state.widget.controller.document.isEmpty()) {
      return false;
    }
    final pos = getRenderEditor()!.getPositionForOffset(details.globalPosition);
    final result =
        getEditor()!.widget.controller.document.queryChild(pos.offset);
    if (result.node == null) {
      return false;
    }
    final line = result.node as Line;
    final segmentResult = line.queryChild(result.offset, false);
    if (segmentResult.node == null) {
      if (line.length == 1) {
        getEditor()?.widget.controller.updateSelection(
            TextSelection.collapsed(offset: pos.offset), ChangeSource.LOCAL);
        return true;
      }
      return false;
    }
    final segment = segmentResult.node as leaf.Leaf;
    if (segment.style.containsKey(Attribute.link.key)) {
      var launchUrl = getEditor()?.widget.onLaunchUrl;
      launchUrl ??= _launchUrl;
      String? link = segment.style.attributes[Attribute.link.key]!.value;
      if (!getEditor()!.widget.readOnly && link != null) {
        link = link.trim();
        if (!linkPrefixes
            .any((linkPrefix) => link!.toLowerCase().startsWith(linkPrefix))) {
          link = 'https://$link';
        }
        launchUrl(link);
      }
      return false;
    }
    // if (getEditor()!.widget.readOnly && segment.value is BlockEmbed) {
    //   final blockEmbed = segment.value as BlockEmbed;
    //   if (blockEmbed.type == 'image') {
    //     final imageUrl = _standardizeImageUrl(blockEmbed.data);
    //     Navigator.push(
    //       getEditor()!.context,
    //       MaterialPageRoute(
    //         builder: (context) => ImageTapWrapper(
    //           imageProvider: imageUrl.startsWith('http')
    //               ? NetworkImage(imageUrl)
    //               : isBase64(imageUrl)
    //                   ? Image.memory(base64.decode(imageUrl))
    //                       as ImageProvider<Object>?
    //                   : FileImage(io.File(imageUrl)),
    //         ),
    //       ),
    //     );
    //   }
    // }

    return false;
  }

  Future<void> _launchUrl(String url) async {
    await launch(url);
  }

  @override
  void onTapDown(TapDownDetails details) {
    // if (_state.widget.onTapDown != null) {
    //   final renderEditor = getRenderEditor();
    //   if (renderEditor != null) {
    //     if (_state.widget.onTapDown!(
    //         details, renderEditor.getPositionForOffset)) {
    //       return;
    //     }
    //   }
    // }
    super.onTapDown(details);
  }

  @override
  void onSingleTapUp(TapUpDetails details) {
    // if (_state.widget.onTapUp != null) {
    //   final renderEditor = getRenderEditor();
    //   if (renderEditor != null) {
    //     if (_state.widget.onTapUp!(
    //         details, renderEditor.getPositionForOffset)) {
    //       return;
    //     }
    //   }
    // }

    // getEditor()?.hideToolbar();

    final positionSelected = _onTapping(details);

    if (delegate.getSelectionEnabled() && !positionSelected) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              getRenderEditor()?.selectPosition(SelectionChangedCause.tap);
              break;
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              getRenderEditor()?.selectWordEdge(SelectionChangedCause.tap);
              break;
          }
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          getRenderEditor()?.selectPosition(SelectionChangedCause.tap);
          break;
      }
    }
    // _state._requestKeyboard();
  }

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    // if (_state.widget.onSingleLongTapStart != null) {
    //   final renderEditor = getRenderEditor();
    //   if (renderEditor != null) {
    //     if (_state.widget.onSingleLongTapStart!(
    //         details, renderEditor.getPositionForOffset)) {
    //       return;
    //     }
    //   }
    // }

    if (delegate.getSelectionEnabled()) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          getRenderEditor()?.selectPositionAt(
            details.globalPosition,
            null,
            SelectionChangedCause.longPress,
          );
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          getRenderEditor()?.selectWord(SelectionChangedCause.longPress);
          Feedback.forLongPress(_state.context);
          break;
        default:
          throw 'Invalid platform';
      }
    }
  }

  @override
  void onSingleLongTapEnd(LongPressEndDetails details) {
    // if (_state.widget.onSingleLongTapEnd != null) {
    //   final renderEditor = getRenderEditor();
    //   if (renderEditor != null) {
    //     if (_state.widget.onSingleLongTapEnd!(
    //         details, renderEditor.getPositionForOffset)) {
    //       return;
    //     }
    //   }
    // }
    super.onSingleLongTapEnd(details);
  }
}
