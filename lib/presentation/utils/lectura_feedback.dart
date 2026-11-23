import 'package:audioplayers/audioplayers.dart';

class LecturaFeedback {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> correcta() =>
      _audioPlayer.play(AssetSource('sounds/lectura_correcta.mp3'));

  static Future<void> error() =>
      _audioPlayer.play(AssetSource('sounds/error_lectura.mp3'));
}
