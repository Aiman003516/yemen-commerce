import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/material.dart';

class CreatorEdgeRulesAssistantCard extends StatefulWidget {
  const CreatorEdgeRulesAssistantCard({super.key});

  @override
  State<CreatorEdgeRulesAssistantCard> createState() =>
      _CreatorEdgeRulesAssistantCardState();
}

class _CreatorEdgeRulesAssistantCardState
    extends State<CreatorEdgeRulesAssistantCard> {
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
        requestId:
            'creator-edge-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        surface: EdgeAppSurface.creator,
        locale: 'ar-YE',
        prompt: prompt,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (!mounted) return;
    final proposal = orchestration.proposal;
    setState(() {
      _busy = false;
      _proposal = proposal;
      _validation = EdgeProposalValidator.validate(proposal);
      _status = null;
    });
  }

  void _confirmLocally() {
    final proposal = _proposal;
    final validation = _validation;
    if (proposal == null || validation == null || !validation.isValid) return;
    setState(
      () => _status =
          'تم تأكيد المسودة محلياً. لم يتم تغيير صلاحية أو سياسة على الخادم.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _proposal;
    final validation = _validation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مساعد المنشئ المحلي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Chip(label: Text('بدون تنفيذ تلقائي')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'يساعد في فهم جاهزية الوحدات والسياسات. أي إجراء عالي التأثير يبقى خلف صلاحيات المنشئ وتأكيده في Supabase.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              minLines: 1,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'ما الذي تريد مراجعته؟',
                hintText: 'مثال: اعرض حالة جاهزية المزودات',
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
              _CreatorMessage(message: _status!),
            ],
            if (proposal != null) ...[
              const Divider(height: 24),
              Text(
                'الاقتراح: ${_creatorIntentLabel(proposal.intent)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(proposal.explanationAr),
              ..._draftPreview(context, proposal),
              if (proposal.provenance != null) ...[
                const SizedBox(height: 6),
                Text(
                  'المصدر: ${_provenanceLabel(proposal.provenance!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'بصمة الاقتراح: ${proposal.proposalHash.substring(0, 16)}…',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (validation != null && !validation.isValid) ...[
                const SizedBox(height: 10),
                _CreatorValidationIssues(validation: validation),
              ],
              if (validation != null && validation.isValid) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: _confirmLocally,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('أؤكد الاقتراح محلياً'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _creatorIntentLabel(String intent) => switch (intent) {
    'navigation.open' => 'فتح شاشة مسموحة',
    'knowledge.explain' => 'شرح من المعرفة الموثقة',
    'status.explain' => 'شرح الحالة',
    'provider.readiness' => 'جاهزية المزودات',
    'erp.summary' => 'ملخص ERP',
    'ai.evaluation_summary' => 'ملخص تقييم الذكاء الاصطناعي',
    'governance.draft' => 'مسودة حوكمة',
    'policy.propose' => 'اقتراح سياسة',
    _ => 'توضيح مطلوب',
  };

  List<Widget> _draftPreview(BuildContext context, EdgeProposal proposal) {
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

class _CreatorValidationIssues extends StatelessWidget {
  const _CreatorValidationIssues({required this.validation});

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

class _CreatorMessage extends StatelessWidget {
  const _CreatorMessage({required this.message});

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
