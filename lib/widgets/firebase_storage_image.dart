import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const FirebaseStorageImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final source = imageUrl?.trim();
    if (source == null || source.isEmpty || source == 'null') {
      return fallback;
    }

    return FutureBuilder<String>(
      future: _downloadUrlFor(source),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback;
        }

        if (resolvedUrl == null || resolvedUrl.isEmpty || snapshot.hasError) {
          return fallback;
        }

        return Image.network(
          resolvedUrl,
          width: width,
          height: height,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }

  static Future<String> _downloadUrlFor(String source) async {
    if (_isNetworkUrl(source)) {
      return source;
    }

    if (source.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(source).getDownloadURL();
    }

    if (_isLikelyStoragePath(source)) {
      return FirebaseStorage.instance.ref(source).getDownloadURL();
    }

    return source;
  }

  static bool _isNetworkUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:');
  }

  static bool _isLikelyStoragePath(String value) {
    return !value.startsWith('gs://') && !_isNetworkUrl(value);
  }
}
