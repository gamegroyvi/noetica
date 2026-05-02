import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../providers.dart';
import '../../services/backend_urls_service.dart';
import '../../theme/app_theme.dart';

/// CRUD screen for the user-managed list of backend deployments.
///
/// Users may run the same Noetica backend on several Fly apps / private
/// servers (for redundancy or to develop against a localhost copy
/// without losing the production one). This screen lets them register
/// every deployment, mark one as active, and verify connectivity per
/// row before switching.
class BackendsScreen extends ConsumerWidget {
  const BackendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stateAsync = ref.watch(backendUrlsStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бэкенды'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
        onPressed: () => _editBackend(context, ref, existing: null),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (state) => ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Активный бэкенд используется для AI, синхронизации и '
                'входа. Можно держать несколько (например, прод и личный '
                'сервер) и переключаться без перезапуска.',
                style: TextStyle(color: palette.muted, height: 1.4),
              ),
            ),
            for (final ep in state.endpoints)
              _BackendRow(
                endpoint: ep,
                isActive: ep.id == state.activeId,
                canDelete: state.endpoints.length > 1,
                onMakeActive: () async {
                  await ref
                      .read(backendUrlsServiceProvider)
                      .setActive(ep.id);
                },
                onEdit: () =>
                    _editBackend(context, ref, existing: ep),
                onDelete: () async {
                  final ok = await _confirmDelete(context, ep);
                  if (!ok) return;
                  try {
                    await ref
                        .read(backendUrlsServiceProvider)
                        .remove(ep.id);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, BackendEndpoint ep) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить бэкенд?'),
        content: Text('${ep.name}\n${ep.url}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editBackend(
    BuildContext context,
    WidgetRef ref, {
    required BackendEndpoint? existing,
  }) async {
    final result = await showDialog<_BackendDialogResult>(
      context: context,
      builder: (ctx) => _BackendEditDialog(existing: existing),
    );
    if (result == null) return;
    final svc = ref.read(backendUrlsServiceProvider);
    try {
      if (existing == null) {
        await svc.add(
          name: result.name,
          url: result.url,
          makeActive: result.makeActive,
        );
      } else {
        await svc.update(existing.id, name: result.name, url: result.url);
        if (result.makeActive) {
          await svc.setActive(existing.id);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    }
  }
}

class _BackendRow extends StatefulWidget {
  const _BackendRow({
    required this.endpoint,
    required this.isActive,
    required this.canDelete,
    required this.onMakeActive,
    required this.onEdit,
    required this.onDelete,
  });

  final BackendEndpoint endpoint;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onMakeActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_BackendRow> createState() => _BackendRowState();
}

class _BackendRowState extends State<_BackendRow> {
  // null = idle, true = pinged ok, false = failed.
  bool? _pingOk;
  String? _pingError;
  bool _pinging = false;

  Future<void> _ping() async {
    setState(() {
      _pinging = true;
      _pingOk = null;
      _pingError = null;
    });
    try {
      final url = '${widget.endpoint.url}/healthz';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final ok = response.statusCode == 200;
      setState(() {
        _pingOk = ok;
        _pingError = ok ? null : 'HTTP ${response.statusCode}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pingOk = false;
        _pingError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive ? palette.fg : palette.line,
          width: widget.isActive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.endpoint.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text(widget.endpoint.url,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.muted)),
                  ],
                ),
              ),
              if (widget.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.fg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Активный',
                    style: TextStyle(
                      color: palette.bg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (_pingOk != null || _pinging)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    _pinging
                        ? Icons.cloud_sync_outlined
                        : (_pingOk == true
                            ? Icons.check_circle_outline
                            : Icons.error_outline),
                    size: 14,
                    color: _pingOk == false ? Colors.red : palette.fg,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _pinging
                          ? 'Пингую…'
                          : _pingOk == true
                              ? 'Бэкенд отвечает'
                              : 'Не отвечает: ${_pingError ?? '?'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _pingOk == false ? Colors.red : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.network_check, size: 16),
                label: const Text('Пинг'),
                onPressed: _pinging ? null : _ping,
              ),
              if (!widget.isActive)
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Сделать активным'),
                  onPressed: widget.onMakeActive,
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Изменить',
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: widget.canDelete ? null : palette.muted,
                ),
                tooltip: widget.canDelete
                    ? 'Удалить'
                    : 'Должен остаться хотя бы один бэкенд',
                onPressed: widget.canDelete ? widget.onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackendDialogResult {
  const _BackendDialogResult({
    required this.name,
    required this.url,
    required this.makeActive,
  });
  final String name;
  final String url;
  final bool makeActive;
}

class _BackendEditDialog extends StatefulWidget {
  const _BackendEditDialog({required this.existing});
  final BackendEndpoint? existing;

  @override
  State<_BackendEditDialog> createState() => _BackendEditDialogState();
}

class _BackendEditDialogState extends State<_BackendEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  bool _makeActive = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _url = TextEditingController(text: widget.existing?.url ?? 'https://');
    // For new entries we default to making them active so the user
    // doesn't have to do a second tap; for editing we leave it off so
    // pure rename / URL fix doesn't surprise-switch the active one.
    _makeActive = widget.existing == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  bool _isValidUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return false;
    final uri = Uri.tryParse(v);
    if (uri == null) return false;
    if (!uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  void _submit() {
    final url = _url.text.trim();
    if (!_isValidUrl(url)) {
      setState(() {
        _validationError = 'Введите валидный URL начинающийся с http(s)://';
      });
      return;
    }
    Navigator.of(context).pop(_BackendDialogResult(
      name: _name.text.trim(),
      url: url,
      makeActive: _makeActive,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новый бэкенд' : 'Изменить бэкенд'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Прод · Локалка · Запасной',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://noetica-backend.example.com',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
          ),
          const SizedBox(height: 8),
          if (_validationError != null)
            Text(_validationError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _makeActive,
            onChanged: (v) => setState(() => _makeActive = v ?? false),
            title: const Text('Сделать активным'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Добавить' : 'Сохранить'),
        ),
      ],
    );
  }
}
