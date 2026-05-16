// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_ipinfo/otel_ipinfo.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_ipinfo-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('privacy lookup records VPN flags + service', () async {
    await tracedIpinfo<String>(
      operation: 'privacy',
      plan: 'business',
      invoke: () async => const IpinfoCallResult(
        value: 'ok',
        result: IpinfoResult(
          isVpn: true,
          isHosting: false,
          isTor: false,
          privacyService: 'NordVPN',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('ipinfo privacy')!);
    expect(a['ipinfo.operation'], 'privacy');
    expect(a['ipinfo.plan'], 'business');
    expect(a['ipinfo.is_vpn'], true);
    expect(a['ipinfo.privacy.service'], 'NordVPN');
  });

  test('batch records items_returned + company_type', () async {
    await tracedIpinfo<String>(
      operation: 'batch',
      invoke: () async => const IpinfoCallResult(
        value: 'ok',
        result: IpinfoResult(
          itemsReturned: 250,
          companyType: 'hosting',
          countryCode: 'US',
          asn: 16509,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('ipinfo batch')!);
    expect(a['ipinfo.items_returned'], 250);
    expect(a['ipinfo.company.type'], 'hosting');
    expect(a['ipinfo.asn'], 16509);
  });

  test('suppression skips spans', () async {
    await runWithoutIpinfoInstrumentationAsync(() async {
      await tracedIpinfo<String>(
        operation: 'lookup',
        invoke: () async => const IpinfoCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('ipinfo '), isEmpty);
  });
}
