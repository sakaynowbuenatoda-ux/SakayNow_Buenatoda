import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/map_config.dart';
import '../../../core/preferences/app_preferences_controller.dart';
import '../../../widgets/maps/map_type_toggle.dart';
import '../../../widgets/maps/sakay_google_map.dart';
import '../admin_models.dart';
import '../admin_service.dart';
import 'admin_shared.dart';

class AdminLiveDriverMap extends StatelessWidget {
  const AdminLiveDriverMap({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminDriverLocationRecord>>(
      stream: AdminService.watchActiveDriverLocations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminErrorCard(
            message: 'Unable to load live driver locations: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const _AdminLiveDriverMapLoading();
        }

        return _AdminLiveDriverMapContent(
          drivers: snapshot.data ?? const <AdminDriverLocationRecord>[],
        );
      },
    );
  }
}

class _AdminLiveDriverMapContent extends StatelessWidget {
  final List<AdminDriverLocationRecord> drivers;

  const _AdminLiveDriverMapContent({required this.drivers});

  @override
  Widget build(BuildContext context) {
    final hasDrivers = drivers.isNotEmpty;
    final mapHeight = _mapHeightFor(MediaQuery.sizeOf(context).width);
    final initialTarget = hasDrivers
        ? drivers.first.latLng
        : MapConfig.buenavistaMunicipalHall;

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AdminUi.soft(AdminUi.secondary),
                  borderRadius: AdminUi.radius,
                ),
                child: Icon(
                  Icons.map_rounded,
                  color: AdminUi.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Driver Map', style: AdminUi.sectionTitle),
                    const SizedBox(height: 2),
                    Text(
                      hasDrivers
                          ? '${drivers.length} active driver${drivers.length == 1 ? '' : 's'} currently visible'
                          : 'Buenavista, Bohol is ready for active driver locations',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.bodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: AdminUi.radius,
            child: SizedBox(
              height: mapHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: AppPreferencesController.instance,
                      builder: (context, _) {
                        return SakayGoogleMap(
                          initialCameraTarget: initialTarget,
                          bounds: hasDrivers
                              ? _boundsForDrivers(drivers)
                              : null,
                          markers: _driverMarkers(drivers),
                          mapType:
                              AppPreferencesController.instance.googleMapType,
                          zoomControlsEnabled: true,
                          preferInitialCameraTarget: !hasDrivers,
                        );
                      },
                    ),
                  ),
                  const Positioned(top: 10, right: 10, child: MapTypeToggle()),
                  if (!hasDrivers)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _MapEmptyOverlay(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _driverMarkers(List<AdminDriverLocationRecord> drivers) {
    return drivers.map((driver) {
      return Marker(
        markerId: MarkerId('admin_driver_${driver.driverId}'),
        position: driver.latLng,
        infoWindow: InfoWindow(
          title: driver.fullName,
          snippet: 'Active driver',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        flat: driver.heading != null,
        rotation: driver.heading ?? 0,
      );
    }).toSet();
  }

  LatLngBounds _boundsForDrivers(List<AdminDriverLocationRecord> drivers) {
    var minLat = drivers.first.latLng.latitude;
    var maxLat = drivers.first.latLng.latitude;
    var minLng = drivers.first.latLng.longitude;
    var maxLng = drivers.first.latLng.longitude;

    for (final driver in drivers.skip(1)) {
      final position = driver.latLng;
      minLat = position.latitude < minLat ? position.latitude : minLat;
      maxLat = position.latitude > maxLat ? position.latitude : maxLat;
      minLng = position.longitude < minLng ? position.longitude : minLng;
      maxLng = position.longitude > maxLng ? position.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

double _mapHeightFor(double width) {
  if (width >= 1200) {
    return 520;
  }

  if (width >= 700) {
    return 420;
  }

  return 300;
}

class _AdminLiveDriverMapLoading extends StatelessWidget {
  const _AdminLiveDriverMapLoading();

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: _mapHeightFor(MediaQuery.sizeOf(context).width),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MapEmptyOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AdminUi.surface.withValues(alpha: 0.94),
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: AdminUi.body, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No active drivers are currently online.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
