import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../flutter_quill.dart';

class YoutubeVideoApp extends StatefulWidget {
  const YoutubeVideoApp(
      {required this.videoUrl, required this.context, required this.readOnly});

  final String videoUrl;
  final BuildContext context;
  final bool readOnly;

  @override
  _YoutubeVideoAppState createState() => _YoutubeVideoAppState();
}

class _YoutubeVideoAppState extends State<YoutubeVideoApp> {
  YoutubePlayerController? _youtubeController;
  String? videoId;
  bool canShowPlayer = false;
  @override
  void initState() {
    super.initState();

    videoId = YoutubePlayer.convertUrlToId(
        'https://www.youtube.com/watch?v=4zUQEkDdNR0');
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId!,
        flags: const YoutubePlayerFlags(
          captionLanguage: 'vi',
          loop: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyles = DefaultStyles.getInstance(context);
    if (!canShowPlayer) {
      final ytbThumbnail = YoutubePlayer.getThumbnail(
        videoId: videoId ?? '',
        quality: ThumbnailQuality.high,
      );
      return GestureDetector(
        onTap: () => setState(() => canShowPlayer = !canShowPlayer),
        child: AspectRatio(
          aspectRatio: 360 / 202.5,
          child: Image.network(
            ytbThumbnail,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (_youtubeController == null) {
      if (widget.readOnly) {
        return RichText(
          text: TextSpan(
              text: widget.videoUrl,
              style: defaultStyles.link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => launch(widget.videoUrl)),
        );
      }

      return RichText(
          text: TextSpan(text: widget.videoUrl, style: defaultStyles.link));
    }
    // _youtubeController?.toggleFullScreenMode();

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Column(
          children: [
            // some widgets
            player,
            //some other widgets
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }
}
