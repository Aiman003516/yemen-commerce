import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/contracts.dart';
import '../core/merchant_operational_policy.dart';

class MerchantOperationalActionsDialog extends StatefulWidget {
  const MerchantOperationalActionsDialog({
    required this.order,
    this.onChanged,
    super.key,
  });

  final MerchantOrderWorkbenchEntry order;
  final VoidCallback? onChanged;

  @override
  State<MerchantOperationalActionsDialog> createState() =>
      _MerchantOperationalActionsDialogState();
}

class _MerchantOperationalActionsDialogState
    extends State<MerchantOperationalActionsDialog> {
  final _api = MarketplaceApiClient();
  late Future<_OperationalSnapshot> _snapshot = _load();
  bool _busy = false;

  Future<_OperationalSnapshot> _load() async {
    final results = await Future.wait<Object?>([
      _api.merchantShipmentPlanForOrder(widget.order.id),
      _api.merchantOrderCases(widget.order.id),
    ]);
    final shipment = results[0] as Map<String, dynamic>?;
    final cases = (results[1] as List<Map<String, dynamic>>);
    final exceptions = shipment == null
        ? const <Map<String, dynamic>>[]
        : await _api.merchantDeliveryExceptions(shipment['id'].toString());
    Map<String, dynamic>? returnLogistics;
    final eligibleReturnCase = cases.cast<Map<String, dynamic>?>().firstWhere(
      (item) =>
          item?['case_type'] == 'return' &&
          const {'approved', 'resolved'}.contains(item?['status']),
      orElse: () => null,
    );
    if (eligibleReturnCase != null) {
      returnLogistics = await _api.merchantReturnLogisticsForCase(
        eligibleReturnCase['id'].toString(),
      );
    }
    return _OperationalSnapshot(
      shipment: shipment,
      cases: cases,
      exceptions: exceptions,
      returnCase: eligibleReturnCase,
      returnLogistics: returnLogistics,
    );
  }

  void _refresh() {
    setState(() => _snapshot = _load());
    widget.onChanged?.call();
  }

  String _key(String operation) =>
      'edge3-$operation-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال العملية وتحديث السجل من الخادم.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنفيذ العملية. لم يتغير السجل.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createShipment() async {
    if (widget.order.paymentStatus != 'paid') return;
    final form = await _showForm(
      title: 'إنشاء خطة توصيل',
      fields: const [
        _FormFieldSpec('carrier', 'طريقة التوصيل', 'merchant_arranged'),
        _FormFieldSpec('service', 'مستوى الخدمة (اختياري)', ''),
        _FormFieldSpec('reason', 'السبب (مطلوب)', ''),
      ],
      submitLabel: 'إنشاء للمراجعة',
    );
    if (form == null || form['reason']!.trim().length < 5) return;
    if (!await _confirmAction(
      title: 'تأكيد إنشاء خطة التوصيل',
      details: 'سيتم إنشاء خطة لهذا الطلب بعد تأكيد الدفع. لن تتغير حالة الدفع أو أي مبلغ.',
    )) {
      return;
    }
    await _run(
      () => _api.createShipmentPlan(
        merchantOrderId: widget.order.id,
        carrierKey: form['carrier']!.trim().isEmpty
            ? 'merchant_arranged'
            : form['carrier']!.trim(),
        serviceLevel: form['service']!.trim().isEmpty
            ? null
            : form['service']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('shipment-plan'),
      ),
    );
  }

  Future<void> _recordShipmentStatus(Map<String, dynamic> shipment) async {
    final current = shipment['status']?.toString() ?? 'planned';
    final nextStatuses = MerchantOperationalPolicy.nextShipmentStatuses(
      current,
    );
    if (nextStatuses.isEmpty) return;
    final form = await _showForm(
      title: 'تحديث حالة التوصيل',
      fields: [
        _FormFieldSpec('status', 'الحالة التالية', nextStatuses.first),
        const _FormFieldSpec('message', 'رسالة للعميل (اختياري)', ''),
        const _FormFieldSpec('reason', 'السبب (مطلوب)', ''),
      ],
      selectOptions: {'status': nextStatuses},
      submitLabel: 'حفظ الحالة',
    );
    if (form == null || form['reason']!.trim().length < 5) return;
    if (!await _confirmAction(
      title: 'تأكيد تحديث حالة التوصيل',
      details: 'سيتم إرسال الحالة المحددة إلى الخادم بعد تطبيق بوابة الدفع وسجل التدقيق.',
    )) {
      return;
    }
    await _run(
      () => _api.recordShipmentEvent(
        shipmentPlanId: shipment['id'].toString(),
        status: form['status']!.trim(),
        customerMessage: form['message']!.trim().isEmpty
            ? null
            : form['message']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('shipment-status'),
      ),
    );
  }

  Future<void> _openException(Map<String, dynamic> shipment) async {
    final form = await _showForm(
      title: 'تسجيل استثناء توصيل',
      fields: const [
        _FormFieldSpec('code', 'رمز الاستثناء', 'address_unreachable'),
        _FormFieldSpec('severity', 'الأهمية', 'medium'),
        _FormFieldSpec('message', 'رسالة واضحة للعميل', ''),
        _FormFieldSpec('reason', 'السبب (مطلوب)', ''),
      ],
      selectOptions: const {
        'severity': ['low', 'medium', 'high', 'critical'],
      },
      submitLabel: 'تسجيل الاستثناء',
    );
    if (form == null ||
        form['message']!.trim().length < 3 ||
        form['reason']!.trim().length < 5) {
      return;
    }
    if (!await _confirmAction(
      title: 'تأكيد تسجيل استثناء التوصيل',
      details: 'سيظهر الاستثناء للتاجر والعميل برسالة واضحة. لا ينشئ ذلك استرداداً مالياً.',
    )) {
      return;
    }
    await _run(
      () => _api.openDeliveryException(
        shipmentPlanId: shipment['id'].toString(),
        code: form['code']!.trim(),
        severity: form['severity']!.trim(),
        customerMessage: form['message']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('delivery-exception'),
      ),
    );
  }

  Future<void> _resolveException(Map<String, dynamic> exception) async {
    final form = await _showForm(
      title: 'معالجة استثناء التوصيل',
      fields: const [
        _FormFieldSpec('status', 'الحالة التالية', 'resolved'),
        _FormFieldSpec('reason', 'سبب المعالجة (مطلوب)', ''),
      ],
      selectOptions: const {
        'status': ['acknowledged', 'resolved', 'cancelled'],
      },
      submitLabel: 'حفظ المعالجة',
    );
    if (form == null || form['reason']!.trim().length < 5) return;
    if (!await _confirmAction(
      title: 'تأكيد معالجة الاستثناء',
      details: 'سيتم تسجيل حالة المعالجة وسببها في السجل غير القابل للتعديل.',
    )) {
      return;
    }
    await _run(
      () => _api.resolveDeliveryException(
        exceptionId: exception['id'].toString(),
        status: form['status']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('exception-resolution'),
      ),
    );
  }

  Future<void> _startReturn(_OperationalSnapshot snapshot) async {
    final returnCase = snapshot.returnCase;
    if (returnCase == null) return;
    final form = await _showForm(
      title: 'بدء لوجستيات المرتجع',
      fields: const [
        _FormFieldSpec('method', 'طريقة المرتجع', 'seller_arranged'),
        _FormFieldSpec('message', 'رسالة للعميل (اختياري)', ''),
        _FormFieldSpec('reason', 'السبب (مطلوب)', ''),
      ],
      selectOptions: const {
        'method': ['dropoff', 'pickup', 'seller_arranged'],
      },
      submitLabel: 'بدء المتابعة',
    );
    if (form == null || form['reason']!.trim().length < 5) return;
    if (!await _confirmAction(
      title: 'تأكيد بدء لوجستيات المرتجع',
      details: 'سيبدأ تتبع المرتجع للحالة المؤهلة فقط. لن يتم إنشاء استرداد أو تسوية مالية.',
    )) {
      return;
    }
    await _run(
      () => _api.startReturnLogistics(
        orderCaseId: returnCase['id'].toString(),
        method: form['method']!.trim(),
        customerMessage: form['message']!.trim().isEmpty
            ? null
            : form['message']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('return-start'),
      ),
    );
  }

  Future<void> _recordReturn(Map<String, dynamic> returnLogistics) async {
    final current = returnLogistics['status']?.toString() ?? 'requested';
    final nextStatuses = MerchantOperationalPolicy.nextReturnStatuses(current);
    if (nextStatuses.isEmpty) return;
    final form = await _showForm(
      title: 'تحديث حالة المرتجع',
      fields: [
        _FormFieldSpec('status', 'الحالة التالية', nextStatuses.first),
        const _FormFieldSpec('message', 'رسالة للعميل (اختياري)', ''),
        const _FormFieldSpec('reason', 'السبب (مطلوب)', ''),
      ],
      selectOptions: {'status': nextStatuses},
      submitLabel: 'حفظ الحالة',
    );
    if (form == null || form['reason']!.trim().length < 5) return;
    if (!await _confirmAction(
      title: 'تأكيد تحديث حالة المرتجع',
      details:
          'سيتم إضافة حدث لوجستي للمرتجع. لا تنفذ هذه الشاشة أي استرداد مالي.',
    )) {
      return;
    }
    await _run(
      () => _api.recordReturnEvent(
        returnLogisticsId: returnLogistics['id'].toString(),
        status: form['status']!.trim(),
        customerMessage: form['message']!.trim().isEmpty
            ? null
            : form['message']!.trim(),
        reason: form['reason']!.trim(),
        idempotencyKey: _key('return-status'),
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String details,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('مراجعة مرة أخرى'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد وإرسال'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<Map<String, String>?> _showForm({
    required String title,
    required List<_FormFieldSpec> fields,
    required String submitLabel,
    Map<String, List<String>> selectOptions = const {},
  }) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field.key: TextEditingController(text: field.initialValue),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        var selected = <String, String>{
          for (final field in fields) field.key: field.initialValue,
        };
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    if (selectOptions.containsKey(field.key))
                      DropdownButtonFormField<String>(
                        initialValue: selected[field.key],
                        decoration: InputDecoration(labelText: field.label),
                        items: selectOptions[field.key]!
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_label(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(
                          () =>
                              selected[field.key] = value ?? field.initialValue,
                        ),
                      )
                    else
                      TextField(
                        controller: controllers[field.key],
                        minLines:
                            field.key == 'reason' || field.key == 'message'
                            ? 2
                            : 1,
                        maxLines:
                            field.key == 'reason' || field.key == 'message'
                            ? 3
                            : 1,
                        decoration: InputDecoration(labelText: field.label),
                      ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final values = <String, String>{
                    for (final field in fields)
                      field.key: selectOptions.containsKey(field.key)
                          ? selected[field.key] ?? ''
                          : controllers[field.key]!.text,
                  };
                  Navigator.pop(dialogContext, values);
                },
                child: Text(submitLabel),
              ),
            ],
          ),
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('عمليات التوصيل والمرتجعات · ${widget.order.orderReference}'),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<_OperationalSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Text(
              'تعذر تحميل السجلات التشغيلية. لم يتم تنفيذ أي تغيير.',
            );
          }
          final data = snapshot.data!;
          final shipment = data.shipment;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الدفع: ${_label(widget.order.paymentStatus)}'),
                const SizedBox(height: 4),
                if (widget.order.paymentStatus != 'paid')
                  const Text(
                    'لا يمكن الانتقال إلى التوصيل أو التسليم قبل تأكيد الدفع من التاجر. إثبات الدفع لا يكفي، ولا يتغير الدفع من هذه الشاشة.',
                  ),
                const Divider(height: 24),
                Text(
                  shipment == null
                      ? 'لا توجد خطة توصيل لهذا الطلب.'
                      : 'خطة التوصيل: ${_label(shipment['status']?.toString() ?? '')} · ${shipment['carrier_key'] ?? 'بدون مزود'}',
                ),
                const SizedBox(height: 8),
                if (shipment == null)
                  FilledButton.icon(
                    onPressed:
                        _busy ||
                            !MerchantOperationalPolicy.canCreateShipment(
                              widget.order.paymentStatus,
                            )
                        ? null
                        : _createShipment,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('إنشاء خطة توصيل'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _recordShipmentStatus(shipment),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('تحديث حالة التوصيل'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _openException(shipment),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('تسجيل استثناء توصيل'),
                  ),
                  ...data.exceptions.map(
                    (exception) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${exception['code']} · ${_label(exception['severity']?.toString() ?? '')}',
                      ),
                      subtitle: Text(
                        _label(exception['status']?.toString() ?? ''),
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap:
                          _busy ||
                              const {
                                'resolved',
                                'cancelled',
                              }.contains(exception['status'])
                          ? null
                          : () => _resolveException(exception),
                    ),
                  ),
                ],
                const Divider(height: 24),
                Text(
                  data.returnLogistics == null
                      ? data.returnCase == null
                            ? 'لا توجد حالة مرتجع معتمدة أو محلولة لهذا الطلب.'
                            : 'توجد حالة مرتجع مؤهلة للمتابعة.'
                      : 'لوجستيات المرتجع: ${_label(data.returnLogistics!['status']?.toString() ?? '')}',
                ),
                const SizedBox(height: 8),
                if (data.returnLogistics == null && data.returnCase != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _startReturn(data),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('بدء لوجستيات المرتجع'),
                  )
                else if (data.returnLogistics != null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _recordReturn(data.returnLogistics!),
                    icon: const Icon(Icons.update),
                    label: const Text('تحديث حالة المرتجع'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'هذه الشاشة لا تنشئ استرداداً أو تسوية مالية ولا تحرك أموالاً. كل تغيير يتطلب سبباً ومفتاح إعادة محاولة ويعاد تحميله من الخادم.',
                ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
}

class _OperationalSnapshot {
  const _OperationalSnapshot({
    required this.shipment,
    required this.cases,
    required this.exceptions,
    required this.returnCase,
    required this.returnLogistics,
  });

  final Map<String, dynamic>? shipment;
  final List<Map<String, dynamic>> cases;
  final List<Map<String, dynamic>> exceptions;
  final Map<String, dynamic>? returnCase;
  final Map<String, dynamic>? returnLogistics;
}

class _FormFieldSpec {
  const _FormFieldSpec(this.key, this.label, this.initialValue);

  final String key;
  final String label;
  final String initialValue;
}

String _label(String value) =>
    <String, String>{
      'paid': 'مدفوع مؤكّد',
      'awaiting_payment': 'بانتظار الدفع',
      'payment_under_review': 'الدفع قيد المراجعة',
      'planned': 'مخطط',
      'ready': 'جاهز',
      'dispatched': 'تم الإرسال',
      'in_transit': 'في الطريق',
      'delivered': 'تم التسليم',
      'failed': 'فشل',
      'cancelled': 'ملغى',
      'open': 'مفتوح',
      'acknowledged': 'تم الاطلاع',
      'resolved': 'تمت المعالجة',
      'requested': 'مطلوب',
      'label_pending': 'بانتظار الملصق',
      'awaiting_handoff': 'بانتظار التسليم',
      'received': 'تم الاستلام',
      'inspected': 'تم الفحص',
      'closed': 'مغلق',
      'low': 'منخفض',
      'medium': 'متوسط',
      'high': 'مرتفع',
      'critical': 'حرج',
    }[value] ??
    value;
