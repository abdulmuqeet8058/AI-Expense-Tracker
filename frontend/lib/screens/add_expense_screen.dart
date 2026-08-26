import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/api_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/category_chip.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();

  bool _isIncome = false;
  bool _saving = false;
  String? _category;
  String _payment = 'cash';
  DateTime _date = DateTime.now();
  Timer? _suggestionTimer;
  CategorizeResult? _suggestion;
  bool _suggesting = false;
  bool _manualCategory = false;

  @override
  void initState() {
    super.initState();
    _description.addListener(_scheduleSuggestion);
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _scheduleSuggestion() {
    _suggestionTimer?.cancel();
    final description = _description.text.trim();
    if (_isIncome || _manualCategory || description.length < 3) {
      if (mounted && description.length < 3) {
        setState(() => _suggestion = null);
      }
      return;
    }
    _suggestionTimer = Timer(const Duration(milliseconds: 550), () {
      _requestSuggestion(description);
    });
  }

  Future<void> _requestSuggestion(String description) async {
    if (!mounted || description != _description.text.trim()) return;
    setState(() => _suggesting = true);
    try {
      final result = await ref.read(apiClientProvider).categorize(
            description: description,
            amount: double.tryParse(_amount.text.trim()),
            paymentMethod: _payment,
            date: _date,
          );
      if (!mounted || description != _description.text.trim()) return;
      setState(() {
        _suggestion = result;
        _category = result.category;
        _suggesting = false;
      });
    } on ApiException {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    final description = _description.text.trim();
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount');
      return;
    }
    if (description.isEmpty) {
      _showMessage('Enter a short description');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(expensesProvider.notifier).add(
            amount: amount,
            description: description,
            category: _isIncome || _manualCategory
                ? (_category ?? 'Miscellaneous')
                : null,
            date: _date,
            paymentMethod: _payment,
            isIncome: _isIncome,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(authProvider).user?.currency ?? kDefaultCurrency;
    final theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Add transaction',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _TransactionType(
                  isIncome: _isIncome,
                  onChanged: (value) {
                    setState(() {
                      _isIncome = value;
                      if (!value) _manualCategory = false;
                    });
                    if (!value) _scheduleSuggestion();
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$currency ',
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Lunch at a restaurant',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (!_isIncome) ...[
                  const SizedBox(height: 12),
                  _AiSuggestion(
                    suggestion: _suggestion,
                    loading: _suggesting,
                    onSelect: (category) => setState(() {
                      _category = category;
                      _manualCategory = category != _suggestion?.category;
                    }),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Category',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCategories.length + (_isIncome ? 0 : 1),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      if (!_isIncome && index == 0) {
                        return FilterChip(
                          avatar: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('Auto AI'),
                          selected: !_manualCategory,
                          onSelected: (_) {
                            setState(() => _manualCategory = false);
                            _scheduleSuggestion();
                          },
                        );
                      }
                      final category = kCategories[index - (_isIncome ? 0 : 1)];
                      return CategoryChip(
                        category: category,
                        selected: category == _category,
                        onTap: () => setState(() {
                          _category = category;
                          _manualCategory = true;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(DateFormat('MMM d, yyyy').format(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _payment,
                        decoration: const InputDecoration(labelText: 'Payment'),
                        items: [
                          for (final method in kPaymentMethods)
                            DropdownMenuItem(
                              value: method,
                              child: Text(_titleCase(method)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _payment = value ?? 'cash'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _isIncome ? AppColors.income : AppColors.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isIncome ? 'Save income' : 'Save expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSuggestion extends StatelessWidget {
  const _AiSuggestion({
    required this.suggestion,
    required this.loading,
    required this.onSelect,
  });

  final CategorizeResult? suggestion;
  final bool loading;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading && suggestion == null) {
      return const Row(
        children: [
          SizedBox.square(
              dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('AI is choosing a category...'),
        ],
      );
    }
    final result = suggestion;
    if (result == null) {
      return Text(
        'Describe the expense and AI will categorize it automatically.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final label =
        result.modelMode == 'ml' ? 'Trained AI model' : 'Smart fallback';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$label: ${result.category}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${(result.confidence * 100).round()}%'),
            ],
          ),
          if (result.alternatives.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Other possibilities',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final alternative in result.alternatives)
                  ActionChip(
                    label: Text(
                        '${alternative.category} ${(alternative.confidence * 100).round()}%'),
                    onPressed: () => onSelect(alternative.category),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionType extends StatelessWidget {
  const _TransactionType({required this.isIncome, required this.onChanged});

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Expense'),
          icon: Icon(Icons.south_west_rounded),
        ),
        ButtonSegment(
          value: true,
          label: Text('Income'),
          icon: Icon(Icons.north_east_rounded),
        ),
      ],
      selected: {isIncome},
      onSelectionChanged: (values) => onChanged(values.first),
      showSelectedIcon: false,
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
