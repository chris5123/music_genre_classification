// /*
//  * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
//  *
//  * Licensed under the Apache License, Version 2.0 (the "License");
//  * you may not use this file except in compliance with the License.
//  * You may obtain a copy of the License at
//  *
//  *             http://www.apache.org/licenses/LICENSE-2.0
//  *
//  * Unless required by applicable law or agreed to in writing, software
//  * distributed under the License is distributed on an "AS IS" BASIS,
//  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  * See the License for the specific language governing permissions and
//  * limitations under the License.
//  */

// import 'dart:async';
// import 'dart:developer';
// import 'dart:typed_data';

// import 'helper/audio_classification_helper.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import 'package:flutter_sound/flutter_sound.dart';
// import 'flutter_sound_processing.dart';
// import 'package:permission_handler/permission_handler.dart';

// const int bufferSize = 7839;
// const int sampleRate = 22500;
// const int hopLength = 350;
// const int nMels = 40;
// const int fftSize = 512;
// const int mfcc = 40;

// void main() {
//   runApp(const AudioClassificationApp());
// }

// class AudioClassificationApp extends StatelessWidget {
//   const AudioClassificationApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Audio Classification',
//       theme: ThemeData(
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Audio classification home page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   static const platform =
//       MethodChannel('org.tensorflow.audio_classification/audio_record');

//   // The YAMNet/classifier model used in this code example accepts data that
//   // represent single-channel, or mono, audio clips recorded at 16kHz in 0.975
//   // second clips (15600 samples).
//   static const _sampleRate = 16000; // 16kHz
//   static const _expectAudioLength = 975; // milliseconds
//   final int _requiredInputBuffer =
//       (16000 * (_expectAudioLength / 1000)).toInt();
//   late AudioClassificationHelper _helper;
//   List<MapEntry<String, double>> _classification = List.empty();
//   final List<Color> _primaryProgressColorList = [
//     const Color(0xFFF44336),
//     const Color(0xFFE91E63),
//     const Color(0xFF9C27B0),
//     const Color(0xFF3F51B5),
//     const Color(0xFF2196F3),
//     const Color(0xFF00BCD4),
//     const Color(0xFF009688),
//     const Color(0xFF4CAF50),
//     const Color(0xFFFFEB3B),
//     const Color(0xFFFFC107),
//     const Color(0xFFFF9800)
//   ];
//   final List<Color> _backgroundProgressColorList = [
//     const Color(0x44F44336),
//     const Color(0x44E91E63),
//     const Color(0x449C27B0),
//     const Color(0x443F51B5),
//     const Color(0x442196F3),
//     const Color(0x4400BCD4),
//     const Color(0x44009688),
//     const Color(0x444CAF50),
//     const Color(0x44FFEB3B),
//     const Color(0x44FFC107),
//     const Color(0x44FF9800)
//   ];
//   var _showError = false;

//   void _startRecorder() {
//     try {
//       platform.invokeMethod('startRecord');
//     } on PlatformException catch (e) {
//       log("Failed to start record: '${e.message}'.");
//     }
//   }

//   Future<bool> _requestPermission() async {
//     try {
//       return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
//         "sampleRate": _sampleRate,
//         "requiredInputBuffer": _requiredInputBuffer
//       });
//     } on Exception catch (e) {
//       log("Failed to create recorder: '${e.toString()}'.");
//       return false;
//     }
//   }

//   Future<Float32List> _getAudioFloatArray() async {
//     var audioFloatArray = Float32List(0);
//     try {
//       final Float32List result =
//           await platform.invokeMethod('getAudioFloatArray');
//       audioFloatArray = result;
//     } on PlatformException catch (e) {
//       log("Failed to get audio array: '${e.message}'.");
//     }
//     return audioFloatArray;
//   }

//   Future<void> _closeRecorder() async {
//     try {
//       await platform.invokeMethod('closeRecorder');
//       _helper.closeInterpreter();
//     } on PlatformException {
//       log("Failed to close recorder.");
//     }
//   }

//   @override
//   initState() {
//     _initRecorder();
//     super.initState();
//   }

//   Future<void> _initRecorder() async {
//     _helper = AudioClassificationHelper();
//     await _helper.initHelper();
//     bool success = await _requestPermission();
//     if (success) {
//       _startRecorder();

//       Timer.periodic(const Duration(milliseconds: _expectAudioLength), (timer) {
//         // classify here
//         _runInference();
//       });
//     } else {
//       // show error here
//       setState(() {
//         _showError = true;
//       });
//     }
//   }

//   Future<void> _runInference() async {
//     Float32List inputArray = await _getAudioFloatArray();
//     final result =
//         await _helper.inference(inputArray.sublist(0, _requiredInputBuffer));
//     setState(() {
//       // take top 3 classification
//       _classification = (result.entries.toList()
//             ..sort(
//               (a, b) => a.value.compareTo(b.value),
//             ))
//           .reversed
//           .take(3)
//           .toList();
//     });
//   }

//   @override
//   void dispose() {
//     _closeRecorder();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Image.asset('assets/images/tfl_logo.png'),
//         backgroundColor: Colors.black.withOpacity(0.5),
//       ),
//       body: _buildBody(),
//     );
//   }

//   Widget _buildBody() {
//     if (_showError) {
//       return const Center(
//         child: Text(
//           "Audio recording permission required for audio classification",
//           textAlign: TextAlign.center,
//         ),
//       );
//     } else {
//       return ListView.separated(
//         padding: const EdgeInsets.all(10),
//         physics: const BouncingScrollPhysics(),
//         shrinkWrap: true,
//         itemCount: _classification.length,
//         itemBuilder: (context, index) {
//           final item = _classification[index];
//           return Row(
//             children: [
//               SizedBox(
//                 width: 200,
//                 child: Text(item.key),
//               ),
//               Flexible(
//                   child: LinearProgressIndicator(
//                 backgroundColor: _backgroundProgressColorList[
//                     index % _backgroundProgressColorList.length],
//                 color: _primaryProgressColorList[
//                     index % _primaryProgressColorList.length],
//                 value: item.value,
//                 minHeight: 20,
//               ))
//             ],
//           );
//         },
//         separatorBuilder: (BuildContext context, int index) => const SizedBox(
//           height: 10,
//         ),
//       );
//     }
//   }
// }


/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */






// import 'dart:async';
// import 'dart:developer';
// import 'dart:typed_data';

// import 'helper/audio_classification_helper.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'flutter_sound_processing.dart';
// import 'package:permission_handler/permission_handler.dart';

// void main() {
//   runApp(const AudioClassificationApp());
// }

// class AudioClassificationApp extends StatelessWidget {
//   const AudioClassificationApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Audio Classification',
//       theme: ThemeData(
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Audio Classification Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   static const platform =
//       MethodChannel('org.tensorflow.audio_classification/audio_record');

//   // 16kHz configuration and expected audio length in milliseconds
//   static const _sampleRate = 16000;
//   static const _expectAudioLength = 975;
//   final int _requiredInputBuffer =
//       (16000 * (_expectAudioLength / 1000)).toInt();

//   late AudioClassificationHelper _helper;
//   // Stores the top 3 results to display
//   List<MapEntry<String, double>> _classification = List.empty();
//   // Stores inference results for each second (each result is assumed to be a Map<String, double>)
//   final List<Map<String, double>> _resultsHistory = [];

//   final List<Color> _primaryProgressColorList = [
//     const Color(0xFFF44336),
//     const Color(0xFFE91E63),
//     const Color(0xFF9C27B0),
//     const Color(0xFF3F51B5),
//     const Color(0xFF2196F3),
//     const Color(0xFF00BCD4),
//     const Color(0xFF009688),
//     const Color(0xFF4CAF50),
//     const Color(0xFFFFEB3B),
//     const Color(0xFFFFC107),
//     const Color(0xFFFF9800)
//   ];
//   final List<Color> _backgroundProgressColorList = [
//     const Color(0x44F44336),
//     const Color(0x44E91E63),
//     const Color(0x449C27B0),
//     const Color(0x443F51B5),
//     const Color(0x442196F3),
//     const Color(0x4400BCD4),
//     const Color(0x44009688),
//     const Color(0x444CAF50),
//     const Color(0x44FFEB3B),
//     const Color(0x44FFC107),
//     const Color(0x44FF9800)
//   ];
//   var _showError = false;

//   // Start recording
//   void _startRecorder() {
//     try {
//       platform.invokeMethod('startRecord');
//     } on PlatformException catch (e) {
//       log("Failed to start record: '${e.message}'.");
//     }
//   }

//   // Request permission and create recorder
//   Future<bool> _requestPermission() async {
//     try {
//       return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
//         "sampleRate": _sampleRate,
//         "requiredInputBuffer": _requiredInputBuffer
//       });
//     } on Exception catch (e) {
//       log("Failed to create recorder: '${e.toString()}'.");
//       return false;
//     }
//   }

//   // Get audio data as Float32List
//   Future<Float32List> _getAudioFloatArray() async {
//     var audioFloatArray = Float32List(0);
//     try {
//       final Float32List result =
//           await platform.invokeMethod('getAudioFloatArray');
//       audioFloatArray = result;
//     } on PlatformException catch (e) {
//       log("Failed to get audio array: '${e.message}'.");
//     }
//     return audioFloatArray;
//   }

//   // Close recorder and release resources
//   Future<void> _closeRecorder() async {
//     try {
//       await platform.invokeMethod('closeRecorder');
//       _helper.closeInterpreter();
//     } on PlatformException {
//       log("Failed to close recorder.");
//     }
//   }

//   @override
//   void initState() {
//     _initRecorder();
//     super.initState();
//   }

//   // Initialize the recorder and inference helper
//   Future<void> _initRecorder() async {
//     _helper = AudioClassificationHelper();
//     await _helper.initHelper();
//     bool success = await _requestPermission();
//     if (success) {
//       _startRecorder();
//       // Run inference every second
//       Timer.periodic(const Duration(milliseconds: 1000), (timer) {
//         _runInference();
//       });
//     } else {
//       setState(() {
//         _showError = true;
//       });
//     }
//   }

//   // Perform an inference and update the displayed results (only after accumulating at least 5 results)
//   Future<void> _runInference() async {
//     // Get the current audio data and run inference
//     Float32List inputArray = await _getAudioFloatArray();
//     final Map<String, double> result = await _helper.inference(
//       inputArray.sublist(0, _requiredInputBuffer),
//     );

//     // Add the result to history
//     _resultsHistory.add(result);

//     // If there are fewer than 5 results, do not update the display
//     if (_resultsHistory.length < 5) {
//       return;
//     }

//     // Compute the moving average over the most recent 5 results
//     Map<String, double> averageResult =
//         _computeAverage(_resultsHistory.sublist(_resultsHistory.length - 5));

//     // Sort the averaged results and take the top 3 (in descending order)
//     List<MapEntry<String, double>> sortedEntries = averageResult.entries.toList()
//       ..sort((a, b) => a.value.compareTo(b.value));
//     setState(() {
//       _classification = sortedEntries.reversed.take(10).toList();
//     });
//   }

//   // Compute the average of a list of results (each result is a Map<String, double>)
//   Map<String, double> _computeAverage(List<Map<String, double>> results) {
//     final Map<String, double> sumMap = {};
//     // Sum the values for each label
//     for (final result in results) {
//       result.forEach((label, prob) {
//         sumMap[label] = (sumMap[label] ?? 0) + prob;
//       });
//     }
//     // Divide by the number of results to compute the average
//     final int count = results.length;
//     final Map<String, double> avgMap = {};
//     sumMap.forEach((label, total) {
//       avgMap[label] = total / count;
//     });
//     return avgMap;
//   }

//   @override
//   void dispose() {
//     _closeRecorder();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Image.asset('assets/images/tfl_logo.png'),
//         backgroundColor: Colors.black.withOpacity(0.5),
//       ),
//       body: _buildBody(),
//     );
//   }

//   // Display error message or classification results
//   Widget _buildBody() {
//     if (_showError) {
//       return const Center(
//         child: Text(
//           "Audio recording permission required for audio classification",
//           textAlign: TextAlign.center,
//         ),
//       );
//     } else {
//       // If _classification is empty, show a waiting message
//       return _classification.isEmpty
//           ? const Center(child: Text("Please wait at least 5 seconds before displaying results"))
//           : ListView.separated(
//               padding: const EdgeInsets.all(10),
//               physics: const BouncingScrollPhysics(),
//               shrinkWrap: true,
//               // itemCount: _classification.length,
//               itemCount: 10,
//               itemBuilder: (context, index) {
//                 final item = _classification[index];
//                 return Row(
//                   children: [
//                     SizedBox(
//                       width: 200,
//                       child: Text(item.key),
//                     ),
//                     Flexible(
//                       child: LinearProgressIndicator(
//                         backgroundColor: _backgroundProgressColorList[
//                             index % _backgroundProgressColorList.length],
//                         color: _primaryProgressColorList[
//                             index % _primaryProgressColorList.length],
//                         value: item.value,
//                         minHeight: 20,
//                       ),
//                     )
//                   ],
//                 );
//               },
//               separatorBuilder: (BuildContext context, int index) =>
//                   const SizedBox(height: 30),
//             );
//     }
//   }
// }


// import 'dart:async';
// import 'dart:developer';
// import 'dart:typed_data';

// import 'helper/audio_classification_helper.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import 'health_kit_reporter.dart';
// import 'model/predicate.dart';

// void main() {
//   runApp(const AudioClassificationApp());
// }

// class AudioClassificationApp extends StatelessWidget {
//   const AudioClassificationApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Audio Classification',
//       theme: ThemeData(
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Audio Classification Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   static const platform =
//       MethodChannel('org.tensorflow.audio_classification/audio_record');

//   // 16kHz configuration and expected audio length in milliseconds
//   static const _sampleRate = 16000;
//   static const _expectAudioLength = 975;
//   final int _requiredInputBuffer =
//       (16000 * (_expectAudioLength / 1000)).toInt();

//   late AudioClassificationHelper _helper;
//   // 儲存顯示用的分類結果 (列表數量可自行調整)
//   List<MapEntry<String, double>> _classification = List.empty();
//   // 連續模式下的結果歷史（每秒一次，每個結果為 Map<String, double>）
//   final List<Map<String, double>> _resultsHistory = [];
//   // 定時模式下累積的結果（按下定時判斷功能後開始累積 5 秒的結果）
//   final List<Map<String, double>> _timedResultsHistory = [];

//   // 模式切換：true 表示連續模式（預設）；false 表示定時模式
//   bool _isContinuous = true;
//   // 定時模式中是否正在進行定時判斷
//   bool _timedJudgmentActive = false;

//   final List<Color> _primaryProgressColorList = [
//     const Color(0xFFF44336),
//     const Color(0xFFE91E63),
//     const Color(0xFF9C27B0),
//     const Color(0xFF3F51B5),
//     const Color(0xFF2196F3),
//     const Color(0xFF00BCD4),
//     const Color(0xFF009688),
//     const Color(0xFF4CAF50),
//     const Color(0xFFFFEB3B),
//     const Color(0xFFFFC107),
//     const Color(0xFFFF9800)
//   ];
//   final List<Color> _backgroundProgressColorList = [
//     const Color(0x44F44336),
//     const Color(0x44E91E63),
//     const Color(0x449C27B0),
//     const Color(0x443F51B5),
//     const Color(0x442196F3),
//     const Color(0x4400BCD4),
//     const Color(0x44009688),
//     const Color(0x444CAF50),
//     const Color(0x44FFEB3B),
//     const Color(0x44FFC107),
//     const Color(0x44FF9800)
//   ];
//   var _showError = false;

//   // 開始錄音
//   void _startRecorder() {
//     try {
//       platform.invokeMethod('startRecord');
//     } on PlatformException catch (e) {
//       log("Failed to start record: '${e.message}'.");
//     }
//   }

//   // 請求權限並建立錄音器
//   Future<bool> _requestPermission() async {
//     try {
//       return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
//         "sampleRate": _sampleRate,
//         "requiredInputBuffer": _requiredInputBuffer
//       });
//     } on Exception catch (e) {
//       log("Failed to create recorder: '${e.toString()}'.");
//       return false;
//     }
//   }

//   // 取得音訊資料（Float32List）
//   Future<Float32List> _getAudioFloatArray() async {
//     var audioFloatArray = Float32List(0);
//     try {
//       final Float32List result =
//           await platform.invokeMethod('getAudioFloatArray');
//       audioFloatArray = result;
//     } on PlatformException catch (e) {
//       log("Failed to get audio array: '${e.message}'.");
//     }
//     return audioFloatArray;
//   }

//   // 關閉錄音器並釋放資源
//   Future<void> _closeRecorder() async {
//     try {
//       await platform.invokeMethod('closeRecorder');
//       _helper.closeInterpreter();
//     } on PlatformException {
//       log("Failed to close recorder.");
//     }
//   }

//   @override
//   void initState() {
//     _initRecorder();
//     super.initState();
//     // 每秒進行一次推論，無論模式如何都會執行，但更新畫面時會根據模式有所區分
//     Timer.periodic(const Duration(milliseconds: 1000), (timer) {
//       _runInference();
//     });
//   }

//   // 初始化錄音器與推論輔助物件
//   Future<void> _initRecorder() async {
//     _helper = AudioClassificationHelper();
//     await _helper.initHelper();
//     bool success = await _requestPermission();
//     if (success) {
//       _startRecorder();
//     } else {
//       setState(() {
//         _showError = true;
//       });
//     }
//   }

//   // 每秒進行推論
//   Future<void> _runInference() async {
//     // 取得當前音訊資料並進行推論
//     Float32List inputArray = await _getAudioFloatArray();
//     // 確保有足夠長度
//     if (inputArray.length < _requiredInputBuffer) return;
//     final Map<String, double> result = await _helper.inference(
//       inputArray.sublist(0, _requiredInputBuffer),
//     );

//     // 連續模式下，累積結果並每 5 秒更新一次顯示
//     if (_isContinuous) {
//       _resultsHistory.add(result);
//       if (_resultsHistory.length < 5) return;
//       // 計算最近 5 秒的平均值
//       Map<String, double> averageResult =
//           _computeAverage(_resultsHistory.sublist(_resultsHistory.length - 5));
//       // 排序並取前 10 個結果
//       List<MapEntry<String, double>> sortedEntries = averageResult.entries.toList()
//         ..sort((a, b) => a.value.compareTo(b.value));
//       setState(() {
//         _classification = sortedEntries.reversed.take(10).toList();
//       });
//     } else {
//       // 定時模式下，若正在進行定時判斷則累積結果
//       if (_timedJudgmentActive) {
//         _timedResultsHistory.add(result);
//       }
//       // 否則不更新顯示（保持上次結果）
//     }
//   }

//   // 計算多筆結果的平均值
//   Map<String, double> _computeAverage(List<Map<String, double>> results) {
//     final Map<String, double> sumMap = {};
//     for (final result in results) {
//       result.forEach((label, prob) {
//         sumMap[label] = (sumMap[label] ?? 0) + prob;
//       });
//     }
//     final int count = results.length;
//     final Map<String, double> avgMap = {};
//     sumMap.forEach((label, total) {
//       avgMap[label] = total / count;
//     });
//     return avgMap;
//   }

//   // 切換模式：連續模式與定時模式之間切換
//   void _toggleMode() {
//     setState(() {
//       _isContinuous = !_isContinuous;
//       // 清空兩種模式的歷史資料
//       _resultsHistory.clear();
//       _timedResultsHistory.clear();
//       // 清除畫面上顯示的結果
//       _classification = List.empty();
//       // 若切換至定時模式，則取消任何進行中的定時推論
//       _timedJudgmentActive = false;
//     });
//   }

//   // 定時判斷功能：點下後等待 5 秒，然後僅更新一次結果
//   void _startTimedJudgment() {
//     if (_timedJudgmentActive) return; // 避免重複啟動
//     setState(() {
//       _timedResultsHistory.clear();
//       _timedJudgmentActive = true;
//       // 清除顯示結果，等待更新
//       _classification = List.empty();
//     });
//     Timer(const Duration(seconds: 5), () {
//       if (_timedResultsHistory.isNotEmpty) {
//         Map<String, double> averageResult = _computeAverage(_timedResultsHistory);
//         List<MapEntry<String, double>> sortedEntries = averageResult.entries.toList()
//           ..sort((a, b) => a.value.compareTo(b.value));
//         setState(() {
//           _classification = sortedEntries.reversed.take(10).toList();
//         });
//       }
//       setState(() {
//         _timedJudgmentActive = false;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _closeRecorder();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Image.asset('assets/images/tfl_logo.png'),
//         backgroundColor: Colors.black.withOpacity(0.5),
//       ),
//       body: Column(
//         children: [
//           // 兩個按鈕放在上方
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: _toggleMode,
//                   child: Text(_isContinuous ? '5秒模式' : '即時模式'),
//                 ),
//                 // 定時判斷功能按鈕：僅在定時模式下有效
//                 ElevatedButton(
//                   onPressed: _isContinuous ? null : _startTimedJudgment,
//                   child: const Text('執行'),
//                 ),
//                 ElevatedButton(
//                   onPressed: null,
//                   child: Text('心率分析'),
//                 ),
//               ],
//             ),
//           ),
//           // 顯示結果區域
//           Expanded(child: _buildBody()),
//         ],
//       ),
//     );
//   }

//   // 顯示錯誤訊息或分類結果
//   Widget _buildBody() {
//     if (_showError) {
//       return const Center(
//         child: Text(
//           "Audio recording permission required for audio classification",
//           textAlign: TextAlign.center,
//         ),
//       );
//     } else {
//       return _classification.isEmpty
//           ? Center(
//               child: Text(
//                 _isContinuous
//                     ? "請等待 5 秒顯示即時模式結果"
//                     : (_timedJudgmentActive
//                         ? "正在收集環境音訊，請稍後……"
//                         : "請按下「執行」按鈕後等待 5 秒"),
//               ),
//             )
//           : ListView.separated(
//               padding: const EdgeInsets.all(10),
//               physics: const BouncingScrollPhysics(),
//               shrinkWrap: true,
//               itemCount: _classification.length,
//               itemBuilder: (context, index) {
//                 final item = _classification[index];
//                 return Row(
//                   children: [
//                     SizedBox(
//                       width: 200,
//                       child: Text(item.key),
//                     ),
//                     Flexible(
//                       child: LinearProgressIndicator(
//                         backgroundColor: _backgroundProgressColorList[
//                             index % _backgroundProgressColorList.length],
//                         color: _primaryProgressColorList[
//                             index % _primaryProgressColorList.length],
//                         value: item.value,
//                         minHeight: 20,
//                       ),
//                     )
//                   ],
//                 );
//               },
//               separatorBuilder: (BuildContext context, int index) =>
//                   const SizedBox(height: 30),
//             );
//     }
//   }
// }




import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'helper/audio_classification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        DateTime.now().add(Duration(days: -365)),
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
  static const platform =
      MethodChannel('org.tensorflow.audio_classification/audio_record');

  // 16kHz configuration and expected audio length in milliseconds
  static const _sampleRate = 16000;
  static const _expectAudioLength = 975;
  final int _requiredInputBuffer =
      (16000 * (_expectAudioLength / 1000)).toInt();

  late AudioClassificationHelper _helper;
  // 儲存顯示用的分類結果 (列表數量可自行調整)
  List<MapEntry<String, double>> _classification = List.empty();
  // 連續模式下的結果歷史（每秒一次，每個結果為 Map<String, double>）
  final List<Map<String, double>> _resultsHistory = [];
  // 定時模式下累積的結果（按下定時判斷功能後開始累積 5 秒的結果）
  final List<Map<String, double>> _timedResultsHistory = [];

  // 模式切換：true 表示連續模式（預設）；false 表示定時模式
  bool _isContinuous = true;
  // 定時模式中是否正在進行定時判斷
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
        _classification = sortedEntries.reversed.take(10).toList();
      });
    } else {
      // 定時模式下，若正在進行定時判斷則累積結果
      if (_timedJudgmentActive) {
        _timedResultsHistory.add(result);
      }
      // 否則不更新顯示（保持上次結果）
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
      // 清空兩種模式的歷史資料
      _resultsHistory.clear();
      _timedResultsHistory.clear();
      // 清除畫面上顯示的結果
      _classification = List.empty();
      // 若切換至定時模式，則取消任何進行中的定時推論
      _timedJudgmentActive = false;
    });
  }

  // 定時判斷功能：點下後等待 5 秒，然後僅更新一次結果
  void _startTimedJudgment() {
    if (_timedJudgmentActive) return; // 避免重複啟動
    setState(() {
      _timedResultsHistory.clear();
      _timedJudgmentActive = true;
      // 清除顯示結果，等待更新
      _classification = List.empty();
    });
    Timer(const Duration(seconds: 5), () {
      if (_timedResultsHistory.isNotEmpty) {
        Map<String, double> averageResult =
            _computeAverage(_timedResultsHistory);
        List<MapEntry<String, double>> sortedEntries =
            averageResult.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
        setState(() {
          _classification = sortedEntries.reversed.take(10).toList();
        });
      }
      setState(() {
        _timedJudgmentActive = false;
      });
    });
  }

  void queryElectrocardiograms() async {
    try {
      final electrocardiograms = await HealthKitReporter.electrocardiogramQuery(
          predicate,
          withVoltageMeasurements: true);
      print(
          'electrocardiograms: ${electrocardiograms.map((e) => e.map).toList()}');
    } catch (e) {
      print(e);
    }
  }

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
              _isContinuous ? Icons.refresh : Icons.timer,
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
              Text(
                'HealthKit 權限請求失敗，無法進行心率分析。',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            // 按鈕放在同一行並添加間距
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isContinuous ? null : _startTimedJudgment,
                    child: const Text("開始定時判斷"),
                  ),
                  const SizedBox(width: 20), // 按鈕間距
                  ElevatedButton(
                    onPressed: queryElectrocardiograms,
                    child: const Text("開始心率分析"),
                  ),
                ],
              ),
            ),
            // 顯示分類結果
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
                        width: 200,
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
                      SizedBox(width: 10),
                      Text(
                        "${(item.value * 100).toStringAsFixed(2)}%",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  );
                },
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
