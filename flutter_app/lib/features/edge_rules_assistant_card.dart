import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/material.dart';

class EdgeRulesOnlyAssistantCard extends StatefulWidget {
  const EdgeRulesOnlyAssistantCard({
    required this.surface,
    this.context = const <String, dynamic>{},
    super.key,
  });

  final EdgeAppSurface surface;
  final Map<String, dynamic> context;

  @override
  State<EdgeRulesOnlyAssistantCard> createState() =>
      _EdgeRulesOnlyAssistantCardState();
}

class _EdgeRulesOnlyAssistantCardState
    extends State<EdgeRulesOnlyAssistantCard> {
  final _prompt = TextEditingController();
  final _orchestrator = EdgeAssistantOrchestrator();
  EdgeProposal? _proposal;
  EdgeValidationResult? _validation;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _interpret() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _proposal = null;
        _validation = null;
        _status = 'اكتب طلباً قصيراً قبل تشغيل المساعد المحلي.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    final orchestration = await _orchestrator.propose(
      EdgeAssistantRequest(
        requestId: 'edge-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        surface: widget.surface,
        locale: 'ar-YE',
        prompt: prompt,
        createdAt: DateTime.now().toUtc(),
        context: widget.context,
      ),
    );
    if (!mounted) return;
    final proposal = orchestration.proposal;
    final validation = EdgeProposalValidator.validate(proposal);
    setState(() {
      _busy = false;
      _proposal = proposal;
      _validation = validation;
      _status = null;
    });
  }

  void _confirmLocally() {
    final proposal = _proposal;
    final validation = _validation;
    if (proposal == null || validation == null || !validation.isValid) return;
    setState(() {
      _status = proposal.riskClass == EdgeRiskClass.readOnly
          ? 'تم تأكيد عرض الاقتراح محلياً. لم يتم إرسال أي تغيير.'
          : 'تم تأكيد المسودة محلياً. لم يتم تنفيذ أي تغيير على الخادم في هذا الإصدار.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _proposal;
    final validation = _validation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مساعد يمن كومرس المحلي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Chip(label: Text('قواعد آمنة')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'يساعدك هذا الإصدار على فهم الطلب والتحقق من الحقول. لا يرسل أو ينفذ أي عملية تلقائياً.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              minLines: 1,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'ماذا تريد أن تفعل؟',
                hintText: 'مثال: اشرح حالة طلبي أو اجعل حالة التوصيل جاهزاً',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _interpret(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _busy ? null : _interpret,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_busy ? 'يتم التحقق…' : 'تحقق من الطلب'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 10),
              _MessageBox(message: _status!),
            ],
            if (proposal != null) ...[
              const Divider(height: 24),
              _ProposalPreview(proposal: proposal),
              const SizedBox(height: 10),
              if (validation != null && !validation.isValid)
                _ValidationIssues(validation: validation),
              if (validation != null && validation.isValid)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: proposal.riskClass == EdgeRiskClass.prohibited
                        ? null
                        : _confirmLocally,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('أؤكد الاقتراح محلياً'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalPreview extends StatelessWidget {
  const _ProposalPreview({required this.proposal});

  final EdgeProposal proposal;

  @override
  Widget build(BuildContext context) {
    final labels = <String, String>{
      'assistant.clarify': 'توضيح مطلوب',
      'navigation.open': 'فتح شاشة مسموحة',
      'knowledge.explain': 'شرح من المعرفة الموثقة',
      'status.explain': 'شرح الحالة',
      'shipment.record_status': 'تحديث حالة التوصيل',
      'channel.save': 'حفظ قناة بيع',
      'order.explain': 'شرح الطلب',
      'return.prepare': 'تجهيز المرتجع',
      'provider.readiness': 'حالة جاهزية المزود',
      'payment.mark_paid': 'تغيير حالة الدفع',
      'payment.refund': 'استرداد مالي',
      'payment.settle': 'تسوية مالية',
      'fund.transfer': 'تحويل أموال',
    };
    final riskLabel = switch (proposal.riskClass) {
      EdgeRiskClass.readOnly => 'قراءة فقط',
      EdgeRiskClass.draftOnly => 'مسودة',
      EdgeRiskClass.reviewableOperational => 'إجراء يحتاج مراجعة',
      EdgeRiskClass.highImpact => 'إجراء عالي التأثير',
      EdgeRiskClass.prohibited => 'محظور',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الاقتراح: ${labels[proposal.intent] ?? 'عملية غير معروفة'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('الخطورة: $riskLabel')),
            Chip(label: Text('الثقة: ${(proposal.confidence * 100).round()}%')),
            if (proposal.requiresConfirmation)
              const Chip(label: Text('يتطلب تأكيداً')),
          ],
        ),
        const SizedBox(height: 6),
        Text(proposal.explanationAr),
        ..._draftPreview(context),
        if (proposal.entities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'البيانات المقترحة: ${EdgeCanonicalJson.encode(proposal.entities)}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
          ),
        ],
        if (proposal.provenance != null) ...[
          const SizedBox(height: 6),
          Text(
            'المصدر: ${_provenanceLabel(proposal.provenance!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (proposal.missingFields.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('المطلوب: ${proposal.missingFields.join('، ')}'),
        ],
        const SizedBox(height: 6),
        Text(
          'بصمة الاقتراح: ${proposal.proposalHash.substring(0, 16)}…',
          style: Theme.of(context).textTheme.bodySmall,
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  List<Widget> _draftPreview(BuildContext context) {
    final draft = const EdgeDraftComposer().compose(proposal);
    if (draft == null || draft.fields.isEmpty) return const <Widget>[];
    return [
      const SizedBox(height: 8),
      Text(
        'مسودة غير محفوظة — راجعها قبل النسخ أو الحفظ',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      ...draft.fields.map(
        (field) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${field.labelAr}: ${field.value}'),
        ),
      ),
    ];
  }

  String _provenanceLabel(EdgeProposalProvenance provenance) {
    final source = switch (provenance.source) {
      'rules' => 'قواعد محلية',
      'local_knowledge_pack' => 'حزمة معرفة محلية موقعة',
      'server_read' => 'قراءة مسموحة من الخادم',
      _ => 'مصدر غير معروف',
    };
    if (provenance.packVersion == null) return source;
    return '$source — الإصدار ${provenance.packVersion}';
  }
}

class _ValidationIssues extends StatelessWidget {
  const _ValidationIssues({required this.validation});

  final EdgeValidationResult validation;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('لا يمكن اعتماد الاقتراح بعد:'),
        const SizedBox(height: 4),
        ...validation.issues.map((issue) => Text('• ${issue.messageAr}')),
      ],
    ),
  );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );
}
