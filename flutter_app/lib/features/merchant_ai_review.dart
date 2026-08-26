import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/contracts.dart';

class MerchantAiReviewCard extends StatefulWidget {
  const MerchantAiReviewCard({required this.shopId, super.key});

  final String shopId;

  @override
  State<MerchantAiReviewCard> createState() => _MerchantAiReviewCardState();
}

class _MerchantAiReviewCardState extends State<MerchantAiReviewCard> {
  final _api = MarketplaceApiClient();
  late Future<List<_AiReviewItem>> _reviews = _loadReviews();
  String? _busyApprovalId;
  String? _busyToolCallId;
  String? _error;

  Future<List<_AiReviewItem>> _loadReviews() async {
    final approvals = await _api.myAiApprovals(status: '');
    final items = <_AiReviewItem>[];
    for (final approval
        in approvals
            .where(
              (item) => item.status == 'pending' || item.status == 'approved',
            )
            .take(20)) {
      try {
        final calls = await _api.aiRunToolCalls(approval.runId);
        final call = calls.firstWhere(
          (item) => item.toolCallId == approval.toolCallId,
          orElse: () => const AiToolCallSummary(
            toolCallId: '',
            runId: '',
            toolName: '',
            actionClass: '',
            status: 'unknown',
            argumentsHash: '',
            argumentsRedacted: <String, dynamic>{},
            approvalRequired: true,
          ),
        );
        if (call.toolCallId.isNotEmpty) {
          items.add(_AiReviewItem(approval: approval, call: call));
        }
      } on ApiException {
        // Keep the inbox usable when one stale run cannot be loaded.
      }
    }
    return items;
  }

  void _refresh() {
    setState(() {
      _error = null;
      _reviews = _loadReviews();
    });
  }

  Future<void> _decide(AiApprovalSummary approval, String decision) async {
    if (_busyApprovalId != null) return;
    String? reason;
    if (decision == 'rejected') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('رفض الإجراء'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
              hintText: 'اكتب سبباً واضحاً للمراجعة والسجل.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length >= 3) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اعتماد الإجراء'),
          content: const Text(
            'سيتم تسجيل اعتمادك أولاً. لا ينفذ النظام التغيير تلقائياً؛ ستظهر لك خطوة تنفيذ منفصلة بعد الاعتماد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('اعتماد للمراجعة'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _busyApprovalId = approval.approvalId;
      _error = null;
    });
    try {
      await _api.decideAiApproval(
        approvalId: approval.approvalId,
        decision: decision,
        reason: reason,
      );
      if (mounted) _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busyApprovalId = null);
    }
  }

  Future<void> _execute(_AiReviewItem item) async {
    if (_busyToolCallId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تنفيذ الإجراء المعتمد'),
        content: const Text(
          'سيُستدعى إجراء التجارة الحالي مرة واحدة بمفتاح idempotency محفوظ. تأكد من أن المعاينة الحمراء تطابق ما تريد تنفيذه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تنفيذ الآن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busyToolCallId = item.call.toolCallId;
      _error = null;
    });
    try {
      await _api.executeAiAction(
        runId: item.approval.runId,
        toolCallId: item.call.toolCallId,
        approvalId: item.approval.approvalId,
      );
      if (mounted) _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busyToolCallId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<List<_AiReviewItem>>(
        future: _reviews,
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <_AiReviewItem>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFF5ECD8),
                    foregroundColor: Color(0xFF8A5A05),
                    child: Icon(Icons.fact_check_outlined),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مراجعة إجراءات المساعد',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'اعتماد وتنفيذ منفصلان. لا تغيير دون تأكيد التاجر.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : _refresh,
                    tooltip: 'تحديث',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _ReviewWarning(),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 2),
              ] else if (snapshot.hasError) ...[
                const SizedBox(height: 14),
                const Text('تعذر تحميل طلبات المراجعة حالياً. حاول مرة أخرى.'),
              ] else if (reviews.isEmpty) ...[
                const SizedBox(height: 14),
                const Text('لا توجد إجراءات معلقة أو معتمدة تنتظر التنفيذ.'),
              ] else ...[
                const SizedBox(height: 12),
                ...reviews.map(_reviewTile),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFF8A3B12))),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _reviewTile(_AiReviewItem item) {
    final approval = item.approval;
    final call = item.call;
    final busyApproval = _busyApprovalId == approval.approvalId;
    final busyToolCall = _busyToolCallId == call.toolCallId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _actionLabel(call.toolName),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(label: Text(_statusLabel(approval.status))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'رقم التشغيل: ${approval.runId}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'المعاملات المعروضة بعد التنقيح:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SelectableText(
            _pretty(call.argumentsRedacted),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'بصمة المعاملات: ${approval.argumentsHash}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF68655F)),
          ),
          const SizedBox(height: 10),
          if (approval.status == 'pending')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busyApproval
                      ? null
                      : () => _decide(approval, 'approved'),
                  icon: busyApproval
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('اعتماد للمراجعة'),
                ),
                OutlinedButton.icon(
                  onPressed: busyApproval
                      ? null
                      : () => _decide(approval, 'rejected'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('رفض'),
                ),
              ],
            )
          else if (approval.status == 'approved')
            FilledButton.icon(
              onPressed: busyToolCall ? null : () => _execute(item),
              icon: busyToolCall
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('تنفيذ الإجراء المعتمد'),
            ),
        ],
      ),
    );
  }

  String _pretty(Map<String, dynamic> value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  String _actionLabel(String key) => switch (key) {
    'merchant.catalog_bulk_save' => 'تحديث دفعة من الكتالوج',
    'merchant.save_price_list' => 'حفظ قائمة أسعار الجملة',
    'merchant.save_price_list_item' => 'حفظ بند في قائمة الأسعار',
    'merchant.save_promotion' => 'حفظ عرض ترويجي',
    'merchant.inventory_adjustment' => 'تعديل مخزون',
    'merchant.inventory_transfer' => 'نقل مخزون',
    'merchant.inventory_count' => 'اعتماد جرد مخزون',
    'merchant.open_support_ticket' => 'فتح تذكرة دعم',
    _ => 'إجراء تاجر قابل للمراجعة',
  };

  String _statusLabel(String status) => switch (status) {
    'pending' => 'بانتظار اعتمادك',
    'approved' => 'معتمد بانتظار التنفيذ',
    'rejected' => 'مرفوض',
    'expired' => 'منتهي',
    _ => 'حالة غير معروفة',
  };
}

class _AiReviewItem {
  const _AiReviewItem({required this.approval, required this.call});

  final AiApprovalSummary approval;
  final AiToolCallSummary call;
}

class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.lock_outline, size: 19, color: Color(0xFF006A63)),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'هذه الشاشة تعرض معاملات منقحة فقط. لا تشمل الدفع أو إثباتاته، ولا تعتبر أي إثبات دفع مدفوعاً. كل تغيير يمر عبر RPC قائم وسجل تدقيق، ولا يوجد احتفاظ بأموال المنصة.',
          style: TextStyle(color: Color(0xFF006A63), height: 1.45),
        ),
      ),
    ],
  );
}
