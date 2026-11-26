import 'package:flutter/material.dart';

import '../main.dart' show Logo;
import '../models.dart';
import '../state.dart';
import '../widgets/common.dart';

/// First-run screen: create a tenancy or explore with demo data.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _tenant = TextEditingController();
  final _landlord = TextEditingController();
  final _deposit = TextEditingController();
  final _rent = TextEditingController();
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);
  Role _role = Role.tenant;

  @override
  void dispose() {
    for (final c in [_address, _tenant, _landlord, _deposit, _rent]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _amount(String? v) {
    final n = int.tryParse((v ?? '').replaceAll(',', '').trim());
    return (n == null || n <= 0) ? 'Enter an amount in ₹' : null;
  }

  int _int(TextEditingController c) => int.parse(c.text.replaceAll(',', '').trim());

  void _create() {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.of(context);
    s.setRole(_role);
    s.createTenancy(Tenancy(
      address: _address.text.trim(),
      tenant: _tenant.text.trim(),
      landlord: _landlord.text.trim(),
      deposit: _int(_deposit),
      rent: _int(_rent),
      start: _start,
      items: defaultChecklist(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Logo(),
              const SizedBox(height: 24),
              Text('Protect your security deposit',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Record move-in evidence together, seal it with both signatures, '
                'and settle the deposit with clear, fair rules at move-out.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 24),
              Form(
                key: _form,
                child: Column(children: [
                  SegmentedButton<Role>(
                    segments: const [
                      ButtonSegment(value: Role.tenant, label: Text('I am the tenant'), icon: Icon(Icons.person)),
                      ButtonSegment(value: Role.landlord, label: Text('I am the landlord'), icon: Icon(Icons.home)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (v) => setState(() => _role = v.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _address,
                      validator: _required,
                      decoration: const InputDecoration(labelText: 'Property address')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _tenant,
                            validator: _required,
                            decoration: const InputDecoration(labelText: 'Tenant name'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _landlord,
                            validator: _required,
                            decoration: const InputDecoration(labelText: 'Landlord name'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _deposit,
                            validator: _amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Deposit (₹)'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _rent,
                            validator: _amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Monthly rent (₹)'))),
                  ]),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Tenancy start'),
                    subtitle: Text(dateFmt.format(_start)),
                    trailing: TextButton(
                      child: const Text('Change'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: _start,
                        );
                        if (d != null) setState(() => _start = d);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Create tenancy & checklist'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: s.loadDemo,
                    child: const Text('Just exploring? Load demo data'),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
