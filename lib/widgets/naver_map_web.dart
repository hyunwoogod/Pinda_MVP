import 'dart:async';
import 'dart:convert';
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

  JSFunction? _onMarkerTapJs;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _viewId = 'naver-map-${DateTime.now().millisecondsSinceEpoch}';

    // 전역 콜백 등록
    _onMarkerTapJs = ((JSString id) {
      _handleMarkerTap(id.toDart);
    }).toJS;
    globalContext['onMarkerTap'] = _onMarkerTapJs;

    _registerView();
  }

  @override
  void dispose() {
    globalContext['onMarkerTap'] = null;
    super.dispose();
  }

  void _handleMarkerTap(String id) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastTapTime = now;

    try {
      final marker = widget.markers.firstWhere((m) => m.id == id);
      marker.onTap?.call();
    } catch (_) {}
  }

  String _createMarkerHtml(String id, bool isMyLocation) {
    final clickHandler = "window.onMarkerTap('$id'); event.stopPropagation();";
    final touchStart =
        "event.stopPropagation(); this.style.transform='scale(0.9)';";
    final touchEnd =
        "this.style.transform='scale(1.0)'; window.onMarkerTap('$id'); event.stopPropagation();";
    final mouseDown = "this.style.transform='scale(0.9)';";
    final mouseUp = "this.style.transform='scale(1.0)';";

    final commonStyle =
        "cursor:pointer;pointer-events:auto;transition:transform 0.1s ease-in-out;";

    if (isMyLocation) {
      return '<div onclick="$clickHandler" ontouchstart="$touchStart" ontouchend="$touchEnd" onmousedown="$mouseDown" onmouseup="$mouseUp" onmouseleave="$mouseUp" style="z-index:2000;width:40px;height:40px;display:flex;justify-content:center;align-items:center;$commonStyle">' +
          '<div style="width:40px;height:40px;background:rgba(66, 133, 244, 0.3);border-radius:50%;position:absolute;"></div>' +
          '<div style="width:20px;height:20px;background:#4285F4;border:2px solid #fff;border-radius:50%;position:relative;z-index:1;box-shadow:0 2px 4px rgba(0,0,0,0.2);"></div>' +
          '</div>';
    } else {
      return '<div onclick="$clickHandler" ontouchstart="$touchStart" ontouchend="$touchEnd" onmousedown="$mouseDown" onmouseup="$mouseUp" onmouseleave="$mouseUp" style="z-index:2000;width:30px;height:42px;$commonStyle"><svg xmlns="http://www.w3.org/2000/svg" width="30" height="42" viewBox="0 0 24 34"><path fill="#FF0000" d="M12 0C5.373 0 0 5.373 0 12c0 9 12 22 12 22s12-13 12-22c0-6.627-5.373-12-12-12z"/><circle fill="#FFFFFF" cx="12" cy="12" r="4"/></svg></div>';
    }
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
          final getCoordFn = globalContext['getNaverCoord'] as JSFunction?;
          if (getCoordFn != null) {
            final jsonStr =
                (getCoordFn.callAsFunction(null, e) as JSString?)?.toDart;
            if (jsonStr != null) {
              final Map<String, dynamic> coord = jsonDecode(jsonStr);
              final lat = (coord['lat'] as num).toDouble();
              final lng = (coord['lng'] as num).toDouble();

              if (lat != 0 && lng != 0) {
                widget.onMapTapped?.call(lat, lng);
              }
            }
          }
        } catch (err) {
          debugPrint('클릭 이벤트 처리 오류: $err');
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
      options['clickable'] = true.toJS; // 클릭 가능 명시

      // 마커 아이콘 (빨간색)
      // 마커 아이콘
      // 마커 아이콘 설정
      final iconConfig = JSObject();
      final htmlContent = _createMarkerHtml(marker.id, marker.isMyLocation);
      iconConfig['content'] = htmlContent.toJS;

      if (marker.isMyLocation) {
        iconConfig['size'] =
            (maps['Size'] as JSFunction).callAsConstructor(40.toJS, 40.toJS);
        iconConfig['anchor'] =
            (maps['Point'] as JSFunction).callAsConstructor(20.toJS, 20.toJS);
      } else {
        iconConfig['size'] =
            (maps['Size'] as JSFunction).callAsConstructor(30.toJS, 42.toJS);
        iconConfig['anchor'] =
            (maps['Point'] as JSFunction).callAsConstructor(15.toJS, 42.toJS);
      }
      options['icon'] = iconConfig;

      if (marker.title != null) {
        options['title'] = marker.title!.toJS;
      }

      if (marker.captionText != null) {
        final caption = JSObject();
        caption['text'] = marker.captionText!.toJS;
        // 텍스트 색상 및 정렬 등 추가 옵션 가능
        caption['align'] = 1.toJS; // Bottom
        options['caption'] = caption;
      }

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
  final String? captionText;
  final VoidCallback? onTap;

  final bool isMyLocation;

  const NaverMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title,
    this.captionText,
    this.onTap,
    this.isMyLocation = false,
  });
}

/// 네이버 지오코딩 서비스
class NaverGeocodingService {
  /// 주소로 좌표 검색 (Geocoding)
  static Future<List<NaverGeocodingResult>> geocode(String query) async {
    final completer = Completer<List<NaverGeocodingResult>>();

    try {
      final naverGeocodeFn = globalContext['naverGeocode'] as JSFunction?;
      if (naverGeocodeFn == null) {
        debugPrint('naverGeocode 함수가 없습니다.');
        return [];
      }

      // 성공 콜백
      void onSuccess(JSString jsonResult) {
        try {
          final jsonString = jsonResult.toDart;
          final List<dynamic> data = jsonDecode(jsonString);
          final results = data
              .map((item) => NaverGeocodingResult(
                    address: item['address'] ?? '',
                    latitude: (item['latitude'] ?? 0).toDouble(),
                    longitude: (item['longitude'] ?? 0).toDouble(),
                  ))
              .toList();
          completer.complete(results);
        } catch (e) {
          debugPrint('지오코딩 결과 파싱 오류: $e');
          completer.complete([]);
        }
      }

      // 실패 콜백
      void onError(JSString errorMsg) {
        debugPrint('지오코딩 오류: ${errorMsg.toDart}');
        completer.complete([]);
      }

      naverGeocodeFn.callAsFunction(
          null, query.toJS, onSuccess.toJS, onError.toJS);
    } catch (e) {
      debugPrint('지오코딩 호출 오류: $e');
      completer.complete([]);
    }

    return completer.future;
  }

  /// 좌표로 주소 검색 (Reverse Geocoding)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final completer = Completer<String?>();

    try {
      final naverReverseGeocodeFn =
          globalContext['naverReverseGeocode'] as JSFunction?;
      if (naverReverseGeocodeFn == null) {
        debugPrint('naverReverseGeocode 함수가 없습니다.');
        return null;
      }

      // 성공 콜백
      void onSuccess(JSString result) {
        final address = result.toDart;
        completer.complete(address.isNotEmpty ? address : null);
      }

      // 실패 콜백
      void onError(JSString errorMsg) {
        debugPrint('역지오코딩 오류: ${errorMsg.toDart}');
        completer.complete(null);
      }

      naverReverseGeocodeFn.callAsFunction(
          null, lat.toJS, lng.toJS, onSuccess.toJS, onError.toJS);
    } catch (e) {
      debugPrint('역지오코딩 호출 오류: $e');
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
