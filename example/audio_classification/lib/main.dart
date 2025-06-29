import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'helper/audio_classification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:health_kit_reporter/health_kit_reporter.dart'; 
import 'package:health_kit_reporter/model/predicate.dart';

import 'package:health_kit_reporter/model/payload/activity_summary.dart';
import 'package:health_kit_reporter/model/payload/category.dart';
import 'package:health_kit_reporter/model/payload/characteristic/characteristic.dart';
import 'package:health_kit_reporter/model/payload/correlation.dart';
import 'package:health_kit_reporter/model/payload/date_components.dart';
import 'package:health_kit_reporter/model/payload/deleted_object.dart';
import 'package:health_kit_reporter/model/payload/device.dart';
import 'package:health_kit_reporter/model/payload/electrocardiogram.dart';
import 'package:health_kit_reporter/model/payload/heartbeat_series.dart';
import 'package:health_kit_reporter/model/payload/preferred_unit.dart';
import 'package:health_kit_reporter/model/payload/quantity.dart';
import 'package:health_kit_reporter/model/payload/sample.dart';
import 'package:health_kit_reporter/model/payload/source.dart';
import 'package:health_kit_reporter/model/payload/source_revision.dart';
import 'package:health_kit_reporter/model/payload/statistics.dart';
import 'package:health_kit_reporter/model/payload/workout.dart';
import 'package:health_kit_reporter/model/payload/workout_configuration.dart';
import 'package:health_kit_reporter/model/payload/workout_route.dart';
import 'package:health_kit_reporter/model/predicate.dart';
import 'package:health_kit_reporter/model/type/activity_summary_type.dart';
import 'package:health_kit_reporter/model/type/category_type.dart';
import 'package:health_kit_reporter/model/type/characteristic_type.dart';
import 'package:health_kit_reporter/model/type/correlation_type.dart';
import 'package:health_kit_reporter/model/type/document_type.dart';
import 'package:health_kit_reporter/model/type/electrocardiogram_type.dart';
import 'package:health_kit_reporter/model/type/quantity_type.dart';
import 'package:health_kit_reporter/model/type/series_type.dart';
import 'package:health_kit_reporter/model/type/workout_type.dart';
import 'package:health_kit_reporter/model/update_frequency.dart';

void main() {
  runApp(const AudioClassificationApp());
}

mixin HealthKitReporterMixin {
  Predicate get predicate => Predicate(
        DateTime.now().add(const Duration(days: -365)),
        DateTime.now(),
      );

  Device get device => Device(
        'FlutterTracker',
        'kvs',
        'T-800',
        '3',
        '3.0',
        '1.1.1',
        'kvs.sample.app',
        '444-888-555',
      );
  Source get source => Source(
        'myApp',
        'com.kvs.health_kit_reporter_example',
      );
  OperatingSystem get operatingSystem => OperatingSystem(
        1,
        2,
        3,
      );

  SourceRevision get sourceRevision => SourceRevision(
        source,
        '5',
        'fit',
        '4',
        operatingSystem,
      );
}

class AudioClassificationApp extends StatelessWidget {
  const AudioClassificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Classification',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Audio Classification Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with HealthKitReporterMixin {
  // 狀態變數：原本用於 SDNN 查詢，現改為匯出健康資料時顯示提示訊息
  // 狀態變數：一開始為「5秒判斷」模式
  String _hrvResult = "請點擊定時判斷功能";
  Timer? _timedTimer;

  static const platform =
      MethodChannel('org.tensorflow.audio_classification/audio_record');

  // 16kHz 設定與預期錄音長度（毫秒）
  static const _sampleRate = 16000;
  static const _expectAudioLength = 975;
  final int _requiredInputBuffer =
      (16000 * (_expectAudioLength / 1000)).toInt();

  late AudioClassificationHelper _helper;
  // 儲存分類結果顯示用資料
  List<MapEntry<String, double>> _classification = List.empty();
  // 連續模式下的結果歷史（每秒一次，每筆結果為 Map<String, double>）
  final List<Map<String, double>> _resultsHistory = [];
  // 定時模式下累積的結果（按下定時判斷功能後累積結果）
  final List<Map<String, double>> _timedResultsHistory = [];

  // 模式切換：true 為連續模式（預設）；false 為定時模式
  // bool _isContinuous = true;
  bool _isContinuous = false;
  bool _isClickTimemode = false;
  bool _isClickExport = false;
  // 定時模式中是否正在進行定時推論
  bool _timedJudgmentActive = false;

  final List<Color> _primaryProgressColorList = [
    const Color(0xFFF44336),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF3F51B5),
    const Color(0xFF2196F3),
    const Color(0xFF00BCD4),
    const Color(0xFF009688),
    const Color(0xFF4CAF50),
    const Color(0xFFFFEB3B),
    const Color(0xFFFFC107),
    const Color(0xFFFF9800)
  ];
  final List<Color> _backgroundProgressColorList = [
    const Color(0x44F44336),
    const Color(0x44E91E63),
    const Color(0x449C27B0),
    const Color(0x443F51B5),
    const Color(0x442196F3),
    const Color(0x4400BCD4),
    const Color(0x44009688),
    const Color(0x444CAF50),
    const Color(0x44FFEB3B),
    const Color(0x44FFC107),
    const Color(0x44FF9800)
  ];
  var _showError = false;
  var _showHealthError = false;

  // 開始錄音
  void _startRecorder() {
    try {
      platform.invokeMethod('startRecord');
    } on PlatformException catch (e) {
      log("Failed to start record: '${e.message}'.");
    }
  }

  // 請求權限並建立錄音器
  Future<bool> _requestPermission() async {
    try {
      return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
        "sampleRate": _sampleRate,
        "requiredInputBuffer": _requiredInputBuffer
      });
    } on Exception catch (e) {
      log("Failed to create recorder: '${e.toString()}'.");
      return false;
    }
  }

  // 取得音訊資料（Float32List）
  Future<Float32List> _getAudioFloatArray() async {
    var audioFloatArray = Float32List(0);
    try {
      final Float32List result =
          await platform.invokeMethod('getAudioFloatArray');
      audioFloatArray = result;
    } on PlatformException catch (e) {
      log("Failed to get audio array: '${e.message}'.");
    }
    return audioFloatArray;
  }

  // 關閉錄音器並釋放資源
  Future<void> _closeRecorder() async {
    try {
      await platform.invokeMethod('closeRecorder');
      _helper.closeInterpreter();
    } on PlatformException {
      log("Failed to close recorder.");
    }
  }

  // 請求 HealthKit 許可
  Future<void> _requestHealthPermission() async {
    try {
      final List<String> readTypes = [
        ...ActivitySummaryType.values.map((e) => e.identifier),
        ...CategoryType.values.map((e) => e.identifier),
        ...CharacteristicType.values.map((e) => e.identifier),
        ...QuantityType.values.map((e) => e.identifier),
        ...WorkoutType.values.map((e) => e.identifier),
        ...SeriesType.values.map((e) => e.identifier),
        ...ElectrocardiogramType.values.map((e) => e.identifier),
      ];

      final List<String> writeTypes = [
        QuantityType.stepCount.identifier,
        WorkoutType.workoutType.identifier,
        CategoryType.sleepAnalysis.identifier,
        CategoryType.mindfulSession.identifier,
      ];

      final bool success = await HealthKitReporter.requestAuthorization(readTypes, writeTypes);
      if (!success) {
        setState(() {
          _showHealthError = true;
        });
      }
    } catch (e) {
      log("HealthKit permission request failed: $e");
      setState(() {
        _showHealthError = true;
      });
    }
  }

  @override
  void initState() {
    _initRecorder();
    _requestHealthPermission(); // 請求健康資料授權
    super.initState();
    // 每秒進行一次推論，無論模式如何都會執行，但更新畫面時會根據模式有所區分
    Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _runInference();
    });
  }

  // 初始化錄音器與推論輔助物件
  Future<void> _initRecorder() async {
    _helper = AudioClassificationHelper();
    await _helper.initHelper();
    bool success = await _requestPermission();
    if (success) {
      _startRecorder();
    } else {
      setState(() {
        _showError = true;
      });
    }
  }

  // 每秒進行推論
  Future<void> _runInference() async {
    // 取得當前音訊資料並進行推論
    Float32List inputArray = await _getAudioFloatArray();
    // 確保有足夠長度
    if (inputArray.length < _requiredInputBuffer) return;
    final Map<String, double> result = await _helper.inference(
      inputArray.sublist(0, _requiredInputBuffer),
    );

    // 連續模式下，累積結果並每 5 秒更新一次顯示
    if (_isContinuous) {
      _resultsHistory.add(result);
      if (_resultsHistory.length < 5) return;
      // 計算最近 5 秒的平均值
      Map<String, double> averageResult =
          _computeAverage(_resultsHistory.sublist(_resultsHistory.length - 5));
      // 排序並取前 10 個結果
      List<MapEntry<String, double>> sortedEntries = averageResult.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      setState(() {
        _hrvResult = "";
        _classification = sortedEntries.reversed.take(10).toList();
      });
    } else {
      // 定時模式下，若正在進行定時判斷則累積結果
      if (_timedJudgmentActive) {
        _timedResultsHistory.add(result);
      }
    }
  }

  // 計算多筆結果的平均值
  Map<String, double> _computeAverage(List<Map<String, double>> results) {
    final Map<String, double> sumMap = {};
    for (final result in results) {
      result.forEach((label, prob) {
        sumMap[label] = (sumMap[label] ?? 0) + prob;
      });
    }
    final int count = results.length;
    final Map<String, double> avgMap = {};
    sumMap.forEach((label, total) {
      avgMap[label] = total / count;
    });
    return avgMap;
  }

  // 切換模式：連續模式與定時模式之間切換
  void _toggleMode() {
    setState(() {
      _isContinuous = !_isContinuous;
      if (_isContinuous)
        _hrvResult = "即時模式，偵測環境音效中...";
      else
        _hrvResult = "請點擊定時判斷功能";
      _isClickTimemode = false;
      _isClickExport = false;
      // 清空兩種模式的歷史資料
      _resultsHistory.clear();
      _timedResultsHistory.clear();
      // 清除畫面上顯示的結果
      _classification = List.empty();
      // 若切換至定時模式，則取消任何進行中的定時推論
      _timedJudgmentActive = false;
    });
  }

// 顯示定時判斷選單，讓使用者選擇不同的時長
void _showTimedJudgmentOptions() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return SimpleDialog(
        title: const Text("選擇定時推論時長"),
        children: <Widget>[
          SimpleDialogOption(
            child: const Text("5 秒"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(5);
            },
          ),
          SimpleDialogOption(
            child: const Text("15 秒"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(15);
            },
          ),
          SimpleDialogOption(
            child: const Text("30 秒"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(30);
            },
          ),
          SimpleDialogOption(
            child: const Text("1 分鐘"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(60);
            },
          ),
          SimpleDialogOption(
            child: const Text("2 分鐘"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(120);
            },
          ),
          SimpleDialogOption(
            child: const Text("3 分鐘"),
            onPressed: () {
              Navigator.pop(context);
              _startTimedJudgment(180);
            },
          ),
        ],
      );
    },
  );
}

  // 定時判斷功能：根據傳入秒數進行定時推論
  void _startTimedJudgment(int durationInSeconds) {
    _isClickTimemode = true;
    _isClickExport = false;
    
    // 如果有先前的定時器存在，先取消它
    if (_timedTimer != null && _timedTimer!.isActive) {
      _timedTimer!.cancel();
    }
    
    // 根據秒數決定顯示的時間格式
    String displayTime;
    if (durationInSeconds < 60) {
      displayTime = "$durationInSeconds 秒";
    } else {
      int minutes = durationInSeconds ~/ 60;
      displayTime = "$minutes 分鐘";
    }
    
    // 重置歷史資料與狀態
    setState(() {
      _timedResultsHistory.clear();
      _timedJudgmentActive = true;
      _hrvResult = "$displayTime 定時模式，偵測環境音效中...";
      _classification = List.empty();
    });
    
    // 啟動新的定時器
    _timedTimer = Timer(Duration(seconds: durationInSeconds), () {
      if (_timedResultsHistory.isNotEmpty) {
        Map<String, double> averageResult = _computeAverage(_timedResultsHistory);
        List<MapEntry<String, double>> sortedEntries = averageResult.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        setState(() {
          _classification = sortedEntries.reversed.take(10).toList();
        });
      }
      setState(() {
        _timedJudgmentActive = false;
        _hrvResult = "";
      });
    });
  }


  // --------------------
  // 以下為「匯出健康資料」功能
  // --------------------

  // 利用 URL Scheme 開啟 Apple 健康 App 指定頁面
  Future<void> _openHealthApp() async {
    // 這裡以匯出資料頁面示範，可根據實際需求調整 URL
    final Uri healthUrl = Uri.parse('x-apple-health://sources');
    if (await canLaunchUrl(healthUrl)) {
      await launchUrl(healthUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("無法開啟 Apple 健康 App")),
      );
    }
  }

  // 顯示匯出提示對話框，說明操作步驟，並提供開啟健康 App 的按鈕
  void _showExportGuideDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("匯出健康資料"),
          content: const Text(
            "1. 點選下方「開啟健康 App」按鈕\n"
            "2. 點選「右上角個人頭像」\n"
            "3. 選擇「輸出所有健康資料」\n"
            "4. 等待 Zip 檔案生成，然後選擇分享",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openHealthApp();
              },
              child: const Text("開啟健康 App"),
            ),
          ],
        );
      },
    );
  }

  // --------------------
  // 以下為「心電圖資料」功能：利用 URL Scheme 跳轉到心電圖頁面
  // --------------------
  Future<void> _openECGPage() async {
    // 這裡假設 URL 為 x-apple-health://electrocardiograms
    final Uri ecgUrl = Uri.parse('x-apple-health://browse?query=ECG');
    if (await canLaunchUrl(ecgUrl)) {
      await launchUrl(ecgUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("無法開啟心電圖頁面")),
      );
    }
  }
  // --------------------
  // 以上為「心電圖資料」功能
  // --------------------

  @override
  void dispose() {
    _closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Image.asset('assets/images/tfl_logo.png'),
        backgroundColor: Colors.black.withOpacity(0.8),
        actions: [
          IconButton(
            onPressed: _toggleMode,
            icon: Icon(
              _isContinuous ? Icons.timer : Icons.autorenew,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 10),
            if (_showHealthError)
              const Text(
                'HealthKit 權限請求失敗，無法進行心率分析。',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            // 按鈕區塊：從左至右依序為「定時判斷」、「心電圖資料」、「匯出健康資料」
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isContinuous ? null : _showTimedJudgmentOptions,
                    child: const Text("定時判斷"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _openECGPage,
                    child: const Text("心電圖"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _showExportGuideDialog,
                    child: const Text("匯出健康資料"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isContinuous && _hrvResult.isNotEmpty)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      _hrvResult,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              )
            // 若非連續模式且已點擊定時功能或匯出功能，顯示提示訊息（可依需求做後續處理）
            else if (!_isContinuous && _hrvResult.isNotEmpty)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      _hrvResult,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              )
            else
              // 否則顯示原有分類結果列表
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  physics: const BouncingScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _classification.length,
                  itemBuilder: (context, index) {
                    final item = _classification[index];
                    return Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(item.key),
                        ),
                        Flexible(
                          child: LinearProgressIndicator(
                            backgroundColor: _backgroundProgressColorList[
                                index % _backgroundProgressColorList.length],
                            color: _primaryProgressColorList[
                                index % _primaryProgressColorList.length],
                            value: item.value,
                            minHeight: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${(item.value * 100).toStringAsFixed(2)}%",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
