import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/event_id.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/gate_repository.dart';
import '../../data/models.dart';
import '../../data/request_models.dart';
import 'id_photo_picker.dart';
import 'returning_visitor_sheet.dart';

const purposes = {
  'meeting': 'Meeting',
  'delivery': 'Delivery',
  'contractor': 'Contractor work',
  'interview': 'Interview',
  'other': 'Other',
};

/// Lets tests replace the camera.
final takePhotoProvider = Provider<TakePhoto>((ref) => takeIdPhotoWithCamera);

/// G7 New visitor: register a visitor without email; sends a pending request.
class NewVisitorScreen extends ConsumerStatefulWidget {
  const NewVisitorScreen({super.key});

  @override
  ConsumerState<NewVisitorScreen> createState() => _NewVisitorScreenState();
}

class _NewVisitorScreenState extends ConsumerState<NewVisitorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _host = TextEditingController();
  String? _purpose;
  PassType _type = PassType.day;
  Uint8List? _photo;
  String? _photoError;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _id, _phone, _plate, _host]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final bytes = await ref.read(takePhotoProvider)();
      if (bytes == null || !mounted) return;
      setState(() {
        if (bytes.lengthInBytes > maxIdPhotoBytes) {
          _photo = null;
          _photoError =
              'That photo is too large. Take it again, a little further from the card.';
        } else {
          _photo = bytes;
          _photoError = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError =
              'The camera could not open. Check camera access in Settings.',
        );
      }
    }
  }

  NewVisitor _visitor() => NewVisitor(
    fullName: _name.text.trim(),
    idNumber: _id.text.trim(),
    hostName: _host.text.trim(),
    purpose: _purpose!,
    passType: _type,
    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    plate: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
  );

  void _resetForm() {
    _form.currentState!.reset();
    for (final c in [_name, _id, _phone, _plate, _host]) {
      c.clear();
    }
    setState(() {
      _purpose = null;
      _type = PassType.day;
      _photo = null;
    });
  }

  /// No network: keep the request (and photo) on the phone; the sync worker sends it.
  Future<void> _queue(String requestId) async {
    final v = _visitor();
    await ref
        .read(offlineStoreProvider)
        .enqueue(
          kind: 'request',
          eventId: requestId,
          payload: {
            'full_name': v.fullName,
            'id_number': v.idNumber,
            'host_name': v.hostName,
            'purpose': v.purpose,
            'pass_type': v.passType.name,
            'phone': v.phone,
            'plate': v.plate,
          },
          photo: _photo,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('request-queued'),
        content: Text(
          'No connection. ${v.fullName}\'s request is saved and will send when the phone is back online.',
        ),
      ),
    );
    _resetForm();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    // One id for this request whether it goes now or later: a retry never duplicates it.
    final requestId = newEventId();
    final repo = ref.read(gateRequestsRepositoryProvider);
    try {
      if (!await ref.read(connectivityProvider).isOnline()) {
        await _queue(requestId);
        return;
      }
      final created = await repo.create(_visitor(), clientRequestId: requestId);
      var photoFailed = false;
      if (_photo != null) {
        try {
          await repo.uploadIdPhoto(created.passId, _photo!);
        } on GateFailure {
          photoFailed = true;
        }
      }
      ref.invalidate(myGateRequestsProvider);
      if (!mounted) return;
      if (photoFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request sent, but the ID photo did not upload. Reception can still decide.',
            ),
          ),
        );
      }
      _resetForm();
      context.push('/requests/${created.passId}');
    } on GateFailure catch (e) {
      if (e.network) {
        await _queue(requestId);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String? required(String? v, String message) =>
        (v == null || v.trim().isEmpty) ? message : null;

    InputDecoration deco(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      fillColor: AppColors.surface2,
    );

    Widget label(String text, {bool optional = false}) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: AppSpacing.s2),
      child: Text.rich(
        TextSpan(
          text: text,
          style: t.labelLarge,
          children: [
            if (optional)
              const TextSpan(
                text: ' (optional)',
                style: TextStyle(color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          120,
        ),
        children: [
          Text(
            'New visitor',
            style: t.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          OutlinedButton.icon(
            key: const Key('returning-visitor'),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => showReturningVisitorSheet(context),
            icon: const Icon(Icons.history),
            label: const Text('Returning visitor? Find their pass'),
          ),
          const SizedBox(height: AppSpacing.s2),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s2,
                0,
                AppSpacing.s2,
                AppSpacing.s2,
              ),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label('Full name'),
                    TextFormField(
                      key: const Key('visitor-name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: deco('Enter full name', Icons.person_outline),
                      validator: (v) =>
                          required(v, 'Enter the visitor\'s full name.'),
                    ),
                    label('ID number'),
                    TextFormField(
                      key: const Key('visitor-id'),
                      controller: _id,
                      textCapitalization: TextCapitalization.characters,
                      decoration: deco('Enter ID number', Icons.badge_outlined),
                      validator: (v) =>
                          required(v, 'Enter the ID number from their card.'),
                    ),
                    label('Phone', optional: true),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: deco(
                        '+265 88 123 4567',
                        Icons.phone_outlined,
                      ),
                    ),
                    label('Vehicle plate', optional: true),
                    TextFormField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      decoration: deco(
                        'e.g. BT 4521',
                        Icons.directions_car_outlined,
                      ),
                    ),
                    label('Visiting'),
                    TextFormField(
                      key: const Key('visitor-host'),
                      controller: _host,
                      decoration: deco(
                        'Person or department',
                        Icons.apartment_outlined,
                      ),
                      validator: (v) => required(v, 'Who are they visiting?'),
                    ),
                    label('Purpose of visit'),
                    DropdownButtonFormField<String>(
                      key: const Key('visitor-purpose'),
                      isExpanded: true,
                      initialValue: _purpose,
                      decoration: deco('Select purpose', Icons.list_alt),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      items: [
                        for (final e in purposes.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _purpose = v),
                      validator: (v) =>
                          v == null ? 'Choose the purpose.' : null,
                    ),
                    label('Pass type'),
                    Row(
                      children: [
                        for (final type in [PassType.day, PassType.week]) ...[
                          if (type == PassType.week) const SizedBox(width: 12),
                          Expanded(
                            child: _PassTypeCard(
                              type: type,
                              selected: _type == type,
                              onTap: () => setState(() => _type = type),
                            ),
                          ),
                        ],
                      ],
                    ),
                    label('ID photo', optional: true),
                    IdPhotoTile(
                      photo: _photo,
                      error: _photoError,
                      onTake: _takePhoto,
                      onRemove: () => setState(() => _photo = null),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s3),
                    FilledButton.icon(
                      key: const Key('send-for-approval'),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brand,
                              ),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('Send for approval'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassTypeCard extends StatelessWidget {
  const _PassTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PassType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final week = type == PassType.week;
    return Semantics(
      selected: selected,
      button: true,
      label: week ? 'One week' : 'One day',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandSoft : AppColors.surface2,
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.surface2,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.brandStrong
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        week ? 'One week' : 'One day',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  week ? 'Valid for 7 days' : 'Today only',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status words for the guard's request list and waiting screen.
String requestStatusLabel(RequestStatus s) => switch (s) {
  RequestStatus.pending => 'Waiting',
  RequestStatus.approved => 'Approved',
  RequestStatus.rejected => 'Rejected',
  RequestStatus.revoked => 'Cancelled',
  RequestStatus.expired => 'Expired',
};
