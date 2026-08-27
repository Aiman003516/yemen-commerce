import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/contracts.dart';

class CustomerDeliveryTimelineDialog extends StatefulWidget {
  const CustomerDeliveryTimelineDialog({required this.order, super.key});

  final MerchantOrderSummary order;

  @override
  State<CustomerDeliveryTimelineDialog> createState() =>
      _CustomerDeliveryTimelineDialogState();
}

class _CustomerDeliveryTimelineDialogState
    extends State<CustomerDeliveryTimelineDialog> {
  late Future<_CustomerTimelineSnapshot> _timeline = _load();

  Future<_CustomerTimelineSnapshot> _load() async {
    final api = MarketplaceApiClient();
    final results = await Future.wait<Object?>([
      api.customerShipmentPlanForOrder(widget.order.id),
      api.customerOrderCases(widget.order.id),
    ]);
    final shipment = results[0] as Map<String, dynamic>?;
    final cases = results[1] as List<Map<String, dynamic>>;
    final shipmentEvents = shipment == null
        ? const <Map<String, dynamic>>[]
        : await api.customerShipmentEvents(shipment['id'].toString());
    final returnCase = cases.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['case_type'] == 'return',
      orElse: () => null,
    );
    Map<String, dynamic>? returnLogistics;
    List<Map<String, dynamic>> returnEvents = const [];
    if (returnCase != null) {
      returnLogistics = await api.customerReturnLogisticsForCase(
        returnCase['id'].toString(),
      );
      if (returnLogistics != null) {
        returnEvents = await api.customerReturnEvents(
          returnLogistics['id'].toString(),
        );
      }
    }
    return _CustomerTimelineSnapshot(
      shipment: shipment,
      shipmentEvents: shipmentEvents,
      returnCase: returnCase,
      returnLogistics: returnLogistics,
      returnEvents: returnEvents,
    );
  }

  void _reload() => setState(() => _timeline = _load());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'متابعة الطلب ${widget.order.orderReference ?? widget.order.id}',
    ),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<_CustomerTimelineSnapshot>(
        future: _timeline,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Text(
              'تعذر تحميل متابعة الطلب. تحقق من الاتصال ثم حاول مرة أخرى. لم يتم تنفيذ أي تغيير.',
            );
          }
          final data = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الدفع: ${_customerLabel(widget.order.paymentStatus)}'),
                Text(
                  'التنفيذ: ${_customerLabel(widget.order.fulfilmentStatus)}',
                ),
                const SizedBox(height: 6),
                const Text(
                  'إثبات الدفع أو رسالة العميل لا تعني تأكيد الدفع. تأكيد الدفع يتم يدوياً من المتجر.',
                ),
                const Divider(height: 24),
                const Text(
                  'التوصيل',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (data.shipment == null)
                  const Text(
                    'لم ينشئ المتجر خطة توصيل بعد. سيظهر التحديث هنا عندما تصبح الخطة متاحة.',
                  )
                else ...[
                  Text(
                    'الحالة: ${_customerLabel(data.shipment!['status']?.toString() ?? '')}',
                  ),
                  if ((data.shipment!['customer_message']?.toString() ?? '')
                      .isNotEmpty)
                    Text('رسالة المتجر: ${data.shipment!['customer_message']}'),
                  const SizedBox(height: 8),
                  if (data.shipmentEvents.isEmpty)
                    const Text('لا توجد أحداث توصيل بعد.')
                  else
                    ...data.shipmentEvents.map(
                      (event) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.circle, size: 10),
                        title: Text(
                          _customerLabel(event['status']?.toString() ?? ''),
                        ),
                        subtitle: Text(
                          event['customer_message']?.toString() ?? '',
                        ),
                      ),
                    ),
                ],
                const Divider(height: 24),
                const Text(
                  'المرتجع',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (data.returnCase == null)
                  const Text('لا توجد حالة مرتجع مرتبطة بهذا الطلب.')
                else if (data.returnLogistics == null)
                  Text(
                    'حالة طلب المرتجع: ${_customerLabel(data.returnCase!['status']?.toString() ?? '')}. لم تبدأ المتابعة اللوجستية بعد.',
                  )
                else ...[
                  Text(
                    'الحالة: ${_customerLabel(data.returnLogistics!['status']?.toString() ?? '')}',
                  ),
                  if ((data.returnLogistics!['customer_message']?.toString() ??
                          '')
                      .isNotEmpty)
                    Text(
                      'رسالة المتجر: ${data.returnLogistics!['customer_message']}',
                    ),
                  ...data.returnEvents.map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.circle, size: 10),
                      title: Text(
                        _customerLabel(event['status']?.toString() ?? ''),
                      ),
                      subtitle: Text(
                        event['customer_message']?.toString() ?? '',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'هذه الصفحة للعرض والإرشاد فقط. لا تؤكد الدفع ولا تنشئ استرداداً أو تحرك أموالاً تلقائياً.',
                ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(onPressed: _reload, child: const Text('تحديث')),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
}

class _CustomerTimelineSnapshot {
  const _CustomerTimelineSnapshot({
    required this.shipment,
    required this.shipmentEvents,
    required this.returnCase,
    required this.returnLogistics,
    required this.returnEvents,
  });

  final Map<String, dynamic>? shipment;
  final List<Map<String, dynamic>> shipmentEvents;
  final Map<String, dynamic>? returnCase;
  final Map<String, dynamic>? returnLogistics;
  final List<Map<String, dynamic>> returnEvents;
}

String _customerLabel(String value) =>
    <String, String>{
      'paid': 'مدفوع مؤكّد',
      'awaiting_payment': 'بانتظار الدفع',
      'payment_under_review': 'الدفع قيد المراجعة',
      'pending': 'قيد الانتظار',
      'arranged': 'تم ترتيب التنفيذ',
      'completed': 'تم التنفيذ',
      'planned': 'مخطط',
      'ready': 'جاهز',
      'dispatched': 'تم الإرسال',
      'in_transit': 'في الطريق',
      'delivered': 'تم التسليم',
      'failed': 'تعذر التوصيل',
      'cancelled': 'ملغى',
      'open': 'مفتوح',
      'reviewing': 'قيد المراجعة',
      'approved': 'تمت الموافقة',
      'resolved': 'تمت المعالجة',
      'requested': 'تم الطلب',
      'label_pending': 'بانتظار تجهيز المرتجع',
      'awaiting_handoff': 'بانتظار تسليم المرتجع',
      'received': 'تم استلام المرتجع',
      'inspected': 'تم فحص المرتجع',
      'closed': 'أُغلقت المتابعة',
    }[value] ??
    value;
