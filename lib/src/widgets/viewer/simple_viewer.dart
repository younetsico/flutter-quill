import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/src/widgets/image.dart';
import 'package:flutter_quill/src/widgets/text_selection.dart';
import 'package:flutter_quill/src/widgets/viewer/delegate.dart';
import 'package:string_validator/string_validator.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/documents/attribute.dart';
import '../../models/documents/document.dart';
import '../../models/documents/nodes/block.dart';
import '../../models/documents/nodes/leaf.dart' as leaf;
import '../../models/documents/nodes/line.dart';
import '../controller.dart';
import '../cursor.dart';
import '../default_styles.dart';
import '../delegate.dart';
import '../editor.dart';
import '../text_block.dart';
import '../text_line.dart';
import '../video_app.dart';
import '../youtube_video_app.dart';

class QuillSimpleViewer extends StatefulWidget {
  const QuillSimpleViewer({
    required this.controller,
    required this.readOnly,
    this.customStyles,
    this.truncate = false,
    this.truncateScale,
    this.truncateAlignment,
    this.truncateHeight,
    this.truncateWidth,
    this.scrollBottomInset = 0,
    this.padding = EdgeInsets.zero,
    this.options = const {},
    this.embedBuilder,
    this.onCheckBoxTap,
    Key? key,
    this.onTapViewer,
  })  : assert(truncate ||
            ((truncateScale == null) &&
                (truncateAlignment == null) &&
                (truncateHeight == null) &&
                (truncateWidth == null))),
        super(key: key);

  final QuillController controller;
  final DefaultStyles? customStyles;
  final bool truncate;
  final double? truncateScale;
  final Alignment? truncateAlignment;
  final double? truncateHeight;
  final double? truncateWidth;
  final double scrollBottomInset;
  final EdgeInsetsGeometry padding;
  final EmbedBuilder? embedBuilder;
  final Map<String, String>? options;
  final bool readOnly;
  final Function(int offset, bool value)? onCheckBoxTap;
  final Function()? onTapViewer;

  @override
  QuillSimpleViewerState createState() => QuillSimpleViewerState();
}

class QuillSimpleViewerState extends State<QuillSimpleViewer>
    with SingleTickerProviderStateMixin
    implements ViewerSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<ViewerState> _editorKey = GlobalKey<ViewerState>();
  late QuillViewerSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  @override
  void initState() {
    _selectionGestureDetectorBuilder =
        QuillViewerSelectionGestureDetectorBuilder(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _selectionGestureDetectorBuilder.build(
        HitTestBehavior.deferToChild,
        QuillViewer(
          controller: widget.controller,
          onTapViewer: widget.onTapViewer,
          readOnly: widget.readOnly,
          customStyles: widget.customStyles,
          embedBuilder: widget.embedBuilder,
          key: _editorKey,
          onCheckBoxTap: widget.onCheckBoxTap,
          options: widget.options,
          padding: widget.padding,
          scrollBottomInset: widget.scrollBottomInset,
          truncate: widget.truncate,
          truncateAlignment: widget.truncateAlignment,
          truncateHeight: widget.truncateHeight,
          truncateScale: widget.truncateScale,
          truncateWidth: widget.truncateWidth,
        ));
  }

  @override
  GlobalKey<ViewerState> getEditableTextKey() {
    return _editorKey;
  }

  @override
  bool getForcePressEnabled() {
    return true;
  }

  @override
  bool getSelectionEnabled() {
    return true;
  }
}

// ignore: unused_element
class QuillViewer extends StatefulWidget {
  const QuillViewer({
    required this.controller,
    required this.readOnly,
    this.customStyles,
    this.truncate = false,
    this.truncateScale,
    this.truncateAlignment,
    this.truncateHeight,
    this.truncateWidth,
    this.scrollBottomInset = 0,
    this.padding = EdgeInsets.zero,
    this.options = const {},
    this.embedBuilder,
    this.onCheckBoxTap,
    this.onTapViewer,
    Key? key,
    this.onLaunchUrl,
  })  : assert(truncate ||
            ((truncateScale == null) &&
                (truncateAlignment == null) &&
                (truncateHeight == null) &&
                (truncateWidth == null))),
        super(key: key);
  final QuillController controller;
  final DefaultStyles? customStyles;
  final bool truncate;
  final double? truncateScale;
  final Alignment? truncateAlignment;
  final double? truncateHeight;
  final double? truncateWidth;
  final double scrollBottomInset;
  final EdgeInsetsGeometry padding;
  final EmbedBuilder? embedBuilder;
  final Map<String, String>? options;
  final bool readOnly;
  final Function(String)? onLaunchUrl;
  final Function(int offset, bool value)? onCheckBoxTap;
  final Function()? onTapViewer;

  @override
  __QuillViewerState createState() => __QuillViewerState();
}

class __QuillViewerState extends ViewerState
    with SingleTickerProviderStateMixin {
  late DefaultStyles _styles;
  final LayerLink _toolbarLayerLink = LayerLink();
  final LayerLink _startHandleLayerLink = LayerLink();
  final LayerLink _endHandleLayerLink = LayerLink();
  late CursorCont _cursorCont;
  final GlobalKey _editorKey = GlobalKey();
  @override
  void initState() {
    super.initState();

    _cursorCont = CursorCont(
      show: ValueNotifier<bool>(false),
      style: const CursorStyle(
        color: Colors.black,
        backgroundColor: Colors.grey,
        width: 2,
        radius: Radius.zero,
        offset: Offset.zero,
      ),
      tickerProvider: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentStyles = QuillStyles.getStyles(context, true);
    final defaultStyles = DefaultStyles.getInstance(context);
    _styles = (parentStyles != null)
        ? defaultStyles.merge(parentStyles)
        : defaultStyles;

    if (widget.customStyles != null) {
      _styles = _styles.merge(widget.customStyles!);
    }
  }

  EmbedBuilder get embedBuilder => widget.embedBuilder ?? _defaultEmbedBuilder;

  Widget _defaultEmbedBuilder(
      BuildContext context, leaf.Embed node, bool readOnly) {
    assert(!kIsWeb, 'Please provide EmbedBuilder for Web');
    switch (node.value.type) {
      case 'image':
        final imageUrl = _standardizeImageUrl(node.value.data);
        return imageUrl.startsWith('http')
            ? Image.network(
                imageUrl,
                headers: widget.options,
              )
            : isBase64(imageUrl)
                ? Image.memory(base64.decode(imageUrl))
                : Image.file(io.File(imageUrl));
      case 'video':
        final videoUrl = node.value.data;
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          return YoutubeVideoApp(
              videoUrl: videoUrl, context: context, readOnly: readOnly);
        }
        return VideoApp(videoUrl: videoUrl, readOnly: readOnly);
      default:
        throw UnimplementedError(
          'Embeddable type "${node.value.type}" is not supported by default '
          'embed builder of QuillEditor. You must pass your own builder '
          'function to embedBuilder property of QuillEditor or QuillField '
          'widgets.',
        );
    }
  }

  String _standardizeImageUrl(String url) {
    if (url.contains('base64')) {
      return url.split(',')[1];
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final _doc = widget.controller.document;
    // if (_doc.isEmpty() &&
    //     !widget.focusNode.hasFocus &&
    //     widget.placeholder != null) {
    //   _doc = Document.fromJson(jsonDecode(
    //       '[{"attributes":{"placeholder":true},"insert":"${widget.placeholder}\\n"}]'));
    // }

    Widget child = CompositedTransformTarget(
      link: _toolbarLayerLink,
      child: Semantics(
        child: _SimpleViewer(
          key: _editorKey,
          document: _doc,
          textDirection: _textDirection,
          startHandleLayerLink: _startHandleLayerLink,
          endHandleLayerLink: _endHandleLayerLink,
          onSelectionChanged: _nullSelectionChanged,
          scrollBottomInset: widget.scrollBottomInset,
          padding: widget.padding,
          children: _buildChildren(_doc, context),
        ),
      ),
    );

    if (widget.truncate) {
      if (widget.truncateScale != null) {
        child = Container(
            height: widget.truncateHeight,
            child: Align(
                heightFactor: widget.truncateScale,
                widthFactor: widget.truncateScale,
                alignment: widget.truncateAlignment ?? Alignment.topLeft,
                child: Container(
                    width: widget.truncateWidth! / widget.truncateScale!,
                    child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Transform.scale(
                            scale: widget.truncateScale!,
                            alignment:
                                widget.truncateAlignment ?? Alignment.topLeft,
                            child: child)))));
      } else {
        child = Container(
            height: widget.truncateHeight,
            width: widget.truncateWidth,
            child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(), child: child));
      }
    }
    return QuillStyles(data: _styles, child: child);
  }

  List<Widget> _buildChildren(Document doc, BuildContext context) {
    final result = <Widget>[];
    final indentLevelCounts = <int, int>{};
    for (final node in doc.root.children) {
      if (node is Line) {
        final editableTextLine = _getEditableTextLineFromNode(node, context);
        result.add(editableTextLine);
      } else if (node is Block) {
        final attrs = node.style.attributes;
        final editableTextBlock = EditableTextBlock(
            node,
            _textDirection,
            widget.scrollBottomInset,
            _getVerticalSpacingForBlock(node, _styles),
            widget.controller.selection,
            Colors.black,
            // selectionColor,
            _styles,
            false,
            // enableInteractiveSelection,
            false,
            // hasFocus,
            attrs.containsKey(Attribute.codeBlock.key)
                ? const EdgeInsets.all(16)
                : null,
            embedBuilder,
            _cursorCont,
            indentLevelCounts,
            _handleCheckboxTap,
            widget.readOnly);
        result.add(editableTextBlock);
      } else {
        throw StateError('Unreachable.');
      }
    }
    return result;
  }

  /// Updates the checkbox positioned at [offset] in document
  /// by changing its attribute according to [value].
  void _handleCheckboxTap(int offset, bool value) {
    // readonly - do nothing
    if (!widget.readOnly) {
      widget.onCheckBoxTap?.call(offset, value);
      if (value) {
        widget.controller.formatText(offset, 0, Attribute.checked);
      } else {
        widget.controller.formatText(offset, 0, Attribute.unchecked);
      }
      setState(() {});
    }
  }

  TextDirection get _textDirection {
    final result = Directionality.of(context);
    return result;
  }

  EditableTextLine _getEditableTextLineFromNode(
      Line node, BuildContext context) {
    final textLine = TextLine(
      line: node,
      textDirection: _textDirection,
      embedBuilder: embedBuilder,
      styles: _styles,
      readOnly: widget.readOnly,
    );

    final editableTextLine = EditableTextLine(
        node,
        null,
        textLine,
        0,
        _getVerticalSpacingForLine(node, _styles),
        _textDirection,
        widget.controller.selection,
        Colors.black,
        //widget.selectionColor,
        true,
        //enableInteractiveSelection,
        true,
        //_hasFocus,
        MediaQuery.of(context).devicePixelRatio,
        _cursorCont);
    return editableTextLine;
  }

  Tuple2<double, double> _getVerticalSpacingForLine(
      Line line, DefaultStyles? defaultStyles) {
    final attrs = line.style.attributes;
    if (attrs.containsKey(Attribute.header.key)) {
      final int? level = attrs[Attribute.header.key]!.value;
      switch (level) {
        case 1:
          return defaultStyles!.h1!.verticalSpacing;
        case 2:
          return defaultStyles!.h2!.verticalSpacing;
        case 3:
          return defaultStyles!.h3!.verticalSpacing;
        default:
          throw 'Invalid level $level';
      }
    }

    return defaultStyles!.paragraph!.verticalSpacing;
  }

  Tuple2<double, double> _getVerticalSpacingForBlock(
      Block node, DefaultStyles? defaultStyles) {
    final attrs = node.style.attributes;
    if (attrs.containsKey(Attribute.blockQuote.key)) {
      return defaultStyles!.quote!.verticalSpacing;
    } else if (attrs.containsKey(Attribute.codeBlock.key)) {
      return defaultStyles!.code!.verticalSpacing;
    } else if (attrs.containsKey(Attribute.indent.key)) {
      return defaultStyles!.indent!.verticalSpacing;
    }
    return defaultStyles!.lists!.verticalSpacing;
  }

  void _nullSelectionChanged(
      TextSelection selection, SelectionChangedCause cause) {
    widget.onTapViewer?.call();
  }

  @override
  RenderEditor? getRenderEditor() {
    final obj = _editorKey.currentContext?.findRenderObject();
    return obj as RenderEditor?;
  }
}

class _SimpleViewer extends MultiChildRenderObjectWidget {
  _SimpleViewer({
    required List<Widget> children,
    required this.document,
    required this.textDirection,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.onSelectionChanged,
    required this.scrollBottomInset,
    this.padding = EdgeInsets.zero,
    Key? key,
  }) : super(key: key, children: children);

  final Document document;
  final TextDirection textDirection;
  final LayerLink startHandleLayerLink;
  final LayerLink endHandleLayerLink;
  final TextSelectionChangedHandler onSelectionChanged;
  final double scrollBottomInset;
  final EdgeInsetsGeometry padding;

  @override
  RenderEditor createRenderObject(BuildContext context) {
    return RenderEditor(
      null,
      textDirection,
      scrollBottomInset,
      padding,
      document,
      const TextSelection(baseOffset: 0, extentOffset: 0),
      true,
      // hasFocus,
      onSelectionChanged,
      startHandleLayerLink,
      endHandleLayerLink,
      const EdgeInsets.fromLTRB(4, 4, 4, 5),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditor renderObject) {
    renderObject
      ..document = document
      ..setContainer(document.root)
      ..textDirection = textDirection
      ..setStartHandleLayerLink(startHandleLayerLink)
      ..setEndHandleLayerLink(endHandleLayerLink)
      ..onSelectionChanged = onSelectionChanged
      ..setScrollBottomInset(scrollBottomInset)
      ..setPadding(padding);
  }
}
