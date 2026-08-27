import 'package:flutter/material.dart';

import 'edge_assistant.dart';
import 'edge_pilot.dart';
import 'edge_runtime.dart';

class EdgePilotGateCard extends StatefulWidget {
  const EdgePilotGateCard({
    required this.surface,
    required this.titleAr,
    this.manifest,
    this.trustedPublicKeys = const <String, String>{},
    this.runtime,
    this.preferences,
    this.capabilityProbe,
    super.key,
  });

  final EdgeAppSurface surface;
  final String titleAr;
  final EdgeModelManifest? manifest;
  final Map<String, String> trustedPublicKeys;
  final EdgeRuntime? runtime;
  final EdgePilotPreferences? preferences;
  final EdgeDeviceCapabilityProbe? capabilityProbe;

  @override
  State<EdgePilotGateCard> createState() => _EdgePilotGateCardState();
}

class _EdgePilotGateCardState extends State<EdgePilotGateCard> {
  late final EdgePilotPreferences _preferences =
      widget.preferences ??
      EdgePilotPreferences(
        keyPrefix: 'yemen_commerce.edge_pilot.${widget.surface.value}',
      );
  late final EdgeRuntime _runtime = widget.runtime ?? EdgeRuntimeChannel();
  late final EdgeDeviceCapabilityProbe _capabilityProbe =
      widget.capabilityProbe ?? EdgeDeviceCapabilityProbe();
  EdgePilotOptInState _optIn = EdgePilotOptInState.disabled;
  EdgePilotDecision? _decision;
  EdgeDeviceCapabilities? _capabilities;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final optIn = await _preferences.readOptIn();
    if (!mounted) return;
    setState(() {
      _optIn = optIn;
      _loading = false;
    });
    if (optIn == EdgePilotOptInState.enabled) await _evaluate();
  }

  Future<void> _setOptIn(bool enabled) async {
    setState(() {
      _loading = true;
      _decision = null;
    });
    await _preferences.writeOptIn(
      enabled ? EdgePilotOptInState.enabled : EdgePilotOptInState.disabled,
    );
    if (!mounted) return;
    setState(() {
      _optIn = enabled
          ? EdgePilotOptInState.enabled
          : EdgePilotOptInState.disabled;
      _loading = false;
    });
    if (enabled) await _evaluate();
  }

  Future<void> _evaluate() async {
    if (_optIn != EdgePilotOptInState.enabled) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final manifest = widget.manifest;
    EdgePilotDecision decision;
    EdgeDeviceCapabilities? capabilities;
    if (manifest == null) {
      decision = const EdgePilotDecision(
        isEligible: false,
        code: 'MANIFEST_REQUIRED',
        messageAr: 'لا يوجد manifest موقع ومفعّل لهذا الإصدار.',
      );
    } else {
      capabilities = await _capabilityProbe.read();
      decision = await EdgePilotController(
        runtime: _runtime,
        verifier: EdgeEd25519ManifestVerifier(
          trustedPublicKeys: widget.trustedPublicKeys,
        ),
        preferences: _preferences,
      ).evaluate(manifest: manifest, capabilities: capabilities);
    }
    if (!mounted) return;
    setState(() {
      _capabilities = capabilities;
      _decision = decision;
      _loading = false;
    });
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
              const Icon(Icons.security_update_good_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.titleAr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Chip(label: Text('قراءة فقط')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'تجربة اختيارية على الجهاز. لا تنفذ عمليات ولا تغيّر الطلبات أو المدفوعات أو الصلاحيات.',
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('السماح بتجربة النموذج المحلي'),
            subtitle: Text(
              _optIn == EdgePilotOptInState.enabled
                  ? 'تم حفظ اختيارك محلياً لهذا الجهاز.'
                  : 'متوقفة افتراضياً ويمكن إيقافها في أي وقت.',
            ),
            value: _optIn == EdgePilotOptInState.enabled,
            onChanged: _loading ? null : _setOptIn,
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (!_loading && _optIn == EdgePilotOptInState.enabled)
            _DecisionView(decision: _decision, capabilities: _capabilities),
        ],
      ),
    ),
  );
}

class _DecisionView extends StatelessWidget {
  const _DecisionView({required this.decision, required this.capabilities});

  final EdgePilotDecision? decision;
  final EdgeDeviceCapabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    if (decision == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: decision!.isEligible
            ? colorScheme.secondaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(decision!.messageAr),
          const SizedBox(height: 4),
          if (decision!.verification != null)
            Text('التحقق: ${decision!.verification!.code}'),
          if (decision!.capabilityDecision != null)
            Text(
              'الجهاز: ${capabilities?.platform ?? 'غير معروف'} · الذاكرة: ${capabilities?.memoryMb ?? 0}MB',
            ),
          if (decision!.capabilityDecision?.reasons.isNotEmpty == true)
            Text(
              'الأسباب: ${decision!.capabilityDecision!.reasons.join('، ')}',
            ),
        ],
      ),
    );
  }
}
