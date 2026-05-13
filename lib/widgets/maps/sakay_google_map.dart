import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/app_environment.dart';
import '../../config/map_config.dart';
import '../../services/google_maps_web_loader.dart';

class SakayGoogleMap extends StatefulWidget {
  final LatLng initialCameraTarget;
  final LatLngBounds? bounds;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final bool myLocationEnabled;
  final bool zoomControlsEnabled;
  final bool autoMoveCamera;
  final bool preferInitialCameraTarget;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onLongPress;

  const SakayGoogleMap({
    super.key,
    required this.initialCameraTarget,
    this.bounds,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.circles = const <Circle>{},
    this.myLocationEnabled = false,
    this.zoomControlsEnabled = false,
    this.autoMoveCamera = true,
    this.preferInitialCameraTarget = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<SakayGoogleMap> createState() => _SakayGoogleMapState();
}

class _SakayGoogleMapState extends State<SakayGoogleMap> {
  GoogleMapController? _controller;
  bool _isDisposed = false;

  @override
  void didUpdateWidget(covariant SakayGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.autoMoveCamera) {
      return;
    }

    final boundsChanged = !_sameBounds(widget.bounds, oldWidget.bounds);
    final targetChanged = !_sameLatLng(
      widget.initialCameraTarget,
      oldWidget.initialCameraTarget,
    );

    if (boundsChanged ||
        (widget.bounds == null && targetChanged) ||
        (widget.preferInitialCameraTarget && targetChanged)) {
      _scheduleMoveCamera();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<void>(
        future: ensureGoogleMapsWebSdkLoaded(
          AppEnvironment.googleServicesApiKey,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MapLoadError(message: _mapErrorMessage(snapshot.error));
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const _MapLoading();
          }

          return _buildGoogleMap();
        },
      );
    }

    return _buildGoogleMap();
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialCameraTarget,
        zoom: MapConfig.defaultZoom,
      ),
      markers: widget.markers,
      polylines: widget.polylines,
      circles: widget.circles,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationEnabled,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      mapToolbarEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (controller) {
        _controller = controller;
        if (widget.autoMoveCamera) {
          _scheduleMoveCamera();
        }
      },
    );
  }

  void _scheduleMoveCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _moveCamera();
      }
    });
  }

  Future<void> _moveCamera() async {
    final controller = _controller;
    if (controller == null || _isDisposed || !mounted) {
      return;
    }

    final bounds = widget.bounds;

    try {
      if (!widget.preferInitialCameraTarget &&
          bounds != null &&
          !_isSinglePoint(bounds)) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (_isDisposed || !mounted) {
          return;
        }
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 56),
        );
        return;
      }

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: widget.initialCameraTarget,
            zoom: MapConfig.routeZoom,
          ),
        ),
      );
    } catch (_) {
      // GoogleMap can reject camera bounds before the first layout pass.
    }
  }

  bool _isSinglePoint(LatLngBounds bounds) {
    return bounds.southwest.latitude == bounds.northeast.latitude &&
        bounds.southwest.longitude == bounds.northeast.longitude;
  }

  bool _sameBounds(LatLngBounds? a, LatLngBounds? b) {
    if (a == null || b == null) {
      return a == b;
    }

    return _sameLatLng(a.northeast, b.northeast) &&
        _sameLatLng(a.southwest, b.southwest);
  }

  bool _sameLatLng(LatLng a, LatLng b) {
    const tolerance = 0.000001;
    return (a.latitude - b.latitude).abs() < tolerance &&
        (a.longitude - b.longitude).abs() < tolerance;
  }

  String _mapErrorMessage(Object? error) {
    if (error is StateError) {
      return error.message;
    }

    return 'Unable to load the map. Please check the Google Maps setup.';
  }
}

class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF5F6FA),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MapLoadError extends StatelessWidget {
  final String message;

  const _MapLoadError({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F6FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
