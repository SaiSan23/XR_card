import 'package:flutter/material.dart';

class XrGeneralDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onClose;

  const XrGeneralDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // 取得螢幕尺寸以計算彈窗大小
    final size = MediaQuery.of(context).size;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          // 設定寬度與最大高度
          width: size.width * 0.85,
          constraints: BoxConstraints(maxHeight: size.height * 0.7),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // 1. 半透明深色背景 (科技黑)
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            // 2. 發光邊框 (Cyan 青色)
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              // 3. 外部光暈效果
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 通用標題列 ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.cyanAccent.withOpacity(0.3), height: 1),
              const SizedBox(height: 16),

              // --- 內容區 (自動滾動) ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --- 小工具：XR 風格的資訊列 (Label: Value) ---
/// 可供各個頁面共用，顯示像是「職稱：工程師」這樣的資訊
class XrInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const XrInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          '$label：',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
