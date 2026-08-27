import 'package:flutter/material.dart';
import 'package:commerce_data/commerce_data.dart';

class CreatorGovernanceReadinessCard extends StatefulWidget {
  const CreatorGovernanceReadinessCard({super.key});

  @override
  State<CreatorGovernanceReadinessCard> createState() =>
      _CreatorGovernanceReadinessCardState();
}

class _CreatorGovernanceReadinessCardState
    extends State<CreatorGovernanceReadinessCard> {
  late Future<_ReadinessSnapshot> _snapshot = _load();

  Future<_ReadinessSnapshot> _load() async {
    final repository = CreatorRepository();
    final results = await Future.wait<Object?>([
      repository.aiPlatformSettings(),
      repository.aiEvaluationSummary(),
      repository.erpFeatureRegistry(),
      repository.erpComposableModules(),
    ]);
    return _ReadinessSnapshot(
      aiSettings: results[0] as Map<String, dynamic>,
      evaluations: results[1] as List<Map<String, dynamic>>,
      features: results[2] as List<Map<String, dynamic>>,
      modules: results[3] as List<Map<String, dynamic>>,
    );
  }

  void _reload() => setState(() => _snapshot = _load());

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<_ReadinessSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text('تعذر تحميل ملخص الجاهزية'),
              subtitle: Text(
                'لم يتم تغيير أي إعداد. تحقق من صلاحية المنشئ واتصال Supabase.',
              ),
            );
          }
          final data = snapshot.data!;
          final providerEnabled = data.aiSettings['provider_enabled'] == true;
          final backgroundEnabled =
              data.aiSettings['background_enabled'] == true;
          final externalAgentEnabled =
              data.aiSettings['external_agent_enabled'] == true;
          final knowledgeEnabled = data.aiSettings['knowledge_enabled'] == true;
          final providerFeatures = data.features
              .where((row) => row['provider_required'] == true)
              .length;
          final enabledModules = data.modules
              .where((row) => row['enabled'] == true)
              .length;
          final failingEvaluations = data.evaluations.where((row) {
            final status = row['status']?.toString();
            return status != null &&
                status.isNotEmpty &&
                status != 'passed' &&
                status != 'approved';
          }).length;
          final modelReady =
              data.evaluations.isNotEmpty &&
              !providerEnabled &&
              !backgroundEnabled &&
              !externalAgentEnabled &&
              failingEvaluations == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.health_and_safety_outlined),
                      title: Text(
                        'حوكمة وجاهزية الذكاء والتشغيل',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'ملخص bounded للقرار؛ لا يعرض أسراراً ولا يمنح النموذج صلاحيات جديدة.',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    tooltip: 'تحديث الجاهزية',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReadinessChip(
                    label: providerEnabled ? 'المزود: مفعّل' : 'المزود: متوقف',
                    safe: !providerEnabled,
                  ),
                  _ReadinessChip(
                    label: backgroundEnabled
                        ? 'الخلفية: مفعّلة'
                        : 'الخلفية: متوقفة',
                    safe: !backgroundEnabled,
                  ),
                  _ReadinessChip(
                    label: externalAgentEnabled
                        ? 'وكيل خارجي: مفعّل'
                        : 'وكيل خارجي: متوقف',
                    safe: !externalAgentEnabled,
                  ),
                  _ReadinessChip(
                    label: knowledgeEnabled
                        ? 'المعرفة: مفعّلة'
                        : 'المعرفة: متوقفة',
                    safe: true,
                  ),
                  _ReadinessChip(
                    label: 'تقييمات غير ناجحة: $failingEvaluations',
                    safe: failingEvaluations == 0,
                  ),
                  _ReadinessChip(
                    label: 'وحدات مفعّلة: $enabledModules',
                    safe: true,
                  ),
                  _ReadinessChip(
                    label: 'وحدات تحتاج مزوداً: $providerFeatures',
                    safe: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                modelReady
                    ? 'الجاهزية الحالية محافظة: التنفيذ الخلفي والمزودات الخارجية متوقفة، لكن تفعيل نموذج محلي ما زال يتطلب manifest موقعاً وقياس أجهزة واجتياز التقييم.'
                    : 'توجد إعدادات أو تقييمات تحتاج مراجعة قبل أي تفعيل للنموذج المحلي. لا يتم التفعيل تلقائياً.',
              ),
              const SizedBox(height: 8),
              const Text(
                'لا تعرض هذه اللوحة مفاتيح أو أدلة دفع أو هويات عملاء. أي تغيير حوكمي لاحق يمر عبر شاشة الصلاحيات وسبب تدقيق واضح.',
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ReadinessSnapshot {
  const _ReadinessSnapshot({
    required this.aiSettings,
    required this.evaluations,
    required this.features,
    required this.modules,
  });

  final Map<String, dynamic> aiSettings;
  final List<Map<String, dynamic>> evaluations;
  final List<Map<String, dynamic>> features;
  final List<Map<String, dynamic>> modules;
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.label, required this.safe});

  final String label;
  final bool safe;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      safe ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      size: 18,
    ),
    label: Text(label),
  );
}
