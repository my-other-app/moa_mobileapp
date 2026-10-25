import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/volunteer/data/ticket_code.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';
import 'package:finnet/features/volunteer/presentation/providers/gate_controller.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_outcome_card.dart';

/// Check someone in by typing their ticket code, when the QR won't scan.
///
/// The same door as the camera's (the gate console, [GateController]): the
/// code is checked in at once, saved on the phone when there is no signal,
/// and the answer shows under the field. Only the ticket code
/// (MOA-7K3QF-X9PWM) checks anyone in; an admission number printed beside
/// the QR finds whose it is, to check them in by hand.
class ManualTicketEntryPage extends ConsumerStatefulWidget {
  final int eventId;
  final String eventName;
  final String clubName;

  const ManualTicketEntryPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.clubName,
  });

  @override
  ConsumerState<ManualTicketEntryPage> createState() =>
      _ManualTicketEntryPageState();
}

class _ManualTicketEntryPageState extends ConsumerState<ManualTicketEntryPage> {
  final _ticketController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  GateController get _gate =>
      ref.read(gateControllerProvider(widget.eventId).notifier);

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    await _gate.scan(_ticketController.text.trim());
    if (!mounted) return;
    final card = ref.read(gateControllerProvider(widget.eventId)).card;
    // Let in (or saved to send): the field is ready for the next one.
    final tone = card?.card.tone;
    if (tone == GateTone.admit || tone == GateTone.queued) {
      _ticketController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(gateControllerProvider(widget.eventId));
    final card = gate.card;
    final result = card?.result;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'CHECK IN WITH A TICKET CODE',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scrolls, so a long refusal never pushes the button off a
              // small screen with the keyboard up.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Ticket code',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ticketController,
                        decoration: InputDecoration(
                          hintText: 'e.g. $ticketCodeExample',
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF2C333D), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the ticket code';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (card != null) _gate.dismissCard();
                        },
                        onFieldSubmitted: (_) => _submitTicket(),
                      ),
                      const SizedBox(height: 8),
                      if (card != null)
                        GateOutcomeCard(
                          key: ValueKey('typed-card-${card.seq}'),
                          card: card.card,
                          onClose: _gate.dismissCard,
                          onCheckInByHand:
                              result != null && result.needsHandCheckIn
                                  ? () => _gate.checkInByHand(result.attendee!)
                                  : null,
                        )
                      else
                        const Text(
                          'Shown as Ticket ID on their ticket in the app. An '
                          'admission number like MOA-0042-E12 only finds '
                          'whose it is, to check them in by hand.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: gate.busy ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: gate.busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'BebasNeue',
                          ),
                        ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}
