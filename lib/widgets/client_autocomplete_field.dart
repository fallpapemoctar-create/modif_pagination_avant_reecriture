import 'dart:async';

import 'package:flutter/material.dart';

import '../services/client_service.dart';

typedef ClientAutocompleteTrailingBuilder = List<Widget> Function(
  BuildContext context,
  ClientAutocompleteController controller,
  bool loading,
);

class ClientAutocompleteController {
  ClientAutocompleteController({
    required this.focusNode,
    required this.showOptions,
    required this.refresh,
  });

  final FocusNode focusNode;
  final VoidCallback showOptions;
  final VoidCallback refresh;
}

class ClientAutocompleteField extends StatefulWidget {
  const ClientAutocompleteField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.onSelected,
    this.onSummarySelected,
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.trailingBuilder,
    this.onLoadingChanged,
    this.onError,
  });

  final String value;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onSelected;
  /// Called when a client is selected from the dropdown, with the full summary (including numeric id).
  final ValueChanged<ClientSummary>? onSummarySelected;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final bool enabled;
  final bool autofocus;
  final ClientAutocompleteTrailingBuilder? trailingBuilder;
  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<String?>? onError;

  @override
  State<ClientAutocompleteField> createState() => _ClientAutocompleteFieldState();
}

class _ClientAutocompleteFieldState extends State<ClientAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final GlobalKey _autocompleteKey = GlobalKey();
  final List<String> _options = <String>[];
  final List<ClientSummary> _summaries = <ClientSummary>[];
  Timer? _debounce;
  bool _loading = false;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    assert(() {
      if (widget.value.isNotEmpty) {
        final normalized = widget.value.trim();
        if (normalized.isNotEmpty) {
          _options.add(normalized);
        }
      }
      return true;
    }());
    unawaited(_fetchOptions(widget.value));
  }

  @override
  void didUpdateWidget(covariant ClientAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchOptions(value);
    });
  }

  Future<void> _fetchOptions(String query) async {
    final target = ++_requestToken;
    setState(() => _loading = true);
    widget.onLoadingChanged?.call(true);
    try {
      final summaries = await ClientService.getClientSummaries(query: query, limit: 30);
      if (!mounted || target != _requestToken) {
        return;
      }
      setState(() {
        _summaries
          ..clear()
          ..addAll(summaries);
        _options
          ..clear()
          ..addAll(summaries.map((s) => s.name));
        _loading = false;
      });
      widget.onLoadingChanged?.call(false);
      widget.onError?.call(null);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _options.clear();
        _summaries.clear();
        _loading = false;
      });
      widget.onLoadingChanged?.call(false);
      widget.onError?.call(error.toString());
    }
  }

  void _showOptions() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    if (_options.isEmpty) {
      unawaited(_fetchOptions(_controller.text));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerHandle = ClientAutocompleteController(
      focusNode: _focusNode,
      showOptions: _showOptions,
      refresh: () => _fetchOptions(_controller.text),
    );

    return RawAutocomplete<String>(
      key: _autocompleteKey,
      focusNode: _focusNode,
      textEditingController: _controller,
      optionsBuilder: (TextEditingValue value) {
        if (!_focusNode.hasFocus) return const Iterable<String>.empty();
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return List<String>.from(_options);
        return _options.where((option) => option.toLowerCase().contains(query));
      },
      onSelected: (selection) {
        widget.onChanged(selection);
        widget.onSelected?.call(selection);
        // Emit the full ClientSummary (with numeric id) when available
        if (widget.onSummarySelected != null) {
          final match = _summaries.where((s) => s.name == selection).firstOrNull;
          if (match != null) widget.onSummarySelected!(match);
        }
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.business),
            hintText: widget.hintText ?? 'Sélectionner un client',
            isDense: true,
            suffixIcon: _buildSuffix(context, controllerHandle),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList(growable: false);
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, minWidth: 280),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, ignored) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = list[index];
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuffix(BuildContext context, ClientAutocompleteController controllerHandle) {
    final trailing = <Widget>[
      IconButton(
        icon: const Icon(Icons.arrow_drop_down),
        tooltip: 'Voir les clients',
        onPressed: widget.enabled ? controllerHandle.showOptions : null,
      ),
      if (_loading)
        const SizedBox(
          width: 18,
          height: 18,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
    ];
    final extra = widget.trailingBuilder?.call(context, controllerHandle, _loading) ?? const <Widget>[];
    trailing.addAll(extra);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: trailing,
    );
  }
}
