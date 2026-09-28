import 'package:flutter/material.dart';

import 'palette.dart';

/// The winners drawn so far, in draw order, with editing actions.
class HistoryPanel extends StatefulWidget {
  const HistoryPanel({
    super.key,
    required this.winners,
    required this.format,
    required this.isInRange,
    required this.enabled,
    required this.onRemove,
    required this.onUndoLast,
    required this.onClearAll,
  });

  final List<int> winners;
  final String Function(int number) format;
  final bool Function(int number) isInRange;

  /// False while the reels spin, which disables every action.
  final bool enabled;

  /// Called with the index of the winner to remove.
  final ValueChanged<int> onRemove;
  final VoidCallback onUndoLast;
  final VoidCallback onClearAll;

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(HistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.winners.length > oldWidget.winners.length) {
      // Keep the newest winner in view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winners = widget.winners;
    final canEdit = widget.enabled && winners.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: WeddingPalette.goldText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    winners.isEmpty ? 'Winners' : 'Winners (${winners.length})',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Undo last draw',
                  icon: const Icon(Icons.undo),
                  onPressed: canEdit ? widget.onUndoLast : null,
                ),
                IconButton(
                  tooltip: 'Clear all winners',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: canEdit ? widget.onClearAll : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: winners.isEmpty
                ? const _EmptyHistory()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: winners.length,
                    itemBuilder: (context, index) => _WinnerTile(
                      index: index,
                      label: widget.format(winners[index]),
                      inRange: widget.isInRange(winners[index]),
                      latest: index == winners.length - 1,
                      onRemove: widget.enabled
                          ? () => widget.onRemove(index)
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WinnerTile extends StatelessWidget {
  const _WinnerTile({
    required this.index,
    required this.label,
    required this.inRange,
    required this.latest,
    required this.onRemove,
  });

  final int index;
  final String label;
  final bool inRange;
  final bool latest;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: latest ? WeddingPalette.blush : null,
      leading: SizedBox(
        width: 48,
        child: Text(
          '#${index + 1}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: WeddingPalette.goldText,
          ),
        ),
      ),
      title: Text(
        label,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: inRange
              ? WeddingPalette.roseDeep
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: inRange ? null : const Text('Outside the current range'),
      trailing: IconButton(
        tooltip: 'Remove winner #${index + 1}',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No winners yet.\nPress Draw to pick the first lucky number.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
