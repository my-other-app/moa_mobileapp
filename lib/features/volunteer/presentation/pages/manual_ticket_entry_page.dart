import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/volunteer/data/ticket_code.dart';
import 'package:finnet/features/volunteer/presentation/providers/volunteer_provider.dart';

/// Check someone in by typing their ticket code, when the QR won't scan.
///
/// Only the ticket code (MOA-7K3QF-X9PWM) checks anyone in; the admission
/// number printed beside the QR does not (see `data/ticket_code.dart`), and
/// the page says so.
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
  bool _isLoading = false;

  /// Why the last code was refused, shown under the field until it is
  /// edited. A snackbar was gone before the longer reasons could be read.
  String? _refusal;

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _refusal = null;
    });

    final result = await ref
        .read(volunteerProvider.notifier)
        .checkinParticipant(widget.eventId, _ticketController.text.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!result.success) _refusal = result.message;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Clear the field for next entry
      _ticketController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final refusal = _refusal;
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
                          if (_refusal != null) {
                            setState(() => _refusal = null);
                          }
                        },
                        onFieldSubmitted: (_) => _submitTicket(),
                      ),
                      const SizedBox(height: 8),
                      if (refusal != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFCC0000), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                refusal,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFCC0000),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Shown as Ticket ID on their ticket in the app. '
                          "Admission numbers like MOA-0042-E12 can't check "
                          'anyone in.',
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
                  onPressed: _isLoading ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
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
