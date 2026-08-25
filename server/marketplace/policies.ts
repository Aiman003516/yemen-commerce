export type PolicyVersionRow = {
  key: string;
  version: number;
  valueJson: string;
  isActive: boolean;
  effectiveFrom: Date | null;
};

export type ResolvedPolicy = Omit<PolicyVersionRow, "valueJson"> & { value: Record<string, unknown> };

/** Selects one safe, active, effective policy per key without hard-coding an Ibb-only branch. */
export function resolveActivePolicies(rows: PolicyVersionRow[], now = new Date()): ResolvedPolicy[] {
  const selected = new Map<string, PolicyVersionRow>();
  for (const row of rows) {
    if (!row.isActive || (row.effectiveFrom && row.effectiveFrom > now)) continue;
    const current = selected.get(row.key);
    if (!current || row.version > current.version) selected.set(row.key, row);
  }
  return Array.from(selected.values()).map(({ valueJson, ...row }) => ({ ...row, value: JSON.parse(valueJson) as Record<string, unknown> }));
}

export function policyOrFallback(policies: ResolvedPolicy[], key: string, fallback: Record<string, unknown>) {
  return policies.find((policy) => policy.key === key)?.value ?? fallback;
}
