// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_ipinfo_suppression.dart';

const _tracerName = 'dartastic_otel_libs_ipinfo';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class IpinfoResult {
  const IpinfoResult({
    this.countryCode,
    this.asn,
    this.isHosting,
    this.isProxy,
    this.isVpn,
    this.isTor,
    this.isRelay,
    this.privacyService,
    this.companyType,
    this.itemsReturned,
    this.statusCode,
  });

  /// ISO 3166-1 alpha-2.
  final String? countryCode;

  /// AS number from `org` / `asn.asn`.
  final int? asn;

  /// `is_hosting` from the privacy product.
  final bool? isHosting;
  final bool? isProxy;
  final bool? isVpn;
  final bool? isTor;
  final bool? isRelay;

  /// Named VPN service (e.g. `NordVPN`, `Mullvad`) when detected.
  final String? privacyService;

  /// `business` / `education` / `government` / `hosting` / `isp`.
  final String? companyType;

  /// For batch endpoints — number of IPs resolved (the cost dim).
  final int? itemsReturned;

  final int? statusCode;
}

class IpinfoCallResult<T> {
  const IpinfoCallResult({required this.value, this.result});
  final T value;
  final IpinfoResult? result;
}

/// Wraps an IPinfo REST call in a CLIENT span. [operation] is one of
/// `lookup`, `batch`, `asn`, `ranges`, `privacy`, `company`, `domains`,
/// `abuse`.
Future<T> tracedIpinfo<T>({
  required String operation,
  required Future<IpinfoCallResult<T>> Function() invoke,
  String? plan,
}) async {
  if (ipinfoInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'ipinfo',
    'rpc.method': operation,
    'ipinfo.operation': operation,
  };
  if (plan != null) m['ipinfo.plan'] = plan;

  final span = _tracer().startSpan(
    'ipinfo $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.countryCode != null) {
        extras.add(OTel.attributeString(
          'ipinfo.country.iso_code',
          r.result!.countryCode!,
        ));
      }
      if (r.result!.asn != null) {
        extras.add(OTel.attributeInt('ipinfo.asn', r.result!.asn!));
      }
      if (r.result!.isHosting != null) {
        extras.add(OTel.attributeBool(
          'ipinfo.is_hosting',
          r.result!.isHosting!,
        ));
      }
      if (r.result!.isProxy != null) {
        extras.add(OTel.attributeBool(
          'ipinfo.is_proxy',
          r.result!.isProxy!,
        ));
      }
      if (r.result!.isVpn != null) {
        extras.add(OTel.attributeBool('ipinfo.is_vpn', r.result!.isVpn!));
      }
      if (r.result!.isTor != null) {
        extras.add(OTel.attributeBool('ipinfo.is_tor', r.result!.isTor!));
      }
      if (r.result!.isRelay != null) {
        extras.add(OTel.attributeBool(
          'ipinfo.is_relay',
          r.result!.isRelay!,
        ));
      }
      if (r.result!.privacyService != null) {
        extras.add(OTel.attributeString(
          'ipinfo.privacy.service',
          r.result!.privacyService!,
        ));
      }
      if (r.result!.companyType != null) {
        extras.add(OTel.attributeString(
          'ipinfo.company.type',
          r.result!.companyType!,
        ));
      }
      if (r.result!.itemsReturned != null) {
        extras.add(OTel.attributeInt(
          'ipinfo.items_returned',
          r.result!.itemsReturned!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'IPinfo HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
