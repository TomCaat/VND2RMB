import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


/// 默认汇率常量（100 RMB = 359,877 VND）
const double defaultRate = 3598.77; // 1 RMB = 3598.77 VND

void main() {
  runApp(const VndRmbApp());
}

/// 应用根组件
class VndRmbApp extends StatelessWidget {
  const VndRmbApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(child: ConverterPage()),
      ),
    );
  }
}

/// 主页面，管理多个转换器和汇率状态
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  double _exchangeRate = defaultRate;
  bool _usingDefaultRate = false;
  final List<ConverterController> _controllers = [];
  String? _errorMessage;

  final List<ExchangeRateSource> _sources = [
    ExchangeRateSource(
      name: 'ExchangeRate API',
      fetch: fetchFromExchangeRateApi,
    ),
    ExchangeRateSource(
      name: 'Frankfurter API',
      fetch: fetchFromFrankfurterApi,
    ),
    ExchangeRateSource(
      name: 'Currency API',
      fetch: fetchFromCurrencyApi,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
    _addConverter();
  }

  Future<void> _fetchExchangeRate() async {
    setState(() => _usingDefaultRate = false);
    for (final source in _sources) {
      try {
        final rate = await source.fetch();
        if (rate != null && rate > 0) {
          _updateExchangeRate(rate, source.name);
          return;
        }
      } catch (_) {}
    }

    _setDefaultRate();
  }

  void _updateExchangeRate(double rate, String sourceName) {
    setState(() {
      _exchangeRate = rate;
      _usingDefaultRate = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '汇率更新成功\n来源：$sourceName\n汇率：${_exchangeRate.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setDefaultRate() {
    setState(() {
      _exchangeRate = defaultRate;
      _usingDefaultRate = true;
    });
  }

  void _addConverter() {
    if (_controllers.length >= 8) {
      setState(() => _errorMessage = "Made by Aristo");
      ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '最多只能添加8个转换器',
                style: TextStyle(fontSize: 16),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      return;
    }
    setState(() {
      _controllers.add(ConverterController());
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 如果当前使用的是默认汇率，显示顶部红色提示条
        if (_usingDefaultRate)
          Container(
            width: double.infinity, // 宽度撑满父容器
            color: Colors.redAccent, // 红色背景，突出提示
            padding: const EdgeInsets.all(8), // 内边距8像素
            child: const Text(
              'Using default exchange rate (100 RMB = 359,877 VND)', // 提示内容
              style: TextStyle(
                color: Colors.white, // 白色文字
                fontWeight: FontWeight.bold, // 加粗
              ),
              textAlign: TextAlign.center, // 文字居中
            ),
          ),

        // 主体部分：转换器列表，撑满剩余空间
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8), // 列表四周内边距
            itemCount: _controllers.length, // 列表项数量 = 当前转换器数量
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6), // 列表项上下间距6
                child: ConverterWidget(
                  key: ValueKey(_controllers[index]), // 唯一key，保证列表项唯一性和性能
                  controller: _controllers[index], // 当前转换器控制器
                  exchangeRate: _exchangeRate, // 当前汇率，传递给转换器
                ),
              );
            },
          ),
        ),

        // 如果有错误消息，显示红色错误提示文字
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8), // 底部间距8像素
            child: Text(
              _errorMessage!, // 错误信息内容
              style: const TextStyle(
                color: Color.fromARGB(255, 146, 139, 139), // 红色字体
                fontWeight: FontWeight.bold, // 加粗
              ),
            ),
          ),

        // 底部添加转换器按钮，带图标和文字
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8), // 上下间距8像素
          child: ElevatedButton.icon(
            onPressed: _addConverter, // 点击触发添加转换器逻辑
            icon: const Icon(Icons.add), // 添加图标
            label: const Text('Add Converter'), // 按钮文本
          ),
        )
      ],
    );
  }
}

class ExchangeRateSource {
  final String name;
  final Future<double?> Function() fetch;

  const ExchangeRateSource({
    required this.name,
    required this.fetch,
  });
}



/// 控制转换器状态，输入框内容及按钮状态
class ConverterController {
  // 两个输入框的文本编辑控制器，初始为 "0"
  final TextEditingController rmbController = TextEditingController(text: '0');
  final TextEditingController vndController = TextEditingController(text: '0');
  final FocusNode rmbFocusNode = FocusNode();
  final FocusNode vndFocusNode = FocusNode();

  // 当前被输入的框：'rmb' 或 'vnd'，null表示无输入中（防止循环）
  String? activeInput;

  // K和W按钮状态，互斥。'k', 'w' 或 null
  String? scaleMode;

  /// 清空输入框和状态
  void reset() {
    rmbController.text = '0';
    vndController.text = '0';
    activeInput = null;
    scaleMode = null;
  }

  void dispose() {
    rmbController.dispose();
    vndController.dispose();
    rmbFocusNode.dispose();
    vndFocusNode.dispose();
  }
}

/// 单个转换器UI和交互逻辑
class ConverterWidget extends StatefulWidget {
  final ConverterController controller;
  final double exchangeRate; // 当前汇率（1 RMB = ? VND）

  const ConverterWidget({
    super.key,
    required this.controller,
    required this.exchangeRate,
  });

  @override
  State<ConverterWidget> createState() => _ConverterWidgetState();
}

class _ConverterWidgetState extends State<ConverterWidget> {
  late final TextEditingController _rmbCtrl;
  late final TextEditingController _vndCtrl;
  late final FocusNode _rmbFocusNode;
  late final FocusNode _vndFocusNode;
  String? _activeInput; // 'rmb' or 'vnd' 当前输入框标识
  String? _scaleMode; // null, 'k', 'w'
  bool _updating = false; // 防止递归更新
  double _rmbResult = 0;
  double _vndResult = 0;

  @override
  void initState() {
    super.initState();
    _rmbCtrl = widget.controller.rmbController;
    _vndCtrl = widget.controller.vndController;
    _activeInput = widget.controller.activeInput;
    _scaleMode = widget.controller.scaleMode;

    // 初始化FocusNode
    _rmbFocusNode = widget.controller.rmbFocusNode;
    _vndFocusNode = widget.controller.vndFocusNode;

    // 监听焦点变化
    _rmbFocusNode.addListener(() {
      if (_rmbFocusNode.hasFocus) {
        if (_rmbCtrl.text == '0') {
          _rmbCtrl.clear();
        }
      }
    });

    _vndFocusNode.addListener(() {
    if (_vndFocusNode.hasFocus) {
      if (_vndCtrl.text == '0') {
        _vndCtrl.clear();
      }
    }
    });

    // 监听输入变化
    _rmbCtrl.addListener(() {
      if (_activeInput != 'rmb' && !_updating) {
        _activeInput = 'rmb';
        widget.controller.activeInput = 'rmb';
      }
      _onInputChanged();
    });
    _vndCtrl.addListener(() {
      if (_activeInput != 'vnd' && !_updating) {
        _activeInput = 'vnd';
        widget.controller.activeInput = 'vnd';
      }
      _onInputChanged();
    });
  }

  @override
  void didUpdateWidget(covariant ConverterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 汇率变化时，重新计算结果框内容
    if (oldWidget.exchangeRate != widget.exchangeRate && _activeInput != null) {
      _recalculate();
    }
  }

  /// 当用户输入变化时，更新结果框
  void _onInputChanged() {
    if (_updating) return;
    _recalculate();
  }

  /// 核心计算逻辑，根据当前输入框、scaleMode和汇率转换另一个框
  void _recalculate() {
    if (_activeInput == null) return;
    _updating = true;

    // 读取输入框数值，转换为double，异常时视为0
    double inputVal = 0;
    try {
      if (_activeInput == 'rmb') {
        inputVal = double.tryParse(_rmbCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      } else {
        inputVal = double.tryParse(_vndCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }
    } catch (_) {
      inputVal = 0;
    }

    // 根据scaleMode调整计算
    // K: 乘1000，W: 乘10000，null: 乘1
    int scaleFactor = 1;
    if (_scaleMode == 'k') scaleFactor = 1000;
    else if (_scaleMode == 'w') scaleFactor = 10000;

    // 输入框的实际值乘scaleFactor进行换算
    // 计算后结果再除以scaleFactor显示在结果框（保持显示输入框内容不变）
    double scaledInput = inputVal * scaleFactor;
    double resultVal;

    if (_activeInput == 'rmb') {
      // RMB -> VND
      resultVal = scaledInput * widget.exchangeRate;
      _vndResult = resultVal;
      // 结果显示在越南盾输入框
      _setControllerText(_vndCtrl, resultVal);
    } else {
      // VND -> RMB
      resultVal = scaledInput / widget.exchangeRate;
      _rmbResult = resultVal;
      // 结果显示在人民币输入框
      _setControllerText(_rmbCtrl, resultVal);
    }
    _updating = false;
    setState(() {}); // 刷新 UI
  }

  /// 设置文本控制器内容，并调整宽度（随数值长度）
  void _setControllerText(TextEditingController ctrl, double value) {
    // 保留小数最多两位，避免长小数影响显示
    String text = value.toStringAsFixed(1);
    // 去除末尾多余0和小数点
    text = text.replaceAll(RegExp(r'([.]*0+)$'), '');
    if (ctrl.text != text) {
      ctrl.text = text;
    }
  }

  /// K按钮点击切换，互斥
  void _toggleK() {
    setState(() {
      if (_scaleMode == 'k') {
        _scaleMode = null;
      } else {
        _scaleMode = 'k';
      }
      if (_scaleMode == 'k') {
        widget.controller.scaleMode = 'k';
      } else {
        widget.controller.scaleMode = null;
      }
      // 切换后重新计算
      _recalculate();
    });
  }

  /// W按钮点击切换，互斥
  void _toggleW() {
    setState(() {
      if (_scaleMode == 'w') {
        _scaleMode = null;
      } else {
        _scaleMode = 'w';
      }
      if (_scaleMode == 'w') {
        widget.controller.scaleMode = 'w';
      } else {
        widget.controller.scaleMode = null;
      }
      // 切换后重新计算
      _recalculate();
    });
  }

  /// 重置按钮清空内容和状态
  void _reset() {
    setState(() {
      widget.controller.reset();
      _activeInput = null;
      _scaleMode = null;
      // 初始化两个输入框为0
      _rmbCtrl.text = '0';
      _vndCtrl.text = '0';
    });
  }

  /// 计算输入框宽度，基于内容长度（最小80，最大200）
  double _calcInputWidth(String text) {
    int len = text.length;
    double width = len * 13.0;
    if (width < 80) width = 80;
    return width;
  }

  @override
  Widget build(BuildContext context) {
    String rmbLabel = (_rmbResult > 0 && _rmbResult < 1) ? 'RMB<1' : 'RMB';
    String vndLabel = (_vndResult > 0 && _vndResult < 1) ? 'VND<1' : 'VND';
    return Row(
      children: [
        // 人民币输入框
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 80,
              maxWidth: min(_calcInputWidth(_rmbCtrl.text), 96),
            ),
          child: TextField(
            controller: _rmbCtrl,
            focusNode: _rmbFocusNode,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:  InputDecoration(
              labelText: rmbLabel,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
            onTap: () {
              _activeInput = 'rmb';
              widget.controller.activeInput = 'rmb';
            },
          ),
        )),
        const SizedBox(width: 8),
        // 越南盾输入框
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 80,
              maxWidth: min(_calcInputWidth(_vndCtrl.text), 160),
            ),
          child: TextField(
            controller: _vndCtrl,
            focusNode: _vndFocusNode,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:  InputDecoration(
              labelText: vndLabel,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
            onTap: () {
              _activeInput = 'vnd';
              widget.controller.activeInput = 'vnd';
            },
          ),
        )),
        const SizedBox(width: 12),
        // K按钮
        SizedBox(
          width: 40,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _scaleMode == 'k' ? const Color.fromARGB(255, 121, 156, 216) : Colors.grey[300],
              foregroundColor:
                  _scaleMode == 'k' ? Colors.white : Colors.black87,
              padding: EdgeInsets.zero,
            ),
            onPressed: _toggleK,
            child: const Text('K', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        // W按钮
        SizedBox(
          width: 40,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _scaleMode == 'w' ? const Color.fromARGB(255, 101, 232, 236): Colors.grey[300],
              foregroundColor:
                  _scaleMode == 'w' ? Colors.white : Colors.black87,
              padding: EdgeInsets.zero,
            ),
            onPressed: _toggleW,
            child: const Text('W', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        // 重置按钮
        SizedBox(
          width: 40,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 96, 96),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            onPressed: _reset,
            child: const Icon(Icons.refresh, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // 控制器由父持有，子widget不释放
    super.dispose();
    _rmbFocusNode.dispose();
    _vndFocusNode.dispose();
  }
}

Future<double?> fetchFromExchangeRateApi() async {
  const url = 'https://open.er-api.com/v6/latest/VND';
  final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
  if (res.statusCode == 200) {
    final jsonBody = jsonDecode(res.body);
    if (jsonBody['result'] == 'success') {
      final rates = jsonBody['rates'] as Map<String, dynamic>;
      final vndToCny = rates['CNY'] as num?;
      if (vndToCny != null && vndToCny > 0) return 1 / vndToCny.toDouble();
    }
  }
  return null;
}

Future<double?> fetchFromFrankfurterApi() async {
  const url = 'https://api.frankfurter.app/latest?from=VND&to=CNY';
  final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
  if (res.statusCode == 200) {
    final jsonBody = jsonDecode(res.body);
    final vndToCny = (jsonBody['rates']?['CNY'] as num?)?.toDouble();
    if (vndToCny != null && vndToCny > 0) return 1 / vndToCny;
  }
  return null;
}

Future<double?> fetchFromCurrencyApi() async {
  const url = 'https://currencyapi.net/api/v1/rates?key=demo&base=VND';
  final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
  if (res.statusCode == 200) {
    final jsonBody = jsonDecode(res.body);
    final vndToCny = (jsonBody['rates']?['CNY'] as num?)?.toDouble();
    if (vndToCny != null && vndToCny > 0) return 1 / vndToCny;
  }
  return null;
}
