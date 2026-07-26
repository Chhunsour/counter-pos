import 'package:flutter/material.dart';

import '../config/env_config.dart';
import '../models/backend_test_item.dart';
import '../models/pos_category.dart';
import '../services/backend_api_service.dart';
import '../utils/currency.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/record_form.dart';
import '../widgets/records_list.dart';

const _ink = Color(0xFF17211D);
const _muted = Color(0xFF6D7772);
const _accent = Color(0xFFE86F3A);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.config,
    required this.configError,
    super.key,
  });

  final EnvConfig? config;
  final String? configError;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  BackendApiService? _api;
  ConnectionResult? _connection;
  List<BackendTestItem> _items = const [];
  List<PosCategory> _categories = const [];
  final Map<Object, int> _cart = {};
  final List<_Sale> _sales = [];
  bool _testing = false;
  bool _loading = false;
  bool _categoriesLoading = false;
  String? _connectionError;
  int? _connectionErrorStatus;
  Duration? _connectionErrorElapsed;
  String? _recordsError;
  String? _categoriesError;
  String _query = '';
  String _filter = 'all';
  Object? _categoryFilter;
  String _paymentMethod = 'Card';
  bool _showRiel = true;
  double _usdToKhrRate = defaultUsdToKhrRate;
  int _section = 0;

  static const _sections = [
    _NavItem('Register', Icons.point_of_sale_rounded),
    _NavItem('Orders', Icons.receipt_long_outlined),
    _NavItem('Products', Icons.inventory_2_outlined),
    _NavItem('Customers', Icons.people_alt_outlined),
    _NavItem('Reports', Icons.bar_chart_rounded),
    _NavItem('Settings', Icons.tune_rounded),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _api = BackendApiService(widget.config!);
      _testAndLoad();
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  Future<void> _testAndLoad() async {
    await _testConnection();
    if (_connection != null) {
      await Future.wait([_loadRecords(), _loadCategories()]);
    }
  }

  Future<void> _testConnection() async {
    final api = _api;
    if (api == null) return;
    setState(() {
      _testing = true;
      _connection = null;
      _connectionError = null;
      _connectionErrorStatus = null;
      _connectionErrorElapsed = null;
    });
    try {
      final result = await api.testConnection();
      if (mounted) setState(() => _connection = result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _connectionError = error.toString();
          _connectionErrorStatus = error.statusCode;
          _connectionErrorElapsed = error.elapsed;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _connectionError = error.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _loadRecords() async {
    final api = _api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _recordsError = null;
    });
    try {
      final items = await api.fetchItems();
      if (mounted) {
        setState(() {
          _items = items;
          _cart.removeWhere(
            (id, _) => !items.any((item) => item.id == id),
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => _recordsError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCategories() async {
    final api = _api;
    if (api == null) return;
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final categories = await api.fetchCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (error) {
      if (mounted) setState(() => _categoriesError = error.toString());
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _create(
    String title,
    String description,
    String status,
    String? imageName,
    String? imageData,
    String? barcode,
    Object? categoryId,
  ) async {
    await _api!.createItem(
      title: title,
      description: description,
      status: status,
      imageName: imageName,
      imageData: imageData,
      barcode: barcode,
      categoryId: categoryId,
    );
    await _loadRecords();
    _showSuccess('$title was added to the catalog.');
  }

  Future<void> _update(
    BackendTestItem item,
    String title,
    String description,
    String status,
    String? imageName,
    String? imageData,
    String? barcode,
    Object? categoryId,
  ) async {
    await _api!.updateItem(
      item.copyWith(
        title: title,
        description: description,
        status: status,
        imageName: imageName,
        imageData: imageData,
        barcode: barcode,
        categoryId: categoryId,
      ),
    );
    await _loadRecords();
    _showSuccess('$title was updated.');
  }

  Future<void> _createCategory(String name) async {
    try {
      await _api!.createCategory(name);
      await _loadCategories();
      _showSuccess('$name was added to categories.');
    } catch (error) {
      if (mounted) _showError(error.toString());
      rethrow;
    }
  }

  Future<void> _delete(BackendTestItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete “${item.title}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api!.deleteItem(item.id);
      await _loadRecords();
      _showSuccess('${item.title} was deleted.');
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _showEdit(BackendTestItem item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit product'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: RecordForm(
              initialItem: item,
              categories: _categories,
              onSubmit: (
                title,
                description,
                status,
                imageName,
                imageData,
                barcode,
                categoryId,
              ) async {
                await _update(
                  item,
                  title,
                  description,
                  status,
                  imageName,
                  imageData,
                  barcode,
                  categoryId,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _addToCart(BackendTestItem item) {
    if (item.status != 'active') return;
    setState(
        () => _cart.update(item.id, (value) => value + 1, ifAbsent: () => 1));
  }

  void _changeQuantity(Object id, int change) {
    setState(() {
      final next = (_cart[id] ?? 0) + change;
      if (next <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = next;
      }
    });
  }

  void _checkout() {
    if (_cart.isEmpty) return;
    final total = _cart.entries.fold<double>(0, (sum, entry) {
      final item = _items.where((item) => item.id == entry.key).firstOrNull;
      return sum + (item?.productPrice ?? 0) * entry.value;
    });
    final units = _cart.values.fold<int>(0, (sum, quantity) => sum + quantity);
    setState(() {
      _sales.insert(
        0,
        _Sale(
          number: 1000 + _sales.length + 1,
          createdAt: DateTime.now(),
          units: units,
          total: total,
          method: _paymentMethod,
        ),
      );
      _cart.clear();
    });
    _showSuccess(
      'Payment recorded · '
      '${formatDualCurrency(total, _usdToKhrRate, showRiel: _showRiel)}',
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final configError = widget.configError;
    final backendUrl = widget.config?.backendUri.toString() ?? 'Not configured';

    return Scaffold(
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: _ink,
              child: SafeArea(
                child: _NavigationPanel(
                  sections: _sections,
                  selected: _section,
                  onSelect: (index) {
                    Navigator.pop(context);
                    setState(() => _section = index);
                  },
                ),
              ),
            ),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              titleSpacing: 0,
              title: Row(
                children: [
                  const _BrandMark(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    _sections[_section].label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                _SyncIndicator(connected: _connection != null),
                const SizedBox(width: 12),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 224,
                child: ColoredBox(
                  color: _ink,
                  child: _NavigationPanel(
                    sections: _sections,
                    selected: _section,
                    onSelect: (index) => setState(() => _section = index),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (wide)
                    _DesktopTopBar(
                      section: _sections[_section].label,
                      connected: _connection != null,
                    ),
                  Expanded(
                    child: switch (_section) {
                      0 => _RegisterView(
                          items: _items,
                          categories: _categories,
                          loading: _loading,
                          error: configError ?? _recordsError,
                          query: _query,
                          filter: _filter,
                          categoryFilter: _categoryFilter,
                          cart: _cart,
                          paymentMethod: _paymentMethod,
                          showRiel: _showRiel,
                          usdToKhrRate: _usdToKhrRate,
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onCategoryChanged: (value) =>
                              setState(() => _categoryFilter = value),
                          onAdd: _addToCart,
                          onQuantityChanged: _changeQuantity,
                          onClear: () => setState(_cart.clear),
                          onPaymentChanged: (value) =>
                              setState(() => _paymentMethod = value),
                          onCheckout: _checkout,
                          onRefresh: _api == null ? null : _loadRecords,
                          onManageProducts: () => setState(() => _section = 2),
                        ),
                      1 => _OrdersView(
                          sales: _sales,
                          showRiel: _showRiel,
                          usdToKhrRate: _usdToKhrRate,
                        ),
                      2 => _ProductsView(
                          apiEnabled: _api != null,
                          items: _items,
                          categories: _categories,
                          categoriesLoading: _categoriesLoading,
                          categoriesError: _categoriesError,
                          loading: _loading,
                          error: configError ?? _recordsError,
                          onCreate: _create,
                          onCreateCategory: _createCategory,
                          onRefreshCategories:
                              _api == null ? null : _loadCategories,
                          onRefresh: _api == null ? null : _loadRecords,
                          onEdit: _showEdit,
                          onDelete: _delete,
                        ),
                      3 => const _EmptyFeature(
                          icon: Icons.person_add_alt_1_outlined,
                          eyebrow: 'Customer directory',
                          title: 'Keep regulars close',
                          message:
                              'Customer profiles will appear here after you add '
                              'a customer table in your migration.',
                        ),
                      4 => _ReportsView(
                          sales: _sales,
                          showRiel: _showRiel,
                          usdToKhrRate: _usdToKhrRate,
                        ),
                      _ => _SettingsView(
                          backendUrl: backendUrl,
                          testing: _testing,
                          result: _connection,
                          error: configError ?? _connectionError,
                          errorStatusCode: _connectionErrorStatus,
                          errorElapsed: _connectionErrorElapsed,
                          onTest: _api == null ? null : _testConnection,
                          showRiel: _showRiel,
                          usdToKhrRate: _usdToKhrRate,
                          onShowRielChanged: (value) =>
                              setState(() => _showRiel = value),
                          onRateChanged: (value) {
                            final rate = double.tryParse(value);
                            if (rate != null && rate > 0) {
                              setState(() => _usdToKhrRate = rate);
                            }
                          },
                        ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _BrandMark(),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'counter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'POS WORKSTATION',
                      style: TextStyle(
                        color: Color(0xFF9AA49F),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          ...List.generate(sections.length, (index) {
            final item = sections[index];
            final active = selected == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: active ? const Color(0xFF2A3731) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onSelect(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 21,
                          color:
                              active ? Colors.white : const Color(0xFFAEB6B2),
                        ),
                        const SizedBox(width: 13),
                        Text(
                          item.label,
                          style: TextStyle(
                            color:
                                active ? Colors.white : const Color(0xFFC0C6C3),
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (active) ...[
                          const Spacer(),
                          const SizedBox.square(
                            dimension: 7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF202C27),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFF4D9C9),
                  child: Text(
                    'C',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cashier',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Register 01',
                        style: TextStyle(
                          color: Color(0xFF98A39E),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz, color: Color(0xFF98A39E)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.section, required this.connected});

  final String section;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E1D8))),
      ),
      child: Row(
        children: [
          Text(
            section,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _SyncIndicator(connected: connected),
          const SizedBox(width: 12),
          const VerticalDivider(indent: 20, endIndent: 20),
          const SizedBox(width: 12),
          Text(
            _formatClock(DateTime.now()),
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView({
    required this.items,
    required this.categories,
    required this.loading,
    required this.error,
    required this.query,
    required this.filter,
    required this.categoryFilter,
    required this.cart,
    required this.paymentMethod,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onClear,
    required this.onPaymentChanged,
    required this.onCheckout,
    required this.onRefresh,
    required this.onManageProducts,
  });

  final List<BackendTestItem> items;
  final List<PosCategory> categories;
  final bool loading;
  final String? error;
  final String query;
  final String filter;
  final Object? categoryFilter;
  final Map<Object, int> cart;
  final String paymentMethod;
  final bool showRiel;
  final double usdToKhrRate;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<Object?> onCategoryChanged;
  final ValueChanged<BackendTestItem> onAdd;
  final void Function(Object id, int change) onQuantityChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onCheckout;
  final VoidCallback? onRefresh;
  final VoidCallback onManageProducts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final split = constraints.maxWidth >= 900;
          final catalog = _ProductCatalog(
            items: items,
            categories: categories,
            loading: loading,
            error: error,
            query: query,
            filter: filter,
            categoryFilter: categoryFilter,
            showRiel: showRiel,
            usdToKhrRate: usdToKhrRate,
            embedded: !split,
            onQueryChanged: onQueryChanged,
            onFilterChanged: onFilterChanged,
            onCategoryChanged: onCategoryChanged,
            onAdd: onAdd,
            onRefresh: onRefresh,
            onManageProducts: onManageProducts,
          );
          final ticket = _TicketPanel(
            items: items,
            cart: cart,
            paymentMethod: paymentMethod,
            showRiel: showRiel,
            usdToKhrRate: usdToKhrRate,
            onQuantityChanged: onQuantityChanged,
            onClear: onClear,
            onPaymentChanged: onPaymentChanged,
            onCheckout: onCheckout,
            compact: !split,
          );

          if (!split) {
            return ListView(
              children: [
                catalog,
                const SizedBox(height: 18),
                ticket,
                const SizedBox(height: 12),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: catalog),
              const SizedBox(width: 18),
              SizedBox(width: 372, child: ticket),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCatalog extends StatelessWidget {
  const _ProductCatalog({
    required this.items,
    required this.categories,
    required this.loading,
    required this.error,
    required this.query,
    required this.filter,
    required this.categoryFilter,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.embedded,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.onRefresh,
    required this.onManageProducts,
  });

  final List<BackendTestItem> items;
  final List<PosCategory> categories;
  final bool loading;
  final String? error;
  final String query;
  final String filter;
  final Object? categoryFilter;
  final bool showRiel;
  final double usdToKhrRate;
  final bool embedded;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<Object?> onCategoryChanged;
  final ValueChanged<BackendTestItem> onAdd;
  final VoidCallback? onRefresh;
  final VoidCallback onManageProducts;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final visible = items.where((item) {
      final matchesQuery = normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery) ||
          (item.barcode?.contains(normalizedQuery) ?? false);
      final matchesFilter = filter == 'all' || item.status == filter;
      final matchesCategory =
          categoryFilter == null || item.categoryId == categoryFilter;
      return matchesQuery && matchesFilter && matchesCategory;
    }).toList();

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose products',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${visible.length} shown · tap an item to add it',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: _muted),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Refresh products',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search products or scan a barcode',
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: Icon(Icons.qr_code_scanner_rounded),
          ),
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterButton(
                label: 'All items',
                selected: filter == 'all',
                onTap: () => onFilterChanged('all'),
              ),
              _FilterButton(
                label: 'Available',
                selected: filter == 'active',
                onTap: () => onFilterChanged('active'),
              ),
              _FilterButton(
                label: 'Drafts',
                selected: filter == 'pending',
                onTap: () => onFilterChanged('pending'),
              ),
              _FilterButton(
                label: 'Hidden',
                selected: filter == 'inactive',
                onTap: () => onFilterChanged('inactive'),
              ),
            ],
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterButton(
                  label: 'All categories',
                  selected: categoryFilter == null,
                  onTap: () => onCategoryChanged(null),
                ),
                ...categories.map(
                  (category) => _FilterButton(
                    label: category.name,
                    selected: categoryFilter == category.id,
                    onTap: () => onCategoryChanged(category.id),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );

    Widget content;
    if (loading) {
      content = const _LoadingProducts();
    } else if (error != null) {
      content = _CatalogMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Products could not load',
        message: error!,
        actionLabel: 'Try again',
        onAction: onRefresh,
      );
    } else if (items.isEmpty) {
      content = _CatalogMessage(
        icon: Icons.inventory_2_outlined,
        title: 'Your catalog is empty',
        message: 'Add products, prices, and images when you are ready.',
        actionLabel: 'Manage products',
        onAction: onManageProducts,
      );
    } else if (visible.isEmpty) {
      content = const _CatalogMessage(
        icon: Icons.search_off_rounded,
        title: 'No matching products',
        message: 'Try a different search or availability filter.',
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 610
                  ? 3
                  : constraints.maxWidth >= 360
                      ? 2
                      : 1;
          return GridView.builder(
            shrinkWrap: embedded,
            physics: embedded ? const NeverScrollableScrollPhysics() : null,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final item = visible[index];
              return _ProductTile(
                item: item,
                showRiel: showRiel,
                usdToKhrRate: usdToKhrRate,
                categoryName: categories
                    .where((category) => category.id == item.categoryId)
                    .firstOrNull
                    ?.name,
                onTap: item.status == 'active' ? () => onAdd(item) : null,
              );
            },
          );
        },
      );
    }

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, content],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, Expanded(child: content)],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.item,
    required this.categoryName,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.onTap,
  });

  final BackendTestItem item;
  final String? categoryName;
  final bool showRiel;
  final double usdToKhrRate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageBytes = item.imageBytes;
    final available = onTap != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: const Color(0xFFE9E6DF),
                        child: imageBytes == null
                            ? Icon(
                                Icons.local_cafe_outlined,
                                size: 42,
                                color: _ink.withValues(alpha: 0.32),
                              )
                            : Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: _muted,
                                ),
                              ),
                      ),
                    ),
                    if (!available)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _ink.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            color: _ink,
                            child: Text(
                              item.status == 'pending' ? 'DRAFT' : 'HIDDEN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              if (categoryName != null) ...[
                Text(
                  categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDualCurrency(
                        item.productPrice,
                        usdToKhrRate,
                        showRiel: showRiel,
                      ),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: available ? _ink : const Color(0xFFE6E2D9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: available ? Colors.white : _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketPanel extends StatelessWidget {
  const _TicketPanel({
    required this.items,
    required this.cart,
    required this.paymentMethod,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.onQuantityChanged,
    required this.onClear,
    required this.onPaymentChanged,
    required this.onCheckout,
    required this.compact,
  });

  final List<BackendTestItem> items;
  final Map<Object, int> cart;
  final String paymentMethod;
  final bool showRiel;
  final double usdToKhrRate;
  final void Function(Object id, int change) onQuantityChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onCheckout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lines = cart.entries
        .map((entry) {
          final item = items.where((item) => item.id == entry.key).firstOrNull;
          return item == null
              ? null
              : _CartLine(item: item, quantity: entry.value);
        })
        .whereType<_CartLine>()
        .toList();
    final subtotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.item.productPrice * line.quantity,
    );
    final units = lines.fold<int>(0, (sum, line) => sum + line.quantity);

    return SizedBox(
      height: compact ? 620 : null,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current order',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Order #${1000 + units}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: lines.isEmpty ? null : onClear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: lines.isEmpty
                    ? const _EmptyTicket()
                    : ListView.separated(
                        itemCount: lines.length,
                        separatorBuilder: (_, __) => const Divider(height: 22),
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          return _TicketLine(
                            item: line.item,
                            quantity: line.quantity,
                            showRiel: showRiel,
                            usdToKhrRate: usdToKhrRate,
                            onDecrease: () =>
                                onQuantityChanged(line.item.id, -1),
                            onIncrease: () =>
                                onQuantityChanged(line.item.id, 1),
                          );
                        },
                      ),
              ),
              const Divider(height: 24),
              _AmountRow(
                label: 'Subtotal',
                value: subtotal,
                showRiel: showRiel,
                usdToKhrRate: usdToKhrRate,
              ),
              const SizedBox(height: 8),
              _AmountRow(
                label: 'Tax',
                value: 0,
                showRiel: showRiel,
                usdToKhrRate: usdToKhrRate,
              ),
              const SizedBox(height: 10),
              _AmountRow(
                label: 'Total',
                value: subtotal,
                showRiel: showRiel,
                usdToKhrRate: usdToKhrRate,
                total: true,
              ),
              const SizedBox(height: 15),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Cash',
                    icon: Icon(Icons.payments_outlined, size: 18),
                    label: Text('Cash'),
                  ),
                  ButtonSegment(
                    value: 'Card',
                    icon: Icon(Icons.credit_card_rounded, size: 18),
                    label: Text('Card'),
                  ),
                  ButtonSegment(
                    value: 'Split',
                    icon: Icon(Icons.call_split_rounded, size: 18),
                    label: Text('Split'),
                  ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (values) => onPaymentChanged(values.single),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: lines.isEmpty ? null : onCheckout,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Charge ${formatDualCurrency(
                        subtotal,
                        usdToKhrRate,
                        showRiel: showRiel,
                      )}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({
    required this.item,
    required this.quantity,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.onDecrease,
    required this.onIncrease,
  });

  final BackendTestItem item;
  final int quantity;
  final bool showRiel;
  final double usdToKhrRate;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox.square(
            dimension: 48,
            child: ColoredBox(
              color: const Color(0xFFE9E6DF),
              child: item.imageBytes == null
                  ? const Icon(Icons.local_cafe_outlined, color: _muted)
                  : Image.memory(item.imageBytes!, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                formatDualCurrency(
                  item.productPrice,
                  usdToKhrRate,
                  showRiel: showRiel,
                ),
                style: const TextStyle(
                  color: _muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        _QuantityButton(icon: Icons.remove, onPressed: onDecrease),
        SizedBox(
          width: 30,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _QuantityButton(icon: Icons.add, onPressed: onIncrease),
      ],
    );
  }
}

class _ProductsView extends StatelessWidget {
  const _ProductsView({
    required this.apiEnabled,
    required this.items,
    required this.categories,
    required this.categoriesLoading,
    required this.categoriesError,
    required this.loading,
    required this.error,
    required this.onCreate,
    required this.onCreateCategory,
    required this.onRefreshCategories,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final bool apiEnabled;
  final List<BackendTestItem> items;
  final List<PosCategory> categories;
  final bool categoriesLoading;
  final String? categoriesError;
  final bool loading;
  final String? error;
  final RecordSubmit onCreate;
  final Future<void> Function(String name) onCreateCategory;
  final VoidCallback? onRefreshCategories;
  final VoidCallback? onRefresh;
  final ValueChanged<BackendTestItem> onEdit;
  final ValueChanged<BackendTestItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeading(
            eyebrow: 'Catalog',
            title: 'Products',
            message:
                'Add products here, then mark them available to sell at the register.',
          ),
          const SizedBox(height: 20),
          _CategoryManager(
            categories: categories,
            loading: categoriesLoading,
            error: categoriesError,
            enabled: apiEnabled,
            onCreate: onCreateCategory,
            onRefresh: onRefreshCategories,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final form = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add a product',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (!apiEnabled)
                        const Text(
                          'Configure the backend in .env to add products.',
                        )
                      else
                        RecordForm(
                          categories: categories,
                          onSubmit: onCreate,
                        ),
                    ],
                  ),
                ),
              );
              final records = RecordsList(
                items: items,
                loading: loading,
                error: error,
                onRefresh: onRefresh,
                onEdit: onEdit,
                onDelete: onDelete,
              );
              if (constraints.maxWidth < 860) {
                return Column(
                  children: [form, const SizedBox(height: 16), records],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: form),
                  const SizedBox(width: 16),
                  Expanded(child: records),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryManager extends StatefulWidget {
  const _CategoryManager({
    required this.categories,
    required this.loading,
    required this.error,
    required this.enabled,
    required this.onCreate,
    required this.onRefresh,
  });

  final List<PosCategory> categories;
  final bool loading;
  final String? error;
  final bool enabled;
  final Future<void> Function(String name) onCreate;
  final VoidCallback? onRefresh;

  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onCreate(name);
      _controller.clear();
    } catch (_) {
      // The dashboard already shows the backend error.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh categories',
                  onPressed: widget.loading ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Create categories here before assigning them to products.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled && !_saving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _create(),
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                      hintText: 'Example: Drinks',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: widget.enabled && !_saving ? _create : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Create'),
                ),
              ],
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Run migrations/002_add_barcodes_and_categories.sql first.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories
                    .map(
                      (category) => Chip(
                        avatar: const Icon(
                          Icons.sell_outlined,
                          size: 17,
                        ),
                        label: Text(category.name),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView({
    required this.sales,
    required this.showRiel,
    required this.usdToKhrRate,
  });

  final List<_Sale> sales;
  final bool showRiel;
  final double usdToKhrRate;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeading(
            eyebrow: 'Sales activity',
            title: 'Orders',
            message: 'Completed sales from this register session appear here.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: sales.isEmpty
                  ? const _InlineEmpty(
                      icon: Icons.receipt_long_outlined,
                      title: 'No completed orders yet',
                      message: 'Complete a payment at the register to start.',
                    )
                  : Column(
                      children: [
                        for (final sale in sales) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1E9E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.receipt_outlined,
                                color: _accent,
                              ),
                            ),
                            title: Text(
                              'Order #${sale.number}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${sale.units} items · ${sale.method} · '
                              '${_formatClock(sale.createdAt)}',
                            ),
                            trailing: Text(
                              formatDualCurrency(
                                sale.total,
                                usdToKhrRate,
                                showRiel: showRiel,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          if (sale != sales.last) const Divider(),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView({
    required this.sales,
    required this.showRiel,
    required this.usdToKhrRate,
  });

  final List<_Sale> sales;
  final bool showRiel;
  final double usdToKhrRate;

  @override
  Widget build(BuildContext context) {
    final revenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final units = sales.fold<int>(0, (sum, sale) => sum + sale.units);
    final average = sales.isEmpty ? 0.0 : revenue / sales.length;

    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeading(
            eyebrow: 'This register session',
            title: 'Sales snapshot',
            message:
                'A quick view of payments completed since this app opened.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                label: 'Net sales',
                value: formatDualCurrency(
                  revenue,
                  usdToKhrRate,
                  showRiel: showRiel,
                ),
                icon: Icons.trending_up_rounded,
              ),
              _MetricCard(
                label: 'Orders',
                value: '${sales.length}',
                icon: Icons.receipt_long_outlined,
              ),
              _MetricCard(
                label: 'Items sold',
                value: '$units',
                icon: Icons.shopping_bag_outlined,
              ),
              _MetricCard(
                label: 'Average order',
                value: formatDualCurrency(
                  average,
                  usdToKhrRate,
                  showRiel: showRiel,
                ),
                icon: Icons.pie_chart_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: _InlineEmpty(
                icon: Icons.query_stats_rounded,
                title: 'Detailed reports need order storage',
                message:
                    'Add order and line-item tables in your migration to keep '
                    'sales after this session ends.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.backendUrl,
    required this.testing,
    required this.result,
    required this.error,
    required this.errorStatusCode,
    required this.errorElapsed,
    required this.onTest,
    required this.showRiel,
    required this.usdToKhrRate,
    required this.onShowRielChanged,
    required this.onRateChanged,
  });

  final String backendUrl;
  final bool testing;
  final ConnectionResult? result;
  final String? error;
  final int? errorStatusCode;
  final Duration? errorElapsed;
  final VoidCallback? onTest;
  final bool showRiel;
  final double usdToKhrRate;
  final ValueChanged<bool> onShowRielChanged;
  final ValueChanged<String> onRateChanged;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageHeading(
            eyebrow: 'Workspace',
            title: 'Settings',
            message: 'Check the connection used for product data.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Khmer riel'),
                    subtitle: const Text(
                      'Display KHR beside every existing USD price.',
                    ),
                    value: showRiel,
                    onChanged: onShowRielChanged,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: usdToKhrRate.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    enabled: showRiel,
                    onChanged: onRateChanged,
                    decoration: const InputDecoration(
                      labelText: 'Exchange rate',
                      prefixText: '1 USD = ',
                      suffixText: 'KHR',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConnectionStatusCard(
            backendUrl: backendUrl,
            testing: testing,
            result: result,
            error: error,
            errorStatusCode: errorStatusCode,
            errorElapsed: errorElapsed,
            onTest: onTest,
          ),
        ],
      ),
    );
  }
}

class _EmptyFeature extends StatelessWidget {
  const _EmptyFeature({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeading(eyebrow: eyebrow, title: title, message: message),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 68, horizontal: 24),
              child: _InlineEmpty(
                icon: icon,
                title: 'Ready for your data',
                message:
                    'The workspace is designed. Connect it when your migration is ready.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: _accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _muted),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _accent),
              const SizedBox(height: 22),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _ink,
        backgroundColor: const Color(0xFFFFFEFB),
        side: BorderSide(
          color: selected ? _ink : const Color(0xFFDCD7CE),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : _ink,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF0EDE6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.showRiel,
    required this.usdToKhrRate,
    this.total = false,
  });

  final String label;
  final double value;
  final bool showRiel;
  final double usdToKhrRate;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: total ? _ink : _muted,
            fontSize: total ? 17 : 13,
            fontWeight: total ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          formatDualCurrency(
            value,
            usdToKhrRate,
            showRiel: showRiel,
          ),
          style: TextStyle(
            color: _ink,
            fontSize: total ? 22 : 14,
            fontWeight: total ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE8F1EB) : const Color(0xFFF0EDE6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: connected ? const Color(0xFF4E7C60) : _muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            connected ? 'Synced' : 'Offline',
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.point_of_sale_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _EmptyTicket extends StatelessWidget {
  const _EmptyTicket();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 46,
              color: Color(0xFFB2B8B5),
            ),
            SizedBox(height: 12),
            Text(
              'This order is empty',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Choose a product to begin.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: const Color(0xFFA8AFAB)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: _muted),
        ),
      ],
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        child: Column(
          children: [
            _InlineEmpty(icon: icon, title: title, message: message),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingProducts extends StatelessWidget {
  const _LoadingProducts();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE7E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 13, color: const Color(0xFFEAE7E0)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 70,
                  height: 12,
                  color: const Color(0xFFEAE7E0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _CartLine {
  const _CartLine({required this.item, required this.quantity});

  final BackendTestItem item;
  final int quantity;
}

class _Sale {
  const _Sale({
    required this.number,
    required this.createdAt,
    required this.units,
    required this.total,
    required this.method,
  });

  final int number;
  final DateTime createdAt;
  final int units;
  final double total;
  final String method;
}

String _formatClock(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
