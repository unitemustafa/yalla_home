import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../domain/courier_order.dart';

class CourierTrackingMapView extends StatefulWidget {
  const CourierTrackingMapView({super.key, required this.order});

  final CourierOrder order;

  @override
  State<CourierTrackingMapView> createState() => _CourierTrackingMapViewState();
}

class _CourierTrackingMapViewState extends State<CourierTrackingMapView> {
  static const _cairoFallback = LatLng(30.0444, 31.2357);
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _courierLocation;
  LatLng? _lastTrackedLocation;
  String? _locationMessage;
  bool _isLoadingLocation = true;
  bool _followCourier = true;
  bool _hasLocationPermission = false;
  bool _cameraMoveFromCode = false;
  bool _openAppSettings = false;
  bool _openLocationSettings = false;
  double _travelledMeters = 0;
  double? _initialDistanceMeters;
  double _speedMetersPerSecond = 0;
  double _heading = 0;

  LatLng? get _customerLocation {
    final location = widget.order.customerLocation;
    if (location == null) return null;
    return LatLng(location.latitude, location.longitude);
  }

  double? get _remainingMeters {
    final courier = _courierLocation;
    final customer = _customerLocation;
    if (courier == null || customer == null) return null;
    return Geolocator.distanceBetween(
      courier.latitude,
      courier.longitude,
      customer.latitude,
      customer.longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    if (_customerLocation == null) {
      _isLoadingLocation = false;
      _locationMessage = 'موقع العميل غير متاح لهذا الطلب.';
    } else {
      unawaited(_startTracking());
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    await _positionSubscription?.cancel();
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
      _openAppSettings = false;
      _openLocationSettings = false;
    });

    final locationError = await _checkLocationAccess();
    if (locationError != null) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = locationError;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasLocationPermission = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      _handlePosition(position, fitRoute: true);

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: _locationSettings,
          ).listen(
            _handlePosition,
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _isLoadingLocation = false;
                _locationMessage = 'تعذر تحديث موقعك الحالي.';
              });
            },
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = 'تعذر تحديد موقعك الحالي.';
      });
    }
  }

  Future<String?> _checkLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _openLocationSettings = true;
      return 'خدمة الموقع متوقفة على الجهاز.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return 'لم يتم السماح للتطبيق باستخدام موقعك.';
    }

    if (permission == LocationPermission.deniedForever) {
      _openAppSettings = true;
      return 'صلاحية الموقع مرفوضة من إعدادات التطبيق.';
    }

    return null;
  }

  void _handlePosition(Position position, {bool fitRoute = false}) {
    if (!mounted) return;

    final nextLocation = LatLng(position.latitude, position.longitude);
    final previousLocation = _lastTrackedLocation;
    var travelledMeters = _travelledMeters;

    if (previousLocation != null) {
      final stepMeters = Geolocator.distanceBetween(
        previousLocation.latitude,
        previousLocation.longitude,
        nextLocation.latitude,
        nextLocation.longitude,
      );
      if (stepMeters >= 3 && stepMeters <= 500) {
        travelledMeters += stepMeters;
      }
    }

    final customer = _customerLocation;
    final initialDistanceMeters =
        _initialDistanceMeters ??
        (customer == null
            ? null
            : Geolocator.distanceBetween(
                nextLocation.latitude,
                nextLocation.longitude,
                customer.latitude,
                customer.longitude,
              ));

    setState(() {
      _courierLocation = nextLocation;
      _lastTrackedLocation = nextLocation;
      _travelledMeters = travelledMeters;
      _initialDistanceMeters = initialDistanceMeters;
      _speedMetersPerSecond = position.speed.isFinite
          ? math.max(position.speed, 0)
          : 0;
      _heading = position.heading.isFinite && position.heading >= 0
          ? position.heading
          : _heading;
      _isLoadingLocation = false;
      _locationMessage = null;
    });

    if (fitRoute) {
      unawaited(_fitRoute());
    } else if (_followCourier) {
      unawaited(_animateToCourier());
    }
  }

  Future<void> _animateToCourier() async {
    final courier = _courierLocation;
    if (_mapController == null || courier == null) return;

    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: courier, zoom: 17, tilt: 45, bearing: _heading),
      ),
    );
  }

  Future<void> _animateCamera(CameraUpdate cameraUpdate) async {
    final controller = _mapController;
    if (controller == null) return;

    _cameraMoveFromCode = true;
    try {
      await controller.animateCamera(cameraUpdate);
    } finally {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          _cameraMoveFromCode = false;
        }),
      );
    }
  }

  Future<void> _fitRoute() async {
    final customer = _customerLocation;
    if (_mapController == null || customer == null) return;

    final courier = _courierLocation;
    try {
      if (courier == null) {
        await _animateCamera(CameraUpdate.newLatLngZoom(customer, 15));
        return;
      }

      await _animateCamera(
        CameraUpdate.newLatLngBounds(_boundsFor(courier, customer), 86),
      );
    } catch (_) {
      await _animateCamera(CameraUpdate.newLatLngZoom(customer, 15));
    }
  }

  LatLngBounds _boundsFor(LatLng first, LatLng second) {
    final minLat = math.min(first.latitude, second.latitude);
    final maxLat = math.max(first.latitude, second.latitude);
    final minLng = math.min(first.longitude, second.longitude);
    final maxLng = math.max(first.longitude, second.longitude);
    const padding = 0.004;

    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Set<Marker> _buildMarkers() {
    final customer = _customerLocation;
    final courier = _courierLocation;

    return {
      if (customer != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: customer,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.order.customerName,
            snippet: widget.order.address,
          ),
        ),
      if (courier != null)
        Marker(
          markerId: const MarkerId('courier'),
          position: courier,
          rotation: _heading,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'موقعي الحالي'),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final customer = _customerLocation;
    final courier = _courierLocation;
    if (customer == null || courier == null) return {};

    return {
      Polyline(
        polylineId: const PolylineId('courier-route'),
        points: [courier, customer],
        color: AppColors.primary,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Future<void> _recenter() async {
    setState(() => _followCourier = true);
    if (_courierLocation == null) {
      await _fitRoute();
      return;
    }
    await _animateToCourier();
  }

  Future<void> _openSettings() async {
    if (_openAppSettings) {
      await Geolocator.openAppSettings();
      return;
    }
    if (_openLocationSettings) {
      await Geolocator.openLocationSettings();
    }
  }

  String get _statusLabel {
    if (_locationMessage != null) return _locationMessage!;
    if (_isLoadingLocation) return 'جاري تحديد موقعك...';
    if (_remainingMeters != null && _remainingMeters! <= 60) {
      return 'أنت قريب من العميل';
    }
    return _followCourier ? 'تتبع مباشر' : 'استعراض الخريطة';
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _customerLocation ?? _cairoFallback;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: _customerLocation == null ? 11 : 15,
            ),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            buildingsEnabled: true,
            trafficEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(
                Future<void>.delayed(
                  const Duration(milliseconds: 350),
                  _fitRoute,
                ),
              );
            },
            onCameraMoveStarted: () {
              if (_followCourier && !_cameraMoveFromCode) {
                setState(() => _followCourier = false);
              }
            },
          ),
          PositionedDirectional(
            top: 10,
            start: 12,
            end: 12,
            child: SafeArea(
              child: Row(
                children: [
                  _MapIconButton(
                    icon: Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MapHeader(
                      order: widget.order,
                      statusLabel: _statusLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MapIconButton(
                    icon: Icons.my_location_rounded,
                    isActive: _followCourier,
                    onPressed: () => unawaited(_recenter()),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 12,
            child: SafeArea(
              child: _TrackingPanel(
                order: widget.order,
                remainingMeters: _remainingMeters,
                totalMeters: _initialDistanceMeters,
                travelledMeters: _travelledMeters,
                speedMetersPerSecond: _speedMetersPerSecond,
                isLoading: _isLoadingLocation,
                message: _locationMessage,
                canOpenSettings: _openAppSettings || _openLocationSettings,
                onRetry: () => unawaited(_startTracking()),
                onOpenSettings: () => unawaited(_openSettings()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.order, required this.statusLabel});

  final CourierOrder order;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                AppIcons.routing,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.id} • $statusLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: isActive ? Colors.white : AppColors.lightTextPrimary,
          tooltip: isActive ? 'التتبع مفعل' : null,
        ),
      ),
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({
    required this.order,
    required this.remainingMeters,
    required this.totalMeters,
    required this.travelledMeters,
    required this.speedMetersPerSecond,
    required this.isLoading,
    required this.message,
    required this.canOpenSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CourierOrder order;
  final double? remainingMeters;
  final double? totalMeters;
  final double travelledMeters;
  final double speedMetersPerSecond;
  final bool isLoading;
  final String? message;
  final bool canOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        order.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricTile(
                  icon: AppIcons.routing,
                  label: 'الإجمالي',
                  value: _formatDistance(totalMeters),
                ),
                _MetricTile(
                  icon: AppIcons.location,
                  label: 'متبقي',
                  value: _formatDistance(remainingMeters),
                ),
                _MetricTile(
                  icon: AppIcons.direct_right,
                  label: 'تم قطعه',
                  value: _formatDistance(travelledMeters),
                ),
                _MetricTile(
                  icon: Icons.speed_rounded,
                  label: 'السرعة',
                  value: _formatSpeed(speedMetersPerSecond),
                ),
                _MetricTile(
                  icon: AppIcons.calendar,
                  label: 'الوصول',
                  value: _formatEta(remainingMeters, speedMetersPerSecond),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                  if (canOpenSettings) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('الإعدادات'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDistance(double? meters) {
    if (meters == null || !meters.isFinite) return '--';
    if (meters < 1000) return '${meters.round()} م';
    final kilometers = meters / 1000;
    final digits = kilometers >= 10 ? 0 : 1;
    return '${kilometers.toStringAsFixed(digits)} كم';
  }

  static String _formatSpeed(double metersPerSecond) {
    if (!metersPerSecond.isFinite || metersPerSecond <= 0) return '0 كم/س';
    return '${(metersPerSecond * 3.6).round()} كم/س';
  }

  static String _formatEta(double? meters, double metersPerSecond) {
    if (meters == null || !meters.isFinite) return '--';
    final effectiveSpeed = metersPerSecond > 1 ? metersPerSecond : 8.3;
    final minutes = math.max(1, (meters / effectiveSpeed / 60).ceil());
    if (minutes < 60) return '$minutes د';

    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    if (restMinutes == 0) return '$hours س';
    return '$hours س $restMinutes د';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
