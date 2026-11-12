import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/label_view_model.dart';
import "../../../widgets/error_state.dart";
import "../../../widgets/empty_state.dart";
import '../../../widgets/loading_skeleton.dart';
import 'expandable_label_card.dart';

class LabelListView extends StatefulWidget {
  const LabelListView({super.key});

  @override
  State<LabelListView> createState() => _LabelListViewState();
}

class _LabelListViewState extends State<LabelListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final vm = context.read<LabelViewModel>();
    if (!vm.hasMore || vm.isLoadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      vm.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LabelViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading && vm.items.isEmpty) {
          return const LoadingSkeleton();
        }
        if (vm.errorMessage.isNotEmpty && vm.items.isEmpty) {
          return ErrorState(message: vm.errorMessage, onRetry: vm.refresh);
        }
        if (vm.items.isEmpty) {
          return EmptyState(onRefresh: vm.refresh);
        }

        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: vm.items.length + (vm.isLoadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= vm.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return LabelExpandableCard(item: vm.items[i]);
            },
          ),
        );
      },
    );
  }
}
