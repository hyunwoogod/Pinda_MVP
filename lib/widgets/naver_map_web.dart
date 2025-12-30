import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 네이버 지도 JS API를 Flutter Web에서 사용하기 위한 위젯
class NaverMapWeb extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;
  final List<NaverMapMarker> markers;
  final Function(double lat, double lng)? onMapTapped;
  final Function(NaverMapWebController)? onMapReady;

  const NaverMapWeb({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 14,
    this.markers = const [],
    this.onMapTapped,
    this.onMapReady,
  });

  @override
  State<NaverMapWeb> createState() => _NaverMapWebState();
}

class _NaverMapWebState extends State<NaverMapWeb> {
  late String _viewId;
  JSObject? _map;
  final List<JSObject> _jsMarkers = [];
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'naver-map-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = _viewId;
        div.style.width = '100%';
        div.style.height = '100%';
        div.style.position = 'absolute';
        div.style.top = '0';
        div.style.left = '0';
        div.style.right = '0';
        div.style.bottom = '0';

        // 지도 초기화를 약간 지연 (DOM이 준비될 때까지)
        Future.delayed(const Duration(milliseconds: 100), () {
          _initializeMap(div);
        });

        return div;
      },
    );
  }

  void _initializeMap(web.HTMLDivElement container) {
    try {
      // naver.maps.Map 생성
      final naver = globalContext['naver'] as JSObject?;
      if (naver == null) {
        debugPrint('네이버 지도 SDK가 로드되지 않았습니다.');
        return;
      }

      final maps = naver['maps'] as JSObject;
      final mapConstructor = maps['Map'] as JSFunction;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      // LatLng 생성
      final center = latLngConstructor.callAsConstructor(
        widget.latitude.toJS,
        widget.longitude.toJS,
      ) as JSObject;

      // 옵션 생성
      final options = JSObject();
      options['center'] = center;
      options['zoom'] = widget.zoom.toInt().toJS;
      options['autoResize'] = true.toJS;

      // Map 생성
      _map = mapConstructor.callAsConstructor(
        container as JSObject,
        options,
      ) as JSObject;

      if (_map != null) {
        _isMapReady = true;
        _addClickListener();
        _addMarkers();

        // 콜백 호출
        if (widget.onMapReady != null) {
          widget.onMapReady!(NaverMapWebController(this));
        }
      }
    } catch (e) {
      debugPrint('네이버 지도 초기화 오류: $e');
    }
  }

  void _addClickListener() {
    if (_map == null || widget.onMapTapped == null) return;

    try {
      final naver = globalContext['naver'] as JSObject;
      final maps = naver['maps'] as JSObject;
      final eventClass = maps['Event'] as JSObject;
      final addListener = eventClass['addListener'] as JSFunction;

      // 클릭 이벤트 핸들러
      void onClickHandler(JSObject e) {
        try {
          final coord = e['coord'] as JSObject;
          // lat(), lng() 메서드 호출
          final latFn = coord['lat'] as JSFunction;
          final lngFn = coord['lng'] as JSFunction;
          final lat = (latFn.callAsFunction() as JSNumber).toDartDouble;
          final lng = (lngFn.callAsFunction() as JSNumber).toDartDouble;
          widget.onMapTapped?.call(lat, lng);
        } catch (e) {
          debugPrint('클릭 이벤트 처리 오류: $e');
        }
      }

      addListener.callAsFunction(null, _map, 'click'.toJS, onClickHandler.toJS);
    } catch (e) {
      debugPrint('클릭 리스너 추가 오류: $e');
    }
  }

  void _addMarkers() {
    if (_map == null) return;

    // 기존 마커 제거
    for (final marker in _jsMarkers) {
      try {
        final setMap = marker['setMap'] as JSFunction;
        setMap.callAsFunction(marker, null);
      } catch (e) {
        debugPrint('마커 제거 오류: $e');
      }
    }
    _jsMarkers.clear();

    // 새 마커 추가
    for (final marker in widget.markers) {
      _addSingleMarker(marker);
    }
  }

  void _addSingleMarker(NaverMapMarker marker) {
    if (_map == null) return;

    try {
      final naver = globalContext['naver'] as JSObject;
      final maps = naver['maps'] as JSObject;
      final markerConstructor = maps['Marker'] as JSFunction;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      // 위치 생성
      final position = latLngConstructor.callAsConstructor(
        marker.latitude.toJS,
        marker.longitude.toJS,
      ) as JSObject;

      // 옵션 생성
      final options = JSObject();
      options['position'] = position;
      options['map'] = _map;

      // 마커 생성
      final jsMarker = markerConstructor.callAsConstructor(options) as JSObject;
      _jsMarkers.add(jsMarker);

      // 마커 클릭 이벤트
      if (marker.onTap != null) {
        final eventClass = maps['Event'] as JSObject;
        final addListener = eventClass['addListener'] as JSFunction;

        void onMarkerClick(JSObject e) {
          marker.onTap?.call();
        }

        addListener.callAsFunction(
            null, jsMarker, 'click'.toJS, onMarkerClick.toJS);
      }
    } catch (e) {
      debugPrint('마커 추가 오류: $e');
    }
  }

  void moveCamera(double lat, double lng, {double? zoom}) {
    if (_map == null) return;

    try {
      final naver = globalContext['naver'] as JSObject;
      final maps = naver['maps'] as JSObject;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      final center = latLngConstructor.callAsConstructor(
        lat.toJS,
        lng.toJS,
      ) as JSObject;

      final setCenter = _map!['setCenter'] as JSFunction;
      setCenter.callAsFunction(_map, center);

      if (zoom != null) {
        final setZoom = _map!['setZoom'] as JSFunction;
        setZoom.callAsFunction(_map, zoom.toInt().toJS);
      }
    } catch (e) {
      debugPrint('카메라 이동 오류: $e');
    }
  }

  void updateMarkers(List<NaverMapMarker> markers) {
    // 기존 마커 제거
    for (final marker in _jsMarkers) {
      try {
        final setMap = marker['setMap'] as JSFunction;
        setMap.callAsFunction(marker, null);
      } catch (e) {
        debugPrint('마커 제거 오류: $e');
      }
    }
    _jsMarkers.clear();

    // 새 마커 추가
    for (final marker in markers) {
      _addSingleMarker(marker);
    }
  }

  @override
  void didUpdateWidget(NaverMapWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 위치가 변경되면 카메라 이동
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      moveCamera(widget.latitude, widget.longitude, zoom: widget.zoom);
    }

    // 마커가 변경되면 업데이트
    if (oldWidget.markers != widget.markers) {
      updateMarkers(widget.markers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

/// 네이버 지도 컨트롤러
class NaverMapWebController {
  final _NaverMapWebState _state;

  NaverMapWebController(this._state);

  void moveCamera(double lat, double lng, {double? zoom}) {
    _state.moveCamera(lat, lng, zoom: zoom);
  }

  void updateMarkers(List<NaverMapMarker> markers) {
    _state.updateMarkers(markers);
  }
}

/// 마커 데이터 클래스
class NaverMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String? title;
  final VoidCallback? onTap;

  const NaverMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title,
    this.onTap,
  });
}

/// 네이버 지오코딩 서비스
class NaverGeocodingService {
  /// 주소로 좌표 검색 (Geocoding)
  static Future<List<NaverGeocodingResult>> geocode(String query) async {
    final completer = Completer<List<NaverGeocodingResult>>();

    try {
      final naver = globalContext['naver'] as JSObject?;
      if (naver == null) {
        debugPrint('네이버 지도 SDK가 로드되지 않았습니다.');
        return [];
      }

      final maps = naver['maps'] as JSObject;
      final service = maps['Service'] as JSObject;
      final geocodeFn = service['geocode'] as JSFunction;

      // 옵션 객체 생성
      final options = JSObject();
      options['query'] = query.toJS;

      // 콜백 함수
      void callback(JSNumber status, JSObject response) {
        try {
          final results = <NaverGeocodingResult>[];

          // response.v2.addresses 배열 파싱
          final v2 = response['v2'] as JSObject?;
          if (v2 != null) {
            final addresses = v2['addresses'] as JSArray?;
            if (addresses != null) {
              final dartAddresses = addresses.toDart;
              for (int i = 0; i < dartAddresses.length; i++) {
                final addr = dartAddresses[i] as JSObject;
                final roadAddress =
                    (addr['roadAddress'] as JSString?)?.toDart ?? '';
                final jibunAddress =
                    (addr['jibunAddress'] as JSString?)?.toDart ?? '';
                final x =
                    double.tryParse((addr['x'] as JSString?)?.toDart ?? '0') ??
                        0;
                final y =
                    double.tryParse((addr['y'] as JSString?)?.toDart ?? '0') ??
                        0;

                results.add(NaverGeocodingResult(
                  address: roadAddress.isNotEmpty ? roadAddress : jibunAddress,
                  latitude: y,
                  longitude: x,
                ));
              }
            }
          }

          completer.complete(results);
        } catch (e) {
          debugPrint('지오코딩 결과 파싱 오류: $e');
          completer.complete([]);
        }
      }

      geocodeFn.callAsFunction(null, options, callback.toJS);
    } catch (e) {
      debugPrint('지오코딩 오류: $e');
      completer.complete([]);
    }

    return completer.future;
  }

  /// 좌표로 주소 검색 (Reverse Geocoding)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final completer = Completer<String?>();

    try {
      final naver = globalContext['naver'] as JSObject?;
      if (naver == null) {
        debugPrint('네이버 지도 SDK가 로드되지 않았습니다.');
        return null;
      }

      final maps = naver['maps'] as JSObject;
      final service = maps['Service'] as JSObject;
      final reverseGeocodeFn = service['reverseGeocode'] as JSFunction;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      // 좌표 생성
      final coord =
          latLngConstructor.callAsConstructor(lat.toJS, lng.toJS) as JSObject;

      // 옵션 객체 생성
      final options = JSObject();
      options['coords'] = coord;
      options['orders'] = 'roadaddr,addr'.toJS;

      // 콜백 함수
      void callback(JSNumber status, JSObject response) {
        try {
          final v2 = response['v2'] as JSObject?;
          if (v2 != null) {
            final address = v2['address'] as JSObject?;
            if (address != null) {
              final roadAddress = (address['roadAddress'] as JSString?)?.toDart;
              final jibunAddress =
                  (address['jibunAddress'] as JSString?)?.toDart;
              completer.complete(roadAddress ?? jibunAddress);
              return;
            }
          }
          completer.complete(null);
        } catch (e) {
          debugPrint('역지오코딩 결과 파싱 오류: $e');
          completer.complete(null);
        }
      }

      reverseGeocodeFn.callAsFunction(null, options, callback.toJS);
    } catch (e) {
      debugPrint('역지오코딩 오류: $e');
      completer.complete(null);
    }

    return completer.future;
  }
}

/// 지오코딩 결과
class NaverGeocodingResult {
  final String address;
  final double latitude;
  final double longitude;

  const NaverGeocodingResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
