import 'package:flutter/material.dart';
import 'package:my_app/services/ai_service.dart';
import 'package:my_app/core/widgets/xr_general_dialog.dart';

class DeveloperTestSection extends StatelessWidget {
  const DeveloperTestSection({super.key});

  // --- 用來呼叫 XR 風格彈窗的輔助函式 ---
  void _showXrDialog(
    BuildContext context,
    String title,
    IconData icon,
    Widget child,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return XrGeneralDialog(title: title, icon: icon, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        _buildSectionTitle(context, '開發測試 (XR Style Preview)'),

        // 測試 1: 企業分析 (帶有假的人脈資料)
        Card(
          child: ListTile(
            leading: const Icon(Icons.science, color: Colors.orange),
            title: const Text('測試 AI 企業分析 (XR UI)'),
            subtitle: const Text('模擬: 天將麒軍 / 工程師 / Flutter'),
            onTap: () async {
              // 1. 準備測試資料
              const testCompany = '天將麒軍股份有限公司';
              // 模擬從 User Profile 撈出來的欄位
              const mockJobTitle = '資深工程師';
              const mockSkill = 'Flutter, Dart, AI Integration';

              // 2. 顯示 Loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在分析 $testCompany...')),
              );

              // 3. 呼叫 AiService
              final result = await AiService().analyzeCompany(testCompany);

              // 4. 顯示結果 (使用 XR 風格)
              if (context.mounted) {
                _showXrDialog(
                  context,
                  testCompany, // 標題
                  Icons.analytics_outlined, // Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 模擬的人脈資料區塊
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const Column(
                          children: [
                            XrInfoRow(
                              icon: Icons.badge,
                              label: '職位',
                              value: mockJobTitle,
                            ),
                            SizedBox(height: 8),
                            XrInfoRow(
                              icon: Icons.stars,
                              label: '擅長',
                              value: mockSkill,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'AI 企業分析報告',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result ?? '無分析結果',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),

        // 測試 2: 話題建議 (XR UI)
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.purple,
            ),
            title: const Text('測試話題建議 (XR UI)'),
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
                final news = await aiService.fetchCompanyNews(
                  testCompany,
                  testJob,
                );
                final companyInfo = await aiService.analyzeCompany(testCompany);
                final suggestions = await aiService.generateSuggestions(
                  testCompany,
                  testJob,
                  companyInfo,
                  news,
                  testLastSummary,
                );

                if (!context.mounted) return;

                // 顯示 XR 風格彈窗
                _showXrDialog(
                  context,
                  '話題建議',
                  Icons.chat_bubble_outline,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '試試看這樣開場：',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 產生建議列表
                      ...suggestions.map(
                        (suggestion) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.amberAccent,
                            ),
                            title: Text(
                              suggestion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                      ),

                      // (選擇性顯示) 用於除錯的新聞來源
                      if (news.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Divider(color: Colors.white.withOpacity(0.1)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            '參考新聞來源:',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        ...news
                            .take(2)
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $n',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
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
