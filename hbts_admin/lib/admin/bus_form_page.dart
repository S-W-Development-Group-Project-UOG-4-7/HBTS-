import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_theme.dart';

class BusFormPage extends StatefulWidget {
  const BusFormPage({super.key, this.bus});

  final Map<String, dynamic>? bus;

  @override
  State<BusFormPage> createState() => _BusFormPageState();
}

class _BusFormPageState extends State<BusFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _operatorIdCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serviceTypeCtrl = TextEditingController();

  List<Map<String, dynamic>> _operators = [];
  List<Map<String, dynamic>> _routes = [];
  List<String> _serviceTypes = [];

  bool _loadingOperators = false;
  bool _loadingRoutes = false;
  bool _loadingServiceTypes = false;

  int? _selectedOperatorId;
  String? _selectedRouteCode;
  String? _selectedServiceType;

  List<Map<String, dynamic>> _conductors = [];
  bool _loadingConductors = false;
  int? _selectedConductorId;

  bool _saving = false;

  int? get _busId {
    final bus = widget.bus;
    if (bus == null) return null;
    final raw = bus["bus_id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  @override
  void initState() {
    super.initState();
    final bus = widget.bus;
    if (bus != null) {
      _operatorIdCtrl.text =
          bus["operator_user_id"]?.toString() ??
          bus["operator_id"]?.toString() ??
          "";
      _plateCtrl.text = bus["license_plate_no"]?.toString() ?? "";
      _routeCtrl.text = bus["route_no"]?.toString() ?? "";
      _capacityCtrl.text = bus["capacity"]?.toString() ?? "";
      _modelCtrl.text = bus["model"]?.toString() ?? "";
      _serviceTypeCtrl.text = bus["service_type"]?.toString() ?? "";

      _selectedOperatorId = _parseInt(_operatorIdCtrl.text);
      _selectedRouteCode = _routeCtrl.text.trim().isEmpty
          ? null
          : _routeCtrl.text.trim();
      _selectedServiceType = _serviceTypeCtrl.text.trim().isEmpty
          ? null
          : _serviceTypeCtrl.text.trim();
    }
    _loadOperators();
    _loadRoutes();
    _loadServiceTypes();
    _loadConductors();
  }

  @override
  void dispose() {
    _operatorIdCtrl.dispose();
    _plateCtrl.dispose();
    _routeCtrl.dispose();
    _capacityCtrl.dispose();
    _modelCtrl.dispose();
    _serviceTypeCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  String _safeText(dynamic v) {
    final text = v?.toString().trim();
    return (text == null || text.isEmpty) ? "-" : text;
  }

  int? _operatorIdFromMap(Map<String, dynamic> op) {
    return _toInt(op["user_id"] ?? op["id"] ?? op["operator_id"]);
  }

  int? _operatorCompanyIdFromMap(Map<String, dynamic> op) {
    return _toInt(
      op["operator_id"] ?? op["company_id"] ?? op["companyId"],
    );
  }

  int? _selectedOperatorCompanyId() {
    final selected = _selectedOperatorId;
    if (selected == null) return null;
    final match = _operators.cast<Map<String, dynamic>>().firstWhere(
          (o) => _operatorIdFromMap(o) == selected,
          orElse: () => {},
        );
    if (match.isEmpty) return null;
    return _operatorCompanyIdFromMap(match);
  }

  List<Map<String, dynamic>> _filteredConductors() {
    final companyId = _selectedOperatorCompanyId();
    if (companyId == null) return _conductors;
    return _conductors
        .where((c) => _toInt(c["operator_id"] ?? c["company_id"]) == companyId)
        .toList();
  }

  String _operatorLabel(Map<String, dynamic> op) {
    final id = _operatorIdFromMap(op);
    final name = _safeText(op["name"]);
    final company =
        _safeText(op["company"] ?? op["company_name"] ?? op["operator_name"]);
    if (company != "-") {
      return "$name - $company (ID: ${id ?? "-"})";
    }
    return "$name (ID: ${id ?? "-"})";
  }

  String _routeCode(Map<String, dynamic> route) {
    return _safeText(
      route["route_no"] ??
          route["route_number"] ??
          route["route_code"] ??
          route["code"] ??
          route["routeId"] ??
          route["route_id"] ??
          route["id"],
    );
  }

  String _routeLabel(Map<String, dynamic> route) {
    final code = _routeCode(route);
    final name = _safeText(
      route["route_name"] ?? route["name"] ?? route["routeName"],
    );
    final origin = _safeText(
      route["origin"] ?? route["start"] ?? route["start_point"],
    );
    final destination = _safeText(
      route["destination"] ?? route["end"] ?? route["end_point"],
    );

    final hasName = name != "-";
    final hasRoute = origin != "-" && destination != "-";
    final parts = <String>[
      if (code != "-") code,
      if (hasName) name,
      if (hasRoute) "$origin -> $destination",
    ];
    return parts.isEmpty ? "Route" : parts.join(" | ");
  }

  Future<void> _loadOperators() async {
    setState(() => _loadingOperators = true);
    try {
      final data = await AdminApi.getOperators();
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      final selected = _selectedOperatorId ?? _parseInt(_operatorIdCtrl.text);
      final hasSelected = selected != null &&
          list.any((o) => _operatorIdFromMap(o) == selected);
      setState(() {
        _operators = list;
        if (_selectedOperatorId == null) {
          _selectedOperatorId = hasSelected ? selected : null;
        } else if (!hasSelected) {
          _selectedOperatorId = null;
        }
        if (_selectedOperatorId == null) {
          _operatorIdCtrl.text = "";
        }
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingOperators = false);
    }
  }

  Future<void> _loadRoutes() async {
    setState(() => _loadingRoutes = true);
    try {
      final data = await AdminApi.getRoutes();
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      setState(() {
        _routes = list;
        if (_selectedRouteCode == null) {
          final text = _routeCtrl.text.trim();
          _selectedRouteCode = text.isEmpty ? null : text;
        }
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _loadServiceTypes() async {
    setState(() => _loadingServiceTypes = true);
    try {
      final data = await AdminApi.getBuses();
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      final types = <String>{};
      for (final bus in list) {
        final raw = bus["service_type"] ?? bus["serviceType"];
        final text = raw?.toString().trim();
        if (text != null && text.isNotEmpty && text != "-") {
          types.add(text);
        }
      }
      final current = _serviceTypeCtrl.text.trim();
      if (current.isNotEmpty) types.add(current);
      final sorted = types.toList()..sort();
      setState(() {
        _serviceTypes = sorted;
        if (_selectedServiceType == null) {
          _selectedServiceType = current.isEmpty ? null : current;
        }
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingServiceTypes = false);
    }
  }

  Future<void> _loadConductors() async {
    setState(() => _loadingConductors = true);
    try {
      final data = await AdminApi.getConductors();
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      int? selected;
      final busId = _busId;
      if (busId != null) {
        final match = list.firstWhere(
          (c) => _toInt(c["bus_id"]) == busId,
          orElse: () => {},
        );
        selected = _toInt(match["conductor_id"] ?? match["id"]);
      }
      setState(() {
        _conductors = list;
        _selectedConductorId = selected;
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingConductors = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "operatorId": _selectedOperatorId ??
          (_operators.isEmpty ? _parseInt(_operatorIdCtrl.text) : null),
      "conductorId": _selectedConductorId,
      "licensePlateNo": _plateCtrl.text.trim(),
      "routeNo": _selectedRouteCode ?? _routeCtrl.text.trim(),
      "capacity": _parseInt(_capacityCtrl.text),
      "model": _modelCtrl.text.trim(),
      "serviceType": _selectedServiceType ?? _serviceTypeCtrl.text.trim(),
    };
  }

  Future<void> _addRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.addBus(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus added")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRecord() async {
    final busId = _busId;
    if (busId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminApi.updateBus(busId, _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus updated")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecord() async {
    final busId = _busId;
    if (busId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete bus?"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await AdminApi.deleteBus(busId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bus deleted")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _busId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Bus" : "Add Bus Record"),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isEdit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      "Bus ID: ${_busId ?? "-"}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (_operators.isEmpty)
                  _field(
                    label: "Operator ID",
                    controller: _operatorIdCtrl,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_parseInt(value ?? "") == null) {
                        return "Operator is required";
                      }
                      return null;
                    },
                  ),
                if (_operators.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _selectedOperatorId,
                    items: (() {
                      final seen = <int?>{};
                      final items = <DropdownMenuItem<int?>>[];
                      final selected = _selectedOperatorId;
                      if (selected != null) {
                        final exists = _operators.any(
                          (o) => _operatorIdFromMap(o) == selected,
                        );
                        if (!exists) {
                          seen.add(selected);
                          items.add(
                            DropdownMenuItem<int?>(
                              value: selected,
                              child: Text("Current: $selected"),
                            ),
                          );
                        }
                      }
                      for (final o in _operators) {
                        final id = _operatorIdFromMap(o);
                        if (seen.contains(id)) continue;
                        seen.add(id);
                        items.add(
                          DropdownMenuItem<int?>(
                            value: id,
                            child: Text(_operatorLabel(o)),
                          ),
                        );
                      }
                      return items;
                    })(),
                    onChanged: (value) {
                      setState(() {
                        _selectedOperatorId = value;
                        _operatorIdCtrl.text = value?.toString() ?? "";
                        final allowed = _filteredConductors();
                        final current = _selectedConductorId;
                        if (current != null &&
                            !allowed.any(
                              (c) =>
                                  _toInt(c["conductor_id"] ?? c["id"]) ==
                                  current,
                            )) {
                          _selectedConductorId = null;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Operator",
                    ),
                    validator: (value) {
                      if (value == null) return "Operator is required";
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _field(
                  label: "License Plate Number",
                  controller: _plateCtrl,
                  validator: (value) =>
                      (value ?? "").trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 12),
                if (_routes.isEmpty)
                  _field(
                    label: "Route",
                    controller: _routeCtrl,
                  )
                else
                  DropdownButtonFormField<String?>(
                    value: _selectedRouteCode,
                    items: [
                      if (_selectedRouteCode != null &&
                          !_routes.any(
                            (r) => _routeCode(r) == _selectedRouteCode,
                          ))
                        DropdownMenuItem<String?>(
                          value: _selectedRouteCode,
                          child: Text("Current: $_selectedRouteCode"),
                        ),
                      ..._routes.map(
                        (r) => DropdownMenuItem<String?>(
                          value: _routeCode(r),
                          child: Text(_routeLabel(r)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRouteCode = value;
                        _routeCtrl.text = value ?? "";
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Route",
                    ),
                  ),
                const SizedBox(height: 12),
                _field(
                  label: "Capacity",
                  controller: _capacityCtrl,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if ((value ?? "").trim().isEmpty) return null;
                    if (_parseInt(value!) == null) {
                      return "Capacity must be a number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  label: "Model",
                  controller: _modelCtrl,
                ),
                const SizedBox(height: 12),
                if (_serviceTypes.isEmpty)
                  _field(
                    label: "Service Type",
                    controller: _serviceTypeCtrl,
                  )
                else
                  DropdownButtonFormField<String?>(
                    value: _selectedServiceType,
                    items: [
                      if (_selectedServiceType != null &&
                          !_serviceTypes.contains(_selectedServiceType))
                        DropdownMenuItem<String?>(
                          value: _selectedServiceType,
                          child: Text("Current: $_selectedServiceType"),
                        ),
                      ..._serviceTypes.map(
                        (t) => DropdownMenuItem<String?>(
                          value: t,
                          child: Text(t),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedServiceType = value;
                        _serviceTypeCtrl.text = value ?? "";
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Service Type",
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedConductorId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("No Conductor"),
                    ),
                    ..._filteredConductors().map(
                      (c) => DropdownMenuItem<int?>(
                        value: _toInt(c["conductor_id"] ?? c["id"]),
                        child: Text(
                          "${c["name"] ?? "Conductor"} (ID: ${_toInt(c["conductor_id"] ?? c["id"]) ?? "-"})",
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedConductorId = value);
                  },
                  decoration: const InputDecoration(
                    labelText: "Assign Conductor",
                  ),
                  validator: (value) {
                    if (value == null) return "Conductor is required";
                    return null;
                  },
                ),
                if (_loadingConductors)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_loadingOperators || _loadingRoutes || _loadingServiceTypes)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 18),
                if (!isEdit)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _addRecord,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("Add Record"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                if (isEdit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _updateRecord,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text("Update"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _deleteRecord,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text("Delete"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
