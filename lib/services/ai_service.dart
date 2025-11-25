import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_app/services/google_search_service.dart';

class AiService {
  // --- IMPORTANT ---
  // 為了安全起見，API 金鑰不應直接寫在程式碼中。
  // 請將 'Sai_GEMINI_API_KEY' 替換成您自己的 Gemini API 金鑰。
  static final String? _apiKey = dotenv.env['Sai_GEMINI_API_KEY'];

  GenerativeModel? _model;
  final GoogleSearchService _googleSearchService = GoogleSearchService();

  AiService() {
    _initialize();
  }

  void _initialize() {
    if (_apiKey == null) {
      debugPrint('請在 AiService 中設定您的 Gemini API 金鑰！');
      return;
    }
    // 選用模型：
    // 1. gemini-2.5-flash
    // 2. gemini-2.5-pro
    // flash: 10 次/分鐘, pro: 2 次/分鐘
    _model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: _apiKey!);
  }

  /// 針對指定公司名稱進行企業分析
  ///
  /// 流程：
  /// 1. 使用 Google Search 搜尋該公司的新聞與介紹
  /// 2. 將搜尋結果餵給 Gemini
  /// 3. 依照限制格式 (兩段式，字數限制) 產出報告
  Future<String?> analyzeCompany(String companyName) async {
    if (_model == null) {
      debugPrint('Gemini 模型尚未初始化，請檢查 API 金鑰。');
      return '模型尚未初始化。';
    }

    // 檢查公司名稱是否為空
    if (companyName.trim().isEmpty) {
      return '公司名稱為空，無法分析。';
    }

    try {
      // 步驟 1: 先透過 Google Search 獲取外部資訊
      // 搜尋關鍵字包含：公司名稱、介紹、新聞、近況
      final queries = ['$companyName 介紹 主要業務', '$companyName 最近新聞 重大事件'];

      final searchResults = await _googleSearchService.search(queries);

      // 將搜尋結果轉換為文字 Context
      String searchContext = '';
      if (searchResults.isNotEmpty) {
        searchContext = searchResults
            .map((r) => '- 標題: ${r['title']}\n  摘要: ${r['snippet']}')
            .join('\n');
      } else {
        searchContext = '查無具體網路搜尋結果，請依據您的知識庫回答。';
      }

      // 步驟 2: 建立更詳盡、專業的 Prompt
      final prompt =
          '''
      你是一位專業的商業分析師。請根據以下關於「$companyName」的網路搜尋結果與您的知識庫，撰寫一份精簡的企業分析報告。

      === 參考資訊 (搜尋結果) ===
      $searchContext
      ==========================

      請嚴格遵守以下 **格式** 與 **字數限制** (繁體中文)：

      **第一段 (公司介紹)：**
      - 內容：說明該公司屬於何種產業、主要經營業務或產品。
      - 限制：**嚴格控制在 75 字以內**。

      **第二段 (近況與時事)：**
      - 內容：描述該公司近期發生的重大時事、改革、新聞或市場動態。若參考資訊中無具體新聞，請簡述其目前的市場地位或挑戰。
      - 限制：**嚴格控制在 125 字以內**。

      **總字數限制：**
      - 整體回答請勿超過 200 字。
      - 請直接輸出這兩段內容，中間用換行分隔，不需要加入標題 (如 "第一段：" 或 "分析報告：")。
      ''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text?.trim();
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini API 呼叫失敗: $e');
      // 回傳錯誤訊息，讓 UI 層可以判斷是否要重試
      return e.message;
    } catch (e) {
      debugPrint('企業分析流程失敗: $e');
      return '分析失敗，請查看終端機錯誤訊息。';
    }
  }

  /// 整合企業細節、時事新聞和上次對話摘要，產出開放性話題
  /// 根據多方資訊生成「開場白」(供「話題建議」按鈕使用)
  Future<List<String>> generateSuggestions(
    String? companyName,
    String? jobTitle,
    String? companyInfo,
    List<String> newsSnippets,
    String? lastSummary,
  ) async {
    if (_model == null) return ['AI 模型未初始化'];

    String prompt =
        '''
    您是一位專業的商務社交助理。請根據以下關於「${companyName ?? '這位專業人士'}」的背景資訊，
    為我生成 3 個簡短且自然的、適合用來開啟對話的「開放性問題」或「開場白」。
    我希望這些問題能引導對方分享更多資訊，而不是簡單的「是/否」回答。

    背景資訊：
    1.  **企業細節分析** (您對他們公司的了解)：
        ${companyInfo ?? "無"}
    2.  **對方職業/職稱**：
        ${jobTitle ?? "無"}
    3.  **相關時事/新聞摘要** (最近的產業動態)：
        ${newsSnippets.isNotEmpty ? newsSnippets.join("； ") : "無"}
    4.  **上次對話回顧** (上次聊到的重點)：
        ${lastSummary ?? "無"}

    請針對上述資訊，盡可能生成 3 個相關的開場白 (例如，一個關於公司、一個關於職業、一個關於時事)，
    每個開場白的字數約為 20-30 字。
    如果某個面向的資訊不足，您可以生成一個較通用的問題，或專注於有資訊的面向。

    範例：
    - (基於企業細節) "我了解到貴公司在教育領域耕耘，可以多分享一些你們具體的服務模式嗎？"
    - (基於職業) "您作為「${jobTitle ?? '專業人士'}」，最近在[相關領域]上是否有觀察到什麼特別的趨勢？"
    - (基於時事) "最近看到關於[某某]的新聞，這對你們的產業是否有帶來什麼新的挑戰或機遇？"
    - (基於對話回顧) "上次我們聊到[某某]專案，不曉得後續的進展還順利嗎？"

    請直接回傳 3 個以換行符號分隔的建議問題 (不需要包含 '1.' 或 '- ' 這樣的前綴)。
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      // 清理 AI 回應
      return response.text
              ?.split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .map((s) => s.replaceAll(RegExp(r'^[0-9\.\-\*•]\s*'), ''))
              .where((s) => s.isNotEmpty)
              .toList() ??
          ['請問您最近關注哪些產業動態嗎？'];
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini API 呼叫失敗 (generateSuggestions): $e');
      if (e.message.contains('UNAVAILABLE')) {
        return ['模型目前忙碌中，請稍後再試'];
      }
      return ['生成建議時發生錯誤'];
    } catch (e) {
      debugPrint('Gemini API 呼叫失敗 (generateSuggestions): $e');
      return ['生成建議時發生錯誤，請查看終端機'];
    }
  }

  /// 獲取公司相關新聞與時事
  ///
  /// 封裝了關鍵字組合與 Google Search 的呼叫邏輯，
  /// 讓 UI 端不需要處理資料格式轉換。
  Future<List<String>> fetchCompanyNews(
    String companyName,
    String? jobTitle,
  ) async {
    // 檢查參數
    if (companyName.trim().isEmpty) {
      return [];
    }

    List<String> snippets = [];
    try {
      // 1. 建立動態的搜尋查詢列表
      // 這裡可以統一管理搜尋策略，例如加上 "台灣" 或 "2025" 等關鍵字
      List<String> queries = ['"$companyName" 產業動態', '"$companyName" 最近新聞'];

      // 如果有職稱，加入職稱相關的搜尋
      if (jobTitle != null && jobTitle.isNotEmpty) {
        queries.add('$jobTitle 產業趨勢');
        queries.add('$jobTitle 最新消息');
      }

      // 2. 呼叫內部的 Google Search Service
      // (假設您已依照上一個步驟，在 AiService 內宣告了 final GoogleSearchService _googleSearchService = GoogleSearchService();)
      final searchResults = await _googleSearchService.search(queries);

      // 3. 解析與過濾結果
      if (searchResults.isNotEmpty) {
        for (var item in searchResults) {
          String title = item['title'] ?? '';
          String snippet = item['snippet'] ?? '';

          // 移除多餘空白與換行
          title = title.trim().replaceAll(RegExp(r'\s+'), ' ');
          snippet = snippet.trim().replaceAll(RegExp(r'\s+'), ' ');

          String combined = title.isNotEmpty ? "$title：$snippet" : snippet;

          if (combined.isNotEmpty) {
            // 限制長度，避免 token 過多
            if (combined.length > 100) {
              combined = '${combined.substring(0, 100)}...';
            }
            snippets.add(combined);
          }
        }
      }
    } catch (e) {
      debugPrint("AiService: 獲取新聞失敗: $e");
      // 發生錯誤時回傳空陣列，不讓整個流程崩潰
      return [];
    }

    return snippets;
  }
}
