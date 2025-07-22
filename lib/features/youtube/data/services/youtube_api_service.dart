import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class YouTubeApiService {
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  YouTubeApiService(this._functions, this._auth);

  Future<int> syncLikedVideos(String accessToken) async {
    try {
      // For 2nd Gen functions, we must call them directly via their URL.
      final callable = _functions.httpsCallableFromUrl(
        'https://sync-youtube-liked-videos-n7htuxxvja-uc.a.run.app',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
      });
      print('Sync result: ${result.data}');
      return result.data['synced'] as int;
    } on FirebaseFunctionsException catch (e) {
      print('Functions Error: ${e.code} ${e.message}');
      rethrow;
    }
  }
}
