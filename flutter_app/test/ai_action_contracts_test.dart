import 'package:flutter_test/flutter_test.dart';

import '../lib/core/contracts.dart';

void main() {
  test('parses a proposal as a redacted Arabic review envelope', () {
    final proposal = AiActionProposal.fromJson({
      'run_id': 'run-1',
      'tool_call_id': 'call-1',
      'approval_id': 'approval-1',
      'action_key': 'merchant.save_promotion',
      'status': 'awaiting_approval',
      'arguments': {'code': 'WELCOME', 'phone': null},
      'expires_at': '2026-08-26T18:00:00Z',
      'locale': 'ar',
    });

    expect(proposal.status, 'awaiting_approval');
    expect(proposal.argumentsRedacted['code'], 'WELCOME');
    expect(proposal.locale, 'ar');
  });

  test('parses approval and redacted tool-call state independently', () {
    final approval = AiApprovalSummary.fromJson({
      'approval_id': 'approval-1',
      'run_id': 'run-1',
      'tool_call_id': 'call-1',
      'tool_name': 'merchant.inventory_adjustment',
      'arguments_hash': '0123456789abcdef',
      'status': 'approved',
      'created_at': '2026-08-26T17:00:00Z',
      'expires_at': '2026-08-26T18:00:00Z',
    });
    final call = AiToolCallSummary.fromJson({
      'tool_call_id': 'call-1',
      'run_id': 'run-1',
      'tool_name': 'merchant.inventory_adjustment',
      'action_class': 'reversible_write',
      'status': 'approved',
      'arguments_hash': '0123456789abcdef',
      'arguments_redacted': {'product_id': 'product-1', 'quantity_delta': -2},
      'approval_required': true,
    });

    expect(approval.status, 'approved');
    expect(call.argumentsRedacted['quantity_delta'], -2);
    expect(call.approvalRequired, isTrue);
    expect(call.argumentsHash, approval.argumentsHash);
  });

  test('parses a terminal execution envelope without exposing payload fields', () {
    final result = AiActionExecutionResult.fromJson({
      'run_id': 'run-1',
      'tool_call_id': 'call-1',
      'action_key': 'merchant.inventory_count',
      'status': 'succeeded',
      'idempotent': true,
      'result': {'row_count': 1},
      'locale': 'ar',
    });

    expect(result.status, 'succeeded');
    expect(result.idempotent, isTrue);
    expect(result.result['row_count'], 1);
    expect(result.locale, 'ar');
  });
}
