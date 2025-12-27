import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const MaterialApp(home: SimpleFlight()));

class SimpleFlight extends StatefulWidget {
  const SimpleFlight({super.key});
  @override
  State<SimpleFlight> createState() => _SimpleFlightState();
}

class _SimpleFlightState extends State<SimpleFlight> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _pos = const LatLng(35.6762, 139.6503); // 東京
  
  // ジョイスティック関連
  Offset _joyPos = Offset.zero; // ジョイスティックの位置
  bool _isJoystickActive = false;
  
  // 速度と高度
  double _speed = 50.0; // 速度（km/h）
  final double _altitude = 500.0; // 高度（メートル）
  double _airplaneRotation = 0.0; // 飛行機の回転角度（度）
  
  late Ticker _ticker;
  
  @override
  void initState() {
    super.initState();
    // Tickerを開始して毎フレーム更新
    _ticker = createTicker(_onTick);
    _ticker.start();
  }
  
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
  
  // 毎フレーム実行される更新処理
  void _onTick(Duration elapsed) {
    const double minSpeed = 50.0; // 最低速度（km/h）
    
    double joyStickX = 0.0;
    double joyStickY = 0.0;
    double intensity = 0.0;
    
    if (_isJoystickActive && _joyPos.distance > 0.01) {
      // ジョイスティックの正規化された位置を取得（-1.0 ～ 1.0 の範囲）
      final maxRadius = 40.0;
      joyStickX = (_joyPos.dx / maxRadius).clamp(-1.0, 1.0);
      joyStickY = (_joyPos.dy / maxRadius).clamp(-1.0, 1.0);
      intensity = (_joyPos.distance / maxRadius).clamp(0.0, 1.0);
      
      // 速度を更新（ジョイスティックの倒し具合に応じて、最低速度を保証）
      final targetSpeed = minSpeed + (intensity * (500.0 - minSpeed)); // 50-500km/hの範囲
      _speed = _speed * 0.85 + targetSpeed * 0.15; // スムーズに加速
      _speed = _speed.clamp(minSpeed, 500.0); // 最低速度を保証
      
      // 飛行機の向きを更新（移動方向に合わせて）
      final angle = math.atan2(joyStickY, joyStickX);
      _airplaneRotation = (angle * 180 / math.pi) + 90; // 90度補正（アイコンの向きに合わせる）
    } else {
      // ジョイスティックが動いていない場合は慣性で減速（最低速度まで）
      _speed = (_speed * 0.92).clamp(minSpeed, 500.0); // 最低速度を保証
      
      // 最後の移動方向を維持（前回の角度からX/Yを計算）
      final lastAngle = (_airplaneRotation - 90) * math.pi / 180;
      joyStickX = math.cos(lastAngle);
      joyStickY = math.sin(lastAngle);
    }
    
    // 1フレーム(1/60秒)あたりの移動係数（一時的に10倍にして動きを見やすく）
    double step = (_speed / 3600) * (1 / 60) * 0.01 * 10.0;
    
    // ジョイスティックが動いている時だけ、座標を更新する
    if (_isJoystickActive && _joyPos.distance > 0.01) {
      _pos = LatLng(
        _pos.latitude - (_joyPos.dy * 0.0001),
        _pos.longitude + (_joyPos.dx * 0.0001),
      );

      // UIを更新
      setState(() {});

      // 地図を動かす
      _mapController.move(_pos, 13.0);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 遠近感（パース）の強度
              ..rotateX(-0.9),       // 奥側に倒す角度（ラジアン）
            alignment: Alignment.center,
            // 地図レイヤー（Stackの最初の子要素として画面いっぱいに配置）
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pos,
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // 操作を無効化
                ),
              ),
              children: [
                TileLayer(
                  // 衛星画像に差し替え
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.flight_sim',
                  // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // userAgentPackageName: 'com.example.flight_sim',
                  maxZoom: 19,
                ),
              ],
            ),
          ),
          // HUD表示（画面上部）
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 高度表示
                  _buildHUDDisplay('ALT', '${_altitude.toInt()}m', Colors.cyan),
                  // 速度表示
                  _buildHUDDisplay('SPD', '${_speed.toInt()}km/h', Colors.cyan),
                ],
              ),
            ),
          ),
          
          // 飛行機アイコン（画面中央）
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 影（丸いグラデーション）
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), // 楕円を表現
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                // 飛行機アイコン（回転可能）
                Transform.rotate(
                  angle: _airplaneRotation * math.pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.airplanemode_active,
                      size: 48,
                      color: Colors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // ジョイスティックUI（画面下部左）
          Positioned(
            bottom: 40,
            left: 30,
            child: _buildJoystick(),
          ),
        ],
      ),
    );
  }

  // HUD表示ウィジェット
  Widget _buildHUDDisplay(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ジョイスティックUI
  Widget _buildJoystick() {
    final maxRadius = 40.0;
    final currentRadius = math.min(_joyPos.distance, maxRadius);
    final angle = _joyPos.distance > 0.01
        ? math.atan2(_joyPos.dy, _joyPos.dx)
        : 0.0;
    
    final knobX = currentRadius * math.cos(angle);
    final knobY = currentRadius * math.sin(angle);
    
    return GestureDetector(
      onPanStart: (details) {
        final localPosition = details.localPosition - const Offset(40, 40);
        setState(() {
          _joyPos = localPosition;
          _isJoystickActive = true;
        });
      },
onPanUpdate: (details) {
        setState(() {
          // 指の移動量を「加算」して、中心からのズレを計算する
          _joyPos += details.delta; 
          
          // 最大範囲(40)を超えないように制限をかける（これがないと無限に飛んでいきます）
          if (_joyPos.distance > 40) {
            _joyPos = Offset.fromDirection(_joyPos.direction, 40);
          }
        });
      },
      onPanEnd: (details) {
        setState(() {
          _joyPos = Offset.zero; // 離したら止める
          _isJoystickActive = false;
        });
      },
      onPanCancel: () {
        setState(() {
          _joyPos = Offset.zero;
          _isJoystickActive = false;
        });
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.cyan.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 外側の円
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            // 内側の円（操作部分）- ジョイスティックの位置に移動
            Transform.translate(
              offset: Offset(knobX, knobY),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
