import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/app_environment.dart';
import '../../config/map_config.dart';
import '../../services/google_maps_web_loader.dart';
import '../../utils/user_facing_error_message.dart';
import '../firebase_storage_image.dart';

@immutable
class MapProfilePin {
  final MarkerId markerId;
  final String name;
  final String? imageUrl;
  final String? detail;
  final Color accentColor;

  const MapProfilePin({
    required this.markerId,
    required this.name,
    this.imageUrl,
    this.detail,
    this.accentColor = const Color(0xFF2563FF),
  });

  String get initials {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }

  String? get normalizedDetail {
    final text = detail?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class SakayGoogleMap extends StatefulWidget {
  final LatLng initialCameraTarget;
  final LatLngBounds? bounds;
  final Set<Marker> markers;
  final List<MapProfilePin> profilePins;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final bool myLocationEnabled;
  final bool zoomControlsEnabled;
  final bool autoMoveCamera;
  final bool preferInitialCameraTarget;
  final MapType mapType;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onLongPress;

  const SakayGoogleMap({
    super.key,
    required this.initialCameraTarget,
    this.bounds,
    this.markers = const <Marker>{},
    this.profilePins = const <MapProfilePin>[],
    this.polylines = const <Polyline>{},
    this.circles = const <Circle>{},
    this.myLocationEnabled = false,
    this.zoomControlsEnabled = false,
    this.autoMoveCamera = true,
    this.preferInitialCameraTarget = false,
    this.mapType = MapType.normal,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<SakayGoogleMap> createState() => _SakayGoogleMapState();
}

class _SakayGoogleMapState extends State<SakayGoogleMap> {
  static const double _profilePinCardWidth = 184;
  static const double _profilePinCardMinWidth = 148;
  static const double _profilePinCardHeight = 98;
  static const double _profilePinCardHeightWithDetail = 134;
  static const double _profilePinTailHeight = 10;
  static const double _profilePinMarkerGap = 42;
  static const double _profilePinEdgePadding = 8;

  GoogleMapController? _controller;
  MarkerId? _selectedProfilePinId;
  ScreenCoordinate? _selectedProfilePinCoordinate;
  bool _isDisposed = false;

  @override
  void didUpdateWidget(covariant SakayGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    _syncSelectedProfilePin();

    if (!widget.autoMoveCamera) {
      return;
    }

    final boundsChanged = !_sameBounds(widget.bounds, oldWidget.bounds);
    final targetChanged = !_sameLatLng(
      widget.initialCameraTarget,
      oldWidget.initialCameraTarget,
    );
    final mapTypeChanged = widget.mapType != oldWidget.mapType;

    if (boundsChanged ||
        mapTypeChanged ||
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
          AppEnvironment.googleMapsWebApiKey,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.initialCameraTarget,
                  zoom: MapConfig.defaultZoom,
                ),
                markers: _effectiveMarkers(),
                polylines: widget.polylines,
                circles: widget.circles,
                mapType: widget.mapType,
                myLocationEnabled: widget.myLocationEnabled,
                myLocationButtonEnabled: widget.myLocationEnabled,
                zoomControlsEnabled: widget.zoomControlsEnabled,
                mapToolbarEnabled: false,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                zoomGesturesEnabled: true,
                onCameraMoveStarted: _handleCameraMoveStarted,
                onCameraIdle: _handleCameraIdle,
                onTap: _handleMapTap,
                onLongPress: widget.onLongPress,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                onMapCreated: (controller) {
                  _controller = controller;
                  if (widget.autoMoveCamera) {
                    _scheduleMoveCamera();
                  }
                  _scheduleSelectedProfilePinPositionUpdate();
                },
              ),
            ),
            ?_selectedProfilePinOverlay(constraints),
          ],
        );
      },
    );
  }

  Set<Marker> _effectiveMarkers() {
    if (widget.profilePins.isEmpty) {
      return widget.markers;
    }

    final profilePinIds = widget.profilePins.map((pin) => pin.markerId).toSet();

    return widget.markers.map((marker) {
      if (!profilePinIds.contains(marker.markerId)) {
        return marker;
      }

      final existingOnTap = marker.onTap;
      return marker.copyWith(
        consumeTapEventsParam: true,
        infoWindowParam: InfoWindow.noText,
        onTapParam: () {
          existingOnTap?.call();
          _selectProfilePin(marker.markerId);
        },
      );
    }).toSet();
  }

  Widget? _selectedProfilePinOverlay(BoxConstraints constraints) {
    final selectedPinId = _selectedProfilePinId;
    final coordinate = _selectedProfilePinCoordinate;
    if (selectedPinId == null || coordinate == null) {
      return null;
    }

    final pin = _profilePinFor(selectedPinId);
    if (pin == null) {
      return null;
    }

    final mapWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _profilePinCardWidth + (_profilePinEdgePadding * 2);
    final mapHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : _profilePinCardHeightWithDetail + _profilePinTailHeight;
    final maxCardWidth = mapWidth - (_profilePinEdgePadding * 2);
    final cardWidth = maxCardWidth < _profilePinCardWidth
        ? _clampDouble(
            maxCardWidth,
            _profilePinCardMinWidth,
            _profilePinCardWidth,
          )
        : _profilePinCardWidth;
    final cardHeight = pin.normalizedDetail == null
        ? _profilePinCardHeight
        : _profilePinCardHeightWithDetail;
    final overlayHeight = cardHeight + _profilePinTailHeight;
    final left = _clampDouble(
      coordinate.x - (cardWidth / 2),
      _profilePinEdgePadding,
      mapWidth - cardWidth - _profilePinEdgePadding,
    );
    final top = _clampDouble(
      coordinate.y - overlayHeight - _profilePinMarkerGap,
      _profilePinEdgePadding,
      mapHeight - overlayHeight - _profilePinEdgePadding,
    );
    final tailCenter = _clampDouble(coordinate.x - left, 18, cardWidth - 18);

    return Positioned(
      left: left,
      top: top,
      child: _MapProfilePinCard(
        pin: pin,
        width: cardWidth,
        cardHeight: cardHeight,
        tailCenter: tailCenter,
      ),
    );
  }

  void _selectProfilePin(MarkerId markerId) {
    if (_profilePinFor(markerId) == null) {
      return;
    }

    setState(() {
      _selectedProfilePinId = markerId;
      _selectedProfilePinCoordinate = null;
    });
    _scheduleSelectedProfilePinPositionUpdate();
  }

  void _handleMapTap(LatLng position) {
    if (_selectedProfilePinId != null) {
      setState(() {
        _selectedProfilePinId = null;
        _selectedProfilePinCoordinate = null;
      });
    }
    widget.onTap?.call(position);
  }

  void _handleCameraMoveStarted() {
    if (_selectedProfilePinCoordinate == null) {
      return;
    }

    setState(() => _selectedProfilePinCoordinate = null);
  }

  void _handleCameraIdle() {
    _scheduleSelectedProfilePinPositionUpdate();
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

  void _scheduleSelectedProfilePinPositionUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        unawaited(_updateSelectedProfilePinPosition());
      }
    });
  }

  Future<void> _updateSelectedProfilePinPosition() async {
    final selectedPinId = _selectedProfilePinId;
    final controller = _controller;
    if (selectedPinId == null || controller == null || _isDisposed) {
      return;
    }

    final marker = _markerFor(selectedPinId);
    if (marker == null) {
      if (mounted) {
        setState(() {
          _selectedProfilePinId = null;
          _selectedProfilePinCoordinate = null;
        });
      }
      return;
    }

    try {
      final coordinate = await controller.getScreenCoordinate(marker.position);
      if (_isDisposed || !mounted || _selectedProfilePinId != selectedPinId) {
        return;
      }

      setState(() => _selectedProfilePinCoordinate = coordinate);
    } on Exception {
      // Projection can fail briefly while the native map is settling.
    }
  }

  void _syncSelectedProfilePin() {
    final selectedPinId = _selectedProfilePinId;
    if (selectedPinId == null) {
      return;
    }

    if (_profilePinFor(selectedPinId) == null ||
        _markerFor(selectedPinId) == null) {
      _selectedProfilePinId = null;
      _selectedProfilePinCoordinate = null;
      return;
    }

    _scheduleSelectedProfilePinPositionUpdate();
  }

  MapProfilePin? _profilePinFor(MarkerId markerId) {
    for (final pin in widget.profilePins) {
      if (pin.markerId == markerId) {
        return pin;
      }
    }

    return null;
  }

  Marker? _markerFor(MarkerId markerId) {
    for (final marker in widget.markers) {
      if (marker.markerId == markerId) {
        return marker;
      }
    }

    return null;
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
    return userFacingErrorMessage(
      error,
      fallback: 'Unable to load the map. Please try again later.',
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (max < min) {
      return min;
    }

    return value.clamp(min, max).toDouble();
  }
}

class _MapProfilePinCard extends StatelessWidget {
  final MapProfilePin pin;
  final double width;
  final double cardHeight;
  final double tailCenter;

  const _MapProfilePinCard({
    required this.pin,
    required this.width,
    required this.cardHeight,
    required this.tailCenter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detail = pin.normalizedDetail;
    final surface = colorScheme.surface;
    final textColor = colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        height: cardHeight + _SakayGoogleMapState._profilePinTailHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: width,
              height: cardHeight,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.75),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _ProfilePinAvatar(pin: pin),
                  const SizedBox(height: 8),
                  Text(
                    pin.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: cardHeight - 5,
              left: tailCenter - 7,
              child: Transform.rotate(
                angle: 0.7853981634,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePinAvatar extends StatelessWidget {
  final MapProfilePin pin;

  const _ProfilePinAvatar({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: pin.accentColor.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: pin.imageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: pin.accentColor.withValues(alpha: 0.13),
            alignment: Alignment.center,
            child: Text(
              pin.initials,
              style: TextStyle(
                color: pin.accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
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
