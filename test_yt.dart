import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final url = 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'; // Despacito
  print('Fetching video...');
  try {
    final video = await yt.videos.get(url);
    print('Title: ${video.title}');
    
    print('Fetching manifest...');
    final manifest = await yt.videos.streamsClient.getManifest(video.id);
    
    print('Audio only streams:');
    for (var s in manifest.audioOnly) {
      print(' - ${s.container.name} | ${s.bitrate} | ${s.size.totalMegaBytes} MB');
    }
    
    final videoStreams = manifest.muxed.where((s) => s.container.name == 'mp4');
    final streamInfo = videoStreams.isNotEmpty ? videoStreams.withHighestBitrate() : manifest.muxed.withHighestBitrate();
    
    print('Selected stream: ${streamInfo.container.name} | ${streamInfo.bitrate}');
    
    final mediaStream = yt.videos.streamsClient.get(streamInfo);
    int totalSize = streamInfo.size.totalBytes;
    print('Total size: $totalSize bytes');
    
    int downloaded = 0;
    await for (final chunk in mediaStream) {
      downloaded += chunk.length;
      print('Downloaded: ${(downloaded / totalSize * 100).toStringAsFixed(1)}%');
      if (downloaded > 100000) {
        print('Successfully downloaded a portion. Exiting test.');
        break;
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
    exit(0);
  }
}
