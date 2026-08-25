import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { API_VERSION, fulfilmentMethods, paymentStatuses, roles } from "../../shared/domain";

describe("Flutter contract mirror", () => {
  it("declares the implemented shared API version, roles, payment states, and fulfilment vocabulary", () => {
    const flutterContracts = readFileSync(resolve(process.cwd(), "flutter_app/lib/core/contracts.dart"), "utf8");
    expect(flutterContracts).toContain(`const marketplaceApiVersion = '${API_VERSION}'`);
    for (const role of roles) expect(flutterContracts).toContain(role);
    for (const status of paymentStatuses) expect(flutterContracts).toContain(status.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase()));
    for (const method of fulfilmentMethods) expect(flutterContracts).toContain(method.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase()));
  });
});
