import 'package:flutter/material.dart';

import '../../../widgets/empty_state_widget.dart';
import './ticket_list_item_widget.dart';

class TicketQueueWidget extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;
  final void Function(String ticketId, String workerName) onAssignWorker;
  final bool isTablet;

  const TicketQueueWidget({
    super.key,
    required this.tickets,
    required this.onAssignWorker,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyStateWidget(
          iconName: 'assignment_turned_in',
          title: 'No tickets in this filter',
          subtitle:
              'All hazards matching this filter have been resolved or reassigned.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TicketListItemWidget(
            ticket: tickets[index],
            index: index,
            onAssignWorker: onAssignWorker,
          ),
        );
      }, childCount: tickets.length),
    );
  }
}
