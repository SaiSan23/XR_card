import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // 為了 Future

import 'package:my_app/data/models/user_complete_profile.dart';
import 'package:my_app/data/supabase_services.dart';
import 'package:my_app/services/ai_service.dart';
import 'package:my_app/services/google_search_service.dart';
import 'package:my_app/core/widgets/expanding_fab.dart';
import 'package:my_app/core/widgets/xr_business_card.dart';

class XrSimulatorPage extends StatefulWidget {
  const XrSimulatorPage({super.key});

  @override
  State<XrSimulatorPage> createState() => _XrSimulatorPageState();
}

class _XrSimulatorPageState extends State<XrSimulatorPage> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  // 用於獲取使用者資料
  late final SupabaseService _supabaseService;
  UserCompleteProfile? _userProfile;

  late final AiService _aiService;
  late final GoogleSearchService _googleSearchService;
  bool _isAnalyzing = false;
  String _companyAnalysisResult = '';

  // --- 「話題建議」的狀態變數 ---
  List<String> _dialogSuggestions = [];
  bool _isLoadingSuggestions = false;
  String? _suggestionError;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService(Supabase.instance.client);
    _aiService = AiService();
    _googleSearchService = GoogleSearchService();

    _initializeCamera();
    _loadUserData();
  }

  // 用於執行企業分析
  Future<void> _runCompanyAnalysis() async {
    if (_isAnalyzing) return;

    setState(() => _isAnalyzing = true);
    _showSnackBar('正在為您進行企業分析...');

    final companyName = _userProfile?.company ?? '';
    String? result;

    // --- 新增：自動重試邏輯 ---
    const maxRetries = 2; // 最多重試 2 次
    for (int i = 0; i <= maxRetries; i++) {
      result = await _aiService.analyzeCompany(companyName);

      // 如果分析成功 (不是 null 也不是特定錯誤訊息)，就跳出迴圈
      if (result != null && !result.contains('UNAVAILABLE')) {
        break;
      }

      // 如果還有重試次數，就等待一下再重試
      if (i < maxRetries) {
        debugPrint('分析失敗 (模型忙碌)，將在 2 秒後重試... (${i + 1}/$maxRetries)');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    // --- 重試邏輯結束 ---

    debugPrint('===== Gemini 企業分析結果 =====');
    debugPrint(result);
    debugPrint('=============================');

    if (mounted) {
      // 為了避免顯示原始錯誤碼，我們做個判斷
      final displayResult = (result != null && result.contains('UNAVAILABLE'))
          ? '模型目前忙碌中，請稍後再試。'
          : result ?? '沒有分析結果。';

      setState(() {
        _isAnalyzing = false;
        if (!displayResult.contains('模型目前') &&
            !displayResult.contains('沒有分析結果')) {
          _companyAnalysisResult = displayResult;
        }
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('「$companyName」分析報告'),
          content: SingleChildScrollView(child: Text(displayResult)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    }
  }

  // --- 話題建議 ---
  Future<void> _fetchDialogSuggestions() async {
    if (_isLoadingSuggestions) return;
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionError = null;
      _dialogSuggestions = [];
    });

    _showSuggestionsDialog(); // 顯示 Loading Dialog

    try {
      // 獲取公司名稱和職稱
      final companyName = _userProfile?.company;
      final jobTitle = _userProfile?.jobTitle;

      if (companyName == null || companyName.isEmpty) {
        throw Exception('未設定公司名稱');
      }

      String? companyInfo;
      List<String> newsSnippets = [];
      String? lastSummary;

      // 1. 獲取企業細節 (重用已分析的結果)
      if (_companyAnalysisResult.isNotEmpty) {
        companyInfo = _companyAnalysisResult;
      } else {
        companyInfo = null;
      }

      // 2. 獲取時事新聞 (傳入職稱)
      newsSnippets = await _fetchNews(companyName, jobTitle); // <--- 修改

      // 3. 獲取上次對話回顧 (Supabase)
      // [!] 提醒：您需要將 contactId 傳入此頁面
      // final int? currentContactId = widget.contactId;
      final int? currentContactId = null; // 暫時用 null

      if (currentContactId != null) {
        try {
          lastSummary = await _supabaseService.fetchLatestConversationSummary(
            currentContactId,
          );
        } catch (e) {
          debugPrint("Error fetching summary: $e");
        }
      }

      // 4. 生成「開場白」 (傳入職稱)
      _dialogSuggestions = await _aiService.generateSuggestions(
        companyName,
        jobTitle,
        companyInfo,
        newsSnippets,
        lastSummary,
      );
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      if (mounted) {
        setState(() {
          _suggestionError = '載入建議時發生錯誤: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
        Navigator.pop(context); // 關閉 Loading Dialog
        _showSuggestionsDialog(); // 開啟顯示結果或錯誤的 Dialog
      }
    }
  }

  // --- 輔助函式：搜尋新聞 ---
  Future<List<String>> _fetchNews(String companyName, String? jobTitle) async {
    List<String> snippets = [];
    try {
      print('正在搜尋關於 $companyName ($jobTitle) 的新聞...');

      // 建立動態的搜尋查詢列表
      List<String> queries = ["\"$companyName\" 產業動態", "\"$companyName\" 最近新聞"];

      // 如果有職稱，加入職稱相關的搜尋
      if (jobTitle != null && jobTitle.isNotEmpty) {
        queries.add("\"$jobTitle\" 產業趨勢");
        queries.add("\"$jobTitle\" 最新消息");
      }

      // 使用修正後的呼叫方式 (位置參數)
      final searchResults = await _googleSearchService.search(queries);

      // 解析 searchResults (List<Map<String, String>>)
      if (searchResults.isNotEmpty) {
        for (var item in searchResults) {
          String title = item['title'] ?? '';
          String snippet = item['snippet'] ?? '';
          String combined = title.isNotEmpty ? "$title：$snippet" : snippet;

          if (combined.isNotEmpty) {
            snippets.add(
              combined.length > 100
                  ? '${combined.substring(0, 100)}...'
                  : combined,
            );
          }
        }
      }
      print('新聞摘要: $snippets');
    } catch (e) {
      debugPrint("Error fetching news from Google Search: $e");
    }
    return snippets;
  }

  // --- 輔助函式：顯示建議的 Dialog (Modal Bottom Sheet) ---
  void _showSuggestionsDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: !_isLoadingSuggestions, // 載入中不可關閉
      enableDrag: !_isLoadingSuggestions,
      builder: (context) {
        Widget content;
        if (_isLoadingSuggestions) {
          content = const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在為您產生對話建議...'),
                ],
              ),
            ),
          );
        } else if (_suggestionError != null) {
          content = Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text('錯誤: $_suggestionError'),
            ),
          );
        } else if (_dialogSuggestions.isEmpty) {
          content = const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('目前沒有對話建議'),
            ),
          );
        } else {
          // 成功取得建議
          content = ListView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Text(
                  '試試看這樣開場：',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._dialogSuggestions.map(
                (suggestion) => ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                  title: Text(suggestion),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: content,
          ),
        );
      },
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        _showErrorDialog("找不到可用的相機");
      }
    } catch (e) {
      _showErrorDialog("相機初始化失敗: $e");
    }
  }

  Future<void> _loadUserData() async {
    try {
      // [!] 這裡目前是讀取 app 使用者自己的資料
      // 未來您需要修改這裡，讓它可以讀取 'contact' 的資料
      final profile = await _supabaseService.fetchUserCompleteProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint("讀取使用者資料失敗: $e");
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('錯誤'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 底層：相機預覽
          if (_isCameraInitialized && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(child: CircularProgressIndicator()),

          // 上層：固定的 UI 元件
          _buildOverlayUI(),
        ],
      ),
    );
  }

  Widget _buildOverlayUI() {
    final orientation = MediaQuery.of(context).orientation; // 螢幕方向
    final screenWidth = MediaQuery.of(context).size.width; // 螢幕寬度
    final isLandscape = orientation == Orientation.landscape; // 是否為橫向螢幕

    // 將所有覆蓋層 UI 包裹在 SafeArea 中，自動避開動態島和系統 UI
    return SafeArea(
      child: Stack(
        children: [
          // 左上角的返回按鈕 (微調 top 和 left 以貼合 SafeArea)
          Positioned(
            top: 0,
            left: 8,
            child: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // 右下角：懸浮名片 (對齊 SafeArea 右下)
          Positioned(
            bottom: 0,
            right: 0,
            left: isLandscape ? screenWidth * 0.55 : null,
            width: isLandscape ? null : screenWidth * 0.75,
            child: XrBusinessCard(
              profile: _userProfile,
              onAnalyzePressed: _runCompanyAnalysis, // 企業分析
              onRecordPressed: () => _showSnackBar("點擊了對話回顧"), // 對話回顧
              onChatPressed: _fetchDialogSuggestions, // 話題建議
            ),
          ),

          // 名片右上方可展開的功能按鈕
          Positioned(
            bottom: isLandscape ? 170 : 170, // 根據螢幕方向調整按鈕距離底部的高度，使其大致對齊名片頂部
            right: 8,
            child: ExpandingFab(
              actions: [
                FabAction(
                  label: "建立對話錄製",
                  icon: Icons.lightbulb_outline,
                  onPressed: () => _showSnackBar("點擊了建立對話錄製"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
