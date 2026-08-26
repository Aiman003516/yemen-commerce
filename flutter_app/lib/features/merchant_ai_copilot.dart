import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/contracts.dart';

class MerchantAiCopilotCard extends StatefulWidget {
  const MerchantAiCopilotCard({required this.shopId, super.key});

  final String shopId;

  @override
  State<MerchantAiCopilotCard> createState() => _MerchantAiCopilotCardState();
}

class _MerchantAiCopilotCardState extends State<MerchantAiCopilotCard> {
  final _prompt = TextEditingController();
  final _api = MarketplaceApiClient();
  String _mode = 'read';
  String _intent = 'general';
  AiRunResponse? _response;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final input = _prompt.text.trim();
    if (input.length < 3 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final response = await _api.runMerchantAi(
        shopId: widget.shopId,
        input: input,
        intentKey: _intent,
        mode: _mode,
        idempotencyKey: 'merchant-ai-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) setState(() => _response = response);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE2F2EC),
                foregroundColor: Color(0xFF006A63),
                child: Icon(Icons.auto_awesome_outlined),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _CopilotHeader()),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'نوع المساعدة'),
            items: const [
              DropdownMenuItem(
                value: 'read',
                child: Text('قراءة وتحليل بيانات المتجر'),
              ),
              DropdownMenuItem(
                value: 'draft',
                child: Text('مسودة للمراجعة فقط'),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) => setState(() => _mode = value ?? 'read'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _intent,
            decoration: const InputDecoration(labelText: 'الغرض'),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('عام')),
              DropdownMenuItem(
                value: 'merchant.dashboard_summary',
                child: Text('ملخص أداء المتجر'),
              ),
              DropdownMenuItem(
                value: 'merchant.product_copy',
                child: Text('وصف منتج'),
              ),
              DropdownMenuItem(
                value: 'merchant.seo_copy',
                child: Text('عنوان ووصف بحثي'),
              ),
              DropdownMenuItem(
                value: 'merchant.catalog_quality',
                child: Text('جودة الكتالوج'),
              ),
              DropdownMenuItem(
                value: 'merchant.reorder_explanation',
                child: Text('تفسير احتياج إعادة التوريد'),
              ),
              DropdownMenuItem(
                value: 'merchant.promotion_draft',
                child: Text('مسودة نص عرض'),
              ),
              DropdownMenuItem(
                value: 'merchant.quote_draft',
                child: Text('مسودة ملاحظة عرض سعر'),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) => setState(() => _intent = value ?? 'general'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 5,
            maxLength: 2_000,
            decoration: const InputDecoration(
              labelText: 'كيف أساعدك؟',
              hintText: 'مثال: لخّص أداء هذا المتجر خلال آخر فترة متاحة.',
              alignLabelWithHint: true,
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'يستخدم المساعد بيانات متجرك المسموح بها فقط. المسودات لا تُحفظ ولا تُنشر تلقائياً.',
                  style: TextStyle(color: Color(0xFF68655F), height: 1.45),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _run,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_loading ? 'جارٍ التحليل' : 'تشغيل'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _CopilotNotice(
              icon: Icons.info_outline,
              text: _error!,
              color: Color(0xFF8A3B12),
            ),
          ],
          if (_response != null) ...[
            const SizedBox(height: 14),
            _CopilotResult(response: _response!),
          ],
        ],
      ),
    ),
  );
}

class _CopilotHeader extends StatelessWidget {
  const _CopilotHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'مساعد التاجر',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      SizedBox(height: 4),
      Text('قراءة آمنة ومسودات عربية للمراجعة قبل أي تغيير.'),
    ],
  );
}

class _CopilotResult extends StatelessWidget {
  const _CopilotResult({required this.response});

  final AiRunResponse response;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD7E8DE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          response.answer.isEmpty ? 'نتيجة المساعد' : response.answer,
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.55),
        ),
        if (response.drafts.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'مسودات تحتاج مراجعتك',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          ...response.drafts.map(
            (draft) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(draft.title),
              subtitle: Text(draft.content),
              isThreeLine: true,
            ),
          ),
          const _CopilotNotice(
            icon: Icons.lock_outline,
            text: 'لم يتم حفظ أو نشر أي مسودة. راجعها ثم استخدم أدوات المتجر الحالية عند اعتمادك لها.',
            color: Color(0xFF006A63),
          ),
        ],
      ],
    ),
  );
}

class _CopilotNotice extends StatelessWidget {
  const _CopilotNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: TextStyle(color: color, height: 1.45)),
      ),
    ],
  );
}
