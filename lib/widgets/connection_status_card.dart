import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    required this.backendUrl,
    required this.testing,
    required this.result,
    required this.error,
    required this.errorStatusCode,
    required this.errorElapsed,
    required this.onTest,
    super.key,
  });

  final String backendUrl;
  final bool testing;
  final ConnectionResult? result;
  final String? error;
  final int? errorStatusCode;
  final Duration? errorElapsed;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) {
    final success = result != null && error == null;
    final color = error != null
        ? Theme.of(context).colorScheme.error
        : success
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: color),
                const SizedBox(width: 10),
                Text(
                  'Connection test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Detail(label: 'Backend URL', value: backendUrl),
            _Detail(
              label: 'Status',
              value: testing
                  ? 'Testing…'
                  : error != null
                      ? 'Failed'
                      : success
                          ? 'Connected'
                          : 'Not tested',
              valueColor: color,
            ),
            _Detail(
              label: 'HTTP response',
              value: (result?.statusCode ?? errorStatusCode)?.toString() ?? '—',
            ),
            _Detail(
              label: 'Response time',
              value: result == null && errorElapsed == null
                  ? '—'
                  : '${(result?.elapsed ?? errorElapsed)!.inMilliseconds} ms',
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ] else if (result != null) ...[
              const SizedBox(height: 8),
              Text(result!.message, style: TextStyle(color: color)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: testing ? null : onTest,
              icon: testing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: const Text('Test Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
