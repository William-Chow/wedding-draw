import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/draw_settings.dart';

/// Edits [DrawSettings]. Pops the new settings, or null when cancelled.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initial,
    required this.winnerCount,
  });

  final DrawSettings initial;

  /// How many winners exist; they are kept when the range changes.
  final int winnerCount;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial.title);
  late final _min = TextEditingController(text: '${widget.initial.min}');
  late final _max = TextEditingController(text: '${widget.initial.max}');
  late bool _allowRepeats = widget.initial.allowRepeats;

  @override
  void dispose() {
    _title.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? _validateMin(String? text) {
    return int.tryParse(text ?? '') == null ? 'Enter a number' : null;
  }

  String? _validateMax(String? text) {
    final max = int.tryParse(text ?? '');
    if (max == null) return 'Enter a number';
    final min = int.tryParse(_min.text);
    return min == null ? null : DrawSettings.validateRange(min, max);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      DrawSettings(
        title: _title.text.trim(),
        min: int.parse(_min.text),
        max: int.parse(_max.text),
        allowRepeats: _allowRepeats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final min = int.tryParse(_min.text);
    final max = int.tryParse(_max.text);
    final preview =
        min != null &&
            max != null &&
            DrawSettings.validateRange(min, max) == null
        ? DrawSettings(min: min, max: max)
        : null;
    return AlertDialog(
      title: const Text('Draw settings'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('titleField'),
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Event title',
                  hintText: 'e.g. William & Anna',
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 40,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NumberField(
                      key: const Key('minField'),
                      controller: _min,
                      label: 'From',
                      validator: _validateMin,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _NumberField(
                      key: const Key('maxField'),
                      controller: _max,
                      label: 'To',
                      validator: _validateMax,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview == null
                    ? 'Tickets can be numbered from 0 to '
                          '${DrawSettings.maxSupportedNumber}.'
                    : '${preview.rangeSize} numbers, shown as '
                          '${preview.format(preview.min)} to '
                          '${preview.format(preview.max)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('allowRepeatsSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow repeat winners'),
                subtitle: const Text('A number can be drawn more than once.'),
                value: _allowRepeats,
                onChanged: (value) => setState(() => _allowRepeats = value),
              ),
              if (widget.winnerCount > 0) ...[
                const SizedBox(height: 8),
                _KeptWinnersNote(
                  count: widget.winnerCount,
                  allowRepeats: _allowRepeats,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Wedding Draw',
          ),
          child: const Text('Licenses'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveSettingsButton'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, errorMaxLines: 2),
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(
          '${DrawSettings.maxSupportedNumber}'.length,
        ),
      ],
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}

/// Explains what happens to existing winners when the range changes.
class _KeptWinnersNote extends StatelessWidget {
  const _KeptWinnersNote({required this.count, required this.allowRepeats});

  final int count;
  final bool allowRepeats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winners = count == 1 ? '1 winner' : '$count winners';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'The $winners drawn so far will be kept'
                '${allowRepeats ? '.' : ', and numbers that already won '
                          'will not be drawn again, even in a new range.'}'
                ' To start over, use "Clear all" in the winners list.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
