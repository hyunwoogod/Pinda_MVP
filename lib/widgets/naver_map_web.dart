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
  final List<NaverMapPolygon> polygons; // 폴리곤 추가
  final List<NaverMapPolyline> polylines; // 폴리라인 추가
  final Function(double lat, double lng)? onMapTapped;
  final Function(NaverMapWebController)? onMapReady;

  const NaverMapWeb({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 14,
    this.markers = const [],
    this.polygons = const [], // 초기값
    this.polylines = const [], // 폴리라인 추가
    this.onMapTapped,
    this.onMapReady,
  });

  @override
  State<NaverMapWeb> createState() => NaverMapWebState();
}

class NaverMapWebState extends State<NaverMapWeb> {
  late String _viewId;
  JSObject? _map;
  JSObject? _resizeObserver;
  final List<JSObject> _jsMarkers = [];
  final List<JSObject> _jsPolygons = []; // JS 폴리곤 객체들

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
    _resizeObserver?.callMethod('disconnect'.toJS);
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

  String _createMarkerHtml(String id, bool isMyLocation, Color? iconColor) {
    const clickHandler = "window.onMarkerTap('";
    const clickHandlerEnd = "'); event.stopPropagation();";
    final fullClickHandler = "$clickHandler$id$clickHandlerEnd";

    const touchStart =
        "event.stopPropagation(); this.style.transform='scale(0.9)';";
    const touchEnd = "this.style.transform='scale(1.0)'; window.onMarkerTap('";
    const touchEndSuffix = "'); event.stopPropagation();";
    final fullTouchEnd = "$touchEnd$id$touchEndSuffix";

    const mouseDown = "this.style.transform='scale(0.9)';";
    const mouseUp = "this.style.transform='scale(1.0)';";

    const commonStyle =
        "cursor:pointer;pointer-events:auto;transition:transform 0.1s ease-in-out;";

    if (isMyLocation) {
      return '<div onclick="$fullClickHandler" ontouchstart="$touchStart" ontouchend="$fullTouchEnd" onmousedown="$mouseDown" onmouseup="$mouseUp" onmouseleave="$mouseUp" style="z-index:2000;width:40px;height:40px;display:flex;justify-content:center;align-items:center;$commonStyle">'
          '<div style="width:40px;height:40px;background:rgba(66, 133, 244, 0.3);border-radius:50%;position:absolute;"></div>'
          '<div style="width:20px;height:20px;background:#4285F4;border:2px solid #fff;border-radius:50%;position:relative;z-index:1;box-shadow:0 2px 4px rgba(0,0,0,0.2);"></div>'
          '</div>';
    } else {
      // Hex Color 변환
      final colorHex = iconColor != null
          ? '#${iconColor.value.toRadixString(16).padLeft(8, '0').substring(2)}'
          : '#FF0000'; // 기본 빨강

      return '<div onclick="$fullClickHandler" ontouchstart="$touchStart" ontouchend="$fullTouchEnd" onmousedown="$mouseDown" onmouseup="$mouseUp" onmouseleave="$mouseUp" style="z-index:2000;width:30px;height:42px;$commonStyle"><svg xmlns="http://www.w3.org/2000/svg" width="30" height="42" viewBox="0 0 24 34"><path fill="$colorHex" d="M12 0C5.373 0 0 5.373 0 12c0 9 12 22 12 22s12-13 12-22c0-6.627-5.373-12-12-12z"/><circle fill="#FFFFFF" cx="12" cy="12" r="4"/></svg></div>';
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
      final mapOptions = JSObject();
      mapOptions['center'] = center;
      mapOptions['zoom'] = widget.zoom.toJS;

      _map =
          mapConstructor.callAsConstructor(container, mapOptions) as JSObject;

      // ResizeObserver 등록 (컨테이너 크기 변경 감지)
      try {
        final resizeCallback = ((JSArray entries, JSObject observer) {
          if (_map != null) {
            final width = container.clientWidth;
            final height = container.clientHeight;
            if (width > 0 && height > 0) {
              final size = (maps['Size'] as JSFunction)
                  .callAsConstructor(width.toJS, height.toJS);
              (_map as JSObject).callMethod('setSize'.toJS, size);

              // 중심점 유지 및 렌더링 강제 업데이트
              try {
                final currentCenter =
                    (_map as JSObject).callMethod('getCenter'.toJS);
                (_map as JSObject).callMethod('setCenter'.toJS, currentCenter);
              } catch (_) {}
            }
          }
        }).toJS;

        _resizeObserver = (globalContext['ResizeObserver'] as JSFunction)
            .callAsConstructor(resizeCallback) as JSObject;

        _resizeObserver?.callMethod('observe'.toJS, container);
      } catch (e) {
        debugPrint('ResizeObserver error: $e');
      }

      // 초기 마커 추가
      updateMarkers(widget.markers);
      // 초기 폴리곤 추가
      updatePolygons(widget.polygons);
      // 초기 폴리라인 추가
      updatePolylines(widget.polylines);

      if (_map != null) {
        _addClickListener();
        // _addMarkers(); // updateMarkers가 이미 처리함
        // _addPolygons(); // updatePolygons가 이미 처리함

        // 콜백 호출
        if (widget.onMapReady != null) {
          widget.onMapReady!(NaverMapWebController(this));
        }
      }
    } catch (e) {
      print('네이버 지도 초기화 오류: $e'); // debugPrint 대신 print 사용
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

      // 마커 아이콘 설정
      final iconConfig = JSObject();
      final htmlContent = _createMarkerHtml(
          marker.id, marker.isMyLocation, marker.iconTintColor);
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

        // 캡션 색상 적용 (API 버전에 따라 지원 여부 상이, 시도)
        if (marker.captionColor != null) {
          // final colorHex = '#${marker.captionColor!.value.toRadixString(16).substring(2)}';
          // caption['color'] = colorHex.toJS;
        }

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
    // 폴리곤이 변경되면 업데이트
    if (oldWidget.polygons != widget.polygons) {
      updatePolygons(widget.polygons);
    }
    // 폴리라인이 변경되면 업데이트
    if (oldWidget.polylines != widget.polylines) {
      updatePolylines(widget.polylines);
    }
  }

  void updatePolygons(List<NaverMapPolygon> polygons) {
    if (_map == null) return;

    // 기존 폴리곤 제거
    for (final polygon in _jsPolygons) {
      try {
        final setMap = polygon['setMap'] as JSFunction;
        setMap.callAsFunction(polygon, null);
      } catch (e) {
        debugPrint('폴리곤 제거 오류: $e');
      }
    }
    _jsPolygons.clear();

    // 새 폴리곤 추가
    for (final polygon in polygons) {
      _addSinglePolygon(polygon);
    }
  }

  // --- Polyline 관리 ---
  final List<JSObject> _jsPolylines = [];

  void updatePolylines(List<NaverMapPolyline> polylines) {
    if (_map == null) return;

    // 기존 폴리라인 제거
    for (final jsPolyline in _jsPolylines) {
      try {
        jsPolyline.callMethod('setMap'.toJS, null);
      } catch (e) {
        debugPrint('Polyline Remove Error: $e');
      }
    }
    _jsPolylines.clear();

    // 새 폴리라인 추가
    for (final polyline in polylines) {
      _addSinglePolyline(polyline);
    }
  }

  void _addSinglePolyline(NaverMapPolyline polyline) {
    if (_map == null) return;

    try {
      final naver = globalContext['naver'] as JSObject;
      final maps = naver['maps'] as JSObject;
      final polylineConstructor = maps['Polyline'] as JSFunction;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      // 좌표 변환
      final pathArray = JSArray();
      for (final coord in polyline.coordinates) {
        final latLng = latLngConstructor.callAsConstructor(
          coord.latitude.toJS,
          coord.longitude.toJS,
        );
        pathArray.add(latLng);
      }

      // 옵션
      final options = JSObject();
      options['map'] = _map;
      options['path'] =
          pathArray; // Polylines uses 'path', Polygons uses 'paths'

      // 색상 변환
      final strokeColor =
          '#${polyline.strokeColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

      options['strokeColor'] = strokeColor.toJS;
      options['strokeWeight'] = polyline.strokeWidth.toJS;
      options['zIndex'] = polyline.zIndex.toJS;

      // 폴리라인 생성
      final jsPolyline =
          polylineConstructor.callAsConstructor(options) as JSObject;
      _jsPolylines.add(jsPolyline);
    } catch (e) {
      print("Error adding polyline: $e"); // debugPrint 대신 print 사용
    }
  }

  void _addSinglePolygon(NaverMapPolygon polygon) {
    if (_map == null) return;
    print(
        "Adding Polygon: ${polygon.id}, zIndex: ${polygon.zIndex}, coords: ${polygon.coordinates.length}");

    try {
      final naver = globalContext['naver'] as JSObject;
      final maps = naver['maps'] as JSObject;
      final polygonConstructor = maps['Polygon'] as JSFunction;
      final latLngConstructor = maps['LatLng'] as JSFunction;

      // 좌표 리스트 변환 JSArray<JSObject> (LatLng[])
      final pathArray = JSArray();
      for (final coord in polygon.coordinates) {
        final latLng = latLngConstructor.callAsConstructor(
          coord.latitude.toJS,
          coord.longitude.toJS,
        );
        pathArray.add(latLng);
      }

      // 옵션 생성
      final options = JSObject();
      options['map'] = _map;
      options['paths'] = JSArray()
        ..add(
            pathArray); // Paths is Array of Array (for holes) or Array of LatLng

      // 스타일
      final fillColor =
          '#${polygon.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      final strokeColor =
          '#${polygon.strokeColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

      options['fillColor'] = fillColor.toJS;
      options['fillOpacity'] = (polygon.color.opacity).toJS;
      options['strokeColor'] = strokeColor.toJS;
      options['strokeOpacity'] = (polygon.strokeColor.opacity).toJS;
      options['strokeWeight'] = polygon.strokeWidth.toJS;
      options['clickable'] = true.toJS;
      options['zIndex'] = polygon.zIndex.toJS; // Z-Index 적용

      // 폴리곤 생성
      final jsPolygon =
          polygonConstructor.callAsConstructor(options) as JSObject;
      _jsPolygons.add(jsPolygon);

      // 클릭 이벤트
      if (polygon.onTap != null) {
        // ...
      }
    } catch (e) {
      print('폴리곤 추가 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

/// 네이버 지도 컨트롤러
class NaverMapWebController {
  final NaverMapWebState _state;

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
  final Color? captionColor; // 추가
  final Color? iconTintColor; // 추가
  final VoidCallback? onTap;

  final bool isMyLocation;

  const NaverMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title,
    this.captionText,
    this.captionColor,
    this.iconTintColor,
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

/// 폴리라인 데이터 클래스
class NaverMapPolyline {
  final String id;
  final List<NaverLatLng> coordinates;
  final Color strokeColor;
  final double strokeWidth;
  final int zIndex;

  const NaverMapPolyline({
    required this.id,
    required this.coordinates,
    this.strokeColor = Colors.red,
    this.strokeWidth = 2,
    this.zIndex = 0,
  });
}

/// 폴리곤 데이터 클래스
class NaverMapPolygon {
  final String id;
  final List<NaverLatLng> coordinates; // 좌표 리스트
  final Color color; // 채우기 색상
  final Color strokeColor; // 테두리 색상
  final double strokeWidth;
  final int zIndex; // Z-Index 추가
  final VoidCallback? onTap;

  const NaverMapPolygon({
    required this.id,
    required this.coordinates,
    this.color = const Color(0x33FF0000), // 기본 반투명 빨강
    this.strokeColor = Colors.red,
    this.strokeWidth = 2,
    this.zIndex = 0,
    this.onTap,
  });
}

class NaverLatLng {
  final double latitude;
  final double longitude;
  const NaverLatLng(this.latitude, this.longitude);
}
