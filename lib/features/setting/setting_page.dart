import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/core/theme/app_colors.dart';
import 'package:my_app/features/xr_simulator/xr_simulator_page.dart';
// import 'package:my_app/features/setting/developer_test_section.dart'; // 開發設計按鈕

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isResetting = false; // 用於管理重置功能的讀取狀態
  bool _isPrivacyMode = true; // 用於管理隱私設定的狀態

  // 導航到 XR 模擬器頁面的方法
  void _navigateToXrSimulator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const XrSimulatorPage()),
    );
  }

  // 重置 Demo 的處理函數
  Future<void> _resetDemo() async {
    if (_isResetting) return; // 防止重複點擊

    setState(() => _isResetting = true); // 開始重置，顯示讀取狀態

    try {
      // 直接在這裡執行 Supabase 刪除操作
      await Supabase.instance.client
          .from('contacts') // 根據您的 SQL 檔，表名是 'contacts'
          .delete()
          .or(
            'and(requester_id.eq.1,friend_id.eq.2),and(requester_id.eq.2,friend_id.eq.1)',
          );

      if (!mounted) return; // 檢查 Widget 是否還存在
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Reset Demo 成功'),
      //     backgroundColor: Colors.green,
      //   ),
      // );
    } catch (e) {
      if (!mounted) return; // 檢查 Widget 是否還存在
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset Demo 失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false); // 結束重置
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Setting',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.primary,
            child: SizedBox(height: 3),
          ),
        ),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, '實驗性功能'),

          // 開啟模擬功能的選項
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '開啟模擬功能',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _isPrivacyMode ? Colors.black : Colors.grey,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      // 禁用時的背景色與前景色會由 Flutter 自動處理，通常是灰色
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // 根據隱私模式狀態決定按鈕是否可按
                    onPressed: _isPrivacyMode
                        ? () => _navigateToXrSimulator(context)
                        : null,
                    child: const Text('啟動'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionTitle(context, '隱私管理'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0, // 稍微調整垂直間距讓 Switch 看起來置中舒服
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '開啟交流模式',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),

                  Switch(
                    value: _isPrivacyMode,
                    activeColor: AppColors.primary, // 開啟時的顏色 (深綠色)
                    onChanged: (value) {
                      setState(() {
                        _isPrivacyMode = value;
                      });
                      // TODO:
                      debugPrint('隱私模式已切換為: $_isPrivacyMode');
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionTitle(context, '帳號設定'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('帳號設定'),
              trailing: _isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isResetting ? null : _resetDemo,
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionTitle(context, '其他設定'),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              title: Text('通知設定'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),

          // Sai: 測試[企業分析、對話建議]功能
          // const DeveloperTestSection(),
        ],
      ),
    );
  }

  // 抽出一個建立區塊標題的 widget
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
