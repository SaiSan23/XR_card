import 'package:flutter/material.dart';
import 'package:my_app/services/ai_service.dart';

class DeveloperTestSection extends StatelessWidget {
  const DeveloperTestSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        _buildSectionTitle(context, '開發測試'),

        // 測試 1: 企業分析
        Card(
          child: ListTile(
            leading: const Icon(Icons.science, color: Colors.orange),
            title: const Text('測試 AI 企業分析'),
            onTap: () async {
              // 1. 準備測試資料
              const testCompany = '天將麒軍股份有限公司';
              const testJob =
                  '工程師'; // 雖然 analyzeCompany 目前只用 companyName，但保留參數以備未來擴充

              // 2. 顯示 Loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在分析 $testCompany...')),
              );

              // 3. 呼叫 AiService
              final result = await AiService().analyzeCompany(testCompany);

              // 4. 顯示結果
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('分析結果'),
                    content: SingleChildScrollView(
                      child: Text(result ?? '無結果'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),

        // 測試 2: 話題建議
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.purple,
            ),
            title: const Text('測試話題建議 (含新聞搜尋)'),
            subtitle: const Text('模擬情境：NVIDIA / AI 架構師'),
            onTap: () async {
              // 1. 準備模擬資料
              const testCompany = 'NVIDIA';
              const testJob = 'AI 架構師';
              const testLastSummary = '上次聊到關於 Edge AI 在醫療器材上的延遲問題，他似乎很感興趣。';

              // 2. 顯示 Loading
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('正在搜尋新聞並生成建議...')));

              try {
                final aiService = AiService();

                // 步驟 A: 抓新聞
                final news = await aiService.fetchCompanyNews(
                  testCompany,
                  testJob,
                );
                debugPrint('抓到的新聞數量: ${news.length}');

                // 步驟 B: 抓企業分析
                final companyInfo = await aiService.analyzeCompany(testCompany);

                // 步驟 C: 綜合所有資訊生成建議
                final suggestions = await aiService.generateSuggestions(
                  testCompany,
                  testJob,
                  companyInfo,
                  news,
                  testLastSummary,
                );

                // 3. 顯示結果 Dialog
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('話題建議結果'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '【搜尋到的新聞摘要】',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          if (news.isEmpty)
                            const Text(
                              '無 (請檢查搜尋功能)',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            )
                          else
                            ...news.map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $n',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          const Divider(height: 24),

                          const Text(
                            '【AI 生成開場白】',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...suggestions.map(
                            (s) => Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(s),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                debugPrint('測試失敗: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
                }
              }
            },
          ),
        ),
      ],
    );
  }

  // 將原本 SettingPage 的 private method 複製一份進來，保持模組獨立
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
