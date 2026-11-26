import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/common.dart';

/// Takes a photo with the camera on phones, or picks a file on web/Windows.
Future<void> capturePhoto(BuildContext context, InspectionItem item, String stage) async {
  final s = AppScope.of(context);
  final mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  try {
    final f = await ImagePicker().pickImage(
      source: mobile ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 70,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    await s.addPhoto(item, bytes, stage);
    if (context.mounted) toast(context, 'Photo saved and hashed for ${item.name}');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not add photo: $e');
  }
}

/// Move-in inspection: room-by-room checklist with photo evidence.
class InspectionScreen extends StatelessWidget {
  const InspectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tenancy!;
    final locked = t.isSealed;
    final rooms = <String, List<InspectionItem>>{};
    for (final i in t.items) {
      rooms.putIfAbsent(i.room, () => []).add(i);
    }

    return PageFrame(
      title: 'Move-in inspection',
      subtitle: 'Tenancy from ${dateFmt.format(t.start)} · ${t.items.length} items',
      action: locked
          ? null
          : FilledButton.tonalIcon(
              onPressed: () => _addItemDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      children: [
        SealBanner(sealed: locked, intact: t.sealIntact),
        if (t.items.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No items yet. Add the things you want to protect.'))),
        for (final entry in rooms.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Card(
            child: Column(children: [
              for (final item in entry.value) _ItemTile(item: item, locked: locked),
            ]),
          ),
        ],
      ],
    );
  }

  Future<void> _addItemDialog(BuildContext context) async {
    final s = AppScope.of(context);
    final room = TextEditingController();
    final name = TextEditingController();
    final cost = TextEditingController();
    var cond = Condition.good;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add inspection item'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: room, decoration: const InputDecoration(labelText: 'Room (e.g. Kitchen)')),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Item (e.g. Fridge)')),
              const SizedBox(height: 12),
              TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Repair / replace cost (₹)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<Condition>(
                value: cond,
                decoration: const InputDecoration(labelText: 'Condition at move-in'),
                items: [
                  for (final c in Condition.values) DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setD(() => cond = v ?? cond),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final c = int.tryParse(cost.text.trim());
    if (ok == true && room.text.trim().isNotEmpty && name.text.trim().isNotEmpty && c != null) {
      s.addItem(InspectionItem(
          room: room.text.trim(), name: name.text.trim(), repairCost: c, moveIn: cond));
    } else if (ok == true && context.mounted) {
      toast(context, 'Please fill room, item and a numeric cost');
    }
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.locked});
  final InspectionItem item;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final inPhotos = item.photos.where((p) => p.stage == 'move-in').toList();
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: conditionColor(item.moveIn).withValues(alpha: 0.12),
        child: Icon(Icons.photo_library, color: conditionColor(item.moveIn), size: 20),
      ),
      title: Text(item.name),
      subtitle: Text('${inPhotos.length} photos · repair value ${inr(item.repairCost)}'),
      trailing: ConditionChip(item.moveIn),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in inPhotos) _Thumb(photo: p, bytes: s.photo(p.hash), intact: s.photoIntact(p)),
          if (!locked)
            OutlinedButton.icon(
              onPressed: () => capturePhoto(context, item, 'move-in'),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add photo'),
            ),
        ]),
        if (!locked)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => s.removeItem(item),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove item'),
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.bytes, required this.intact});
  final PhotoEvidence photo;
  final Uint8List? bytes;
  final bool intact;

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    return Tooltip(
      message: '${dateTimeFmt.format(photo.takenAt)}\nSHA-256 ${photo.hash.substring(0, 16)}…'
          '${b == null ? '' : intact ? '\nIntegrity OK' : '\nINTEGRITY FAILED'}',
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          image: b == null ? null : DecorationImage(image: MemoryImage(b), fit: BoxFit.cover),
        ),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(4),
        child: b == null
            ? const Center(child: Icon(Icons.image_outlined))
            : Icon(intact ? Icons.verified : Icons.gpp_bad,
                size: 16, color: intact ? Colors.greenAccent : Colors.redAccent),
      ),
    );
  }
}
