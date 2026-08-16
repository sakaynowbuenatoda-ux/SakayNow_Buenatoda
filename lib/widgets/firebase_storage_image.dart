import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageImage extends StatelessWidget {
  static final Map<String, String> _resolvedUrlCache = <String, String>{};
  static final Map<String, Future<String>> _downloadFutureCache =
      <String, Future<String>>{};

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;
  final Widget? loading;
  final Widget? errorFallback;

  const FirebaseStorageImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loading,
    this.errorFallback,
  });

  @override
  Widget build(BuildContext context) {
    final source = imageUrl?.trim();
    if (source == null || source.isEmpty || source == 'null') {
      return fallback;
    }

    final cachedUrl = _resolvedUrlCache[source];
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return _networkImage(cachedUrl);
    }

    return FutureBuilder<String>(
      key: ValueKey<String>('firebase_storage_image_${source.hashCode}'),
      future: _cachedDownloadUrlFor(source),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? fallback;
        }

        if (resolvedUrl == null || resolvedUrl.isEmpty || snapshot.hasError) {
          return errorFallback ?? fallback;
        }

        return _networkImage(resolvedUrl);
      },
    );
  }

  Widget _networkImage(String resolvedUrl) {
    return Image.network(
      resolvedUrl,
      key: ValueKey<String>('firebase_storage_network_${resolvedUrl.hashCode}'),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => errorFallback ?? fallback,
    );
  }

  static Future<String> _cachedDownloadUrlFor(String source) {
    final cachedUrl = _resolvedUrlCache[source];
    if (cachedUrl != null) {
      return Future<String>.value(cachedUrl);
    }

    return _downloadFutureCache.putIfAbsent(source, () async {
      final resolvedUrl = await _downloadUrlFor(source);
      _resolvedUrlCache[source] = resolvedUrl;
      return resolvedUrl;
    });
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
