// ignore_for_file: unused_field, use_build_context_synchronously, unnecessary_underscores, prefer_final_fields

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_manager.dart';
import '../core/app_config.dart';
import '../core/brand_footer.dart';
import '../core/models/invoice_line.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../models/company_bank_account.dart';
import '../models/company_info.dart';
import '../services/billing_service.dart';
import '../services/company_info_service.dart';
import '../services/mission_service.dart';

import '../utils/pdf_download_helper_stub.dart'
    if (dart.library.html) '../utils/pdf_download_helper_web.dart';
import '../widgets/client_autocomplete_field.dart';

/*
		final headerChips = <Widget>[
			),
			if (missionRef != null && missionRef.trim().isNotEmpty)
				Container(
					padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
					decoration: BoxDecoration(color: const Color(0xFFE8EEFF), borderRadius: BorderRadius.circular(999)),
					child: Text('Mission $missionRef', style: const TextStyle(color: Color(0xFF000091), fontWeight: FontWeight.w700, fontSize: 12)),
				),
			Container(
				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
				decoration: BoxDecoration(color: isLocked ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
				child: Text(_invoiceStatusLabelFor(invoice), style: TextStyle(color: isLocked ? const Color(0xFF92400E) : const Color(0xFF166534), fontWeight: FontWeight.w700, fontSize: 12)),
			),
		];

												],
											),
											const SizedBox(height: 12),
											Wrap(spacing: 8, runSpacing: 8, children: headerChips),
										],
									),
								),
								Expanded(
									child: Padding(
										padding: EdgeInsets.fromLTRB(spacing, 18, spacing, spacing),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text('Pilotage', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
												const SizedBox(height: 10),
												Container(
													padding: const EdgeInsets.all(14),
													decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text('Statut de la facture', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF6B7280))),
															const SizedBox(height: 6),
															_invoiceStatusDropdown(invoice, compact: false),
														],
													),
												),
												const SizedBox(height: 14),
												Row(
													children: [
														Expanded(
															child: Container(
																padding: const EdgeInsets.all(14),
																decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
																child: Column(
																	crossAxisAlignment: CrossAxisAlignment.start,
																	children: [
																		Text(missionRef == null || missionRef.isEmpty ? 'Total HT' : 'Sous-total mission', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
																		const SizedBox(height: 6),
																		Text(_formatCurrency(totalHt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF000091))),
																	],
																),
															),
														),
														const SizedBox(width: 12),
														Expanded(
															child: Container(
																padding: const EdgeInsets.all(14),
																decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
																child: Column(
																	crossAxisAlignment: CrossAxisAlignment.start,
																	children: [
																		const Text('Total facture', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
																		const SizedBox(height: 6),
																		Text(_formatCurrency(invoice.invoiceTotalHt > 0 ? invoice.invoiceTotalHt : invoice.amountHt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
																	],
																),
															),
														),
													],
												),
												const SizedBox(height: 18),
												Row(
													children: [
														Expanded(child: Text('Lignes de la mission', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
														Text('${lines.length} ligne(s)', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
													],
												),
												const SizedBox(height: 8),
												...detailActions,
												Expanded(child: linesContent),
											],
										),
									),
								),
							],
						),
					),
				),
			),
		);
									),
								IconButton(
									icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
									onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
									tooltip: collapsed ? 'Déplier la navigation' : 'Réduire la navigation',
								),
							],
						),
					),
					const Divider(height: 1, color: Color(0xFFE5E7EB)),
					Expanded(
						child: ListView(
							padding: const EdgeInsets.symmetric(vertical: 8),
							children: [
								_SidebarEntry(
									icon: Icons.description_outlined,
									label: 'Préparation',
									selected: _activeSection == BillingSection.creation,
									onTap: () => _setActiveSection(BillingSection.creation),
									collapsed: collapsed,
								),
								_SidebarEntry(
									icon: Icons.receipt_long_outlined,
									label: 'Factures',
									selected: _activeSection == BillingSection.invoices,
									onTap: () => _setActiveSection(BillingSection.invoices),
									collapsed: collapsed,
								),
							],
						),
					),
					const Divider(height: 1, color: Color(0xFFE5E7EB)),
					Padding(
						padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 16),
						child: Column(
							crossAxisAlignment: collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
							children: [
								if (!collapsed) ...[
									const Text('Détail des lignes de facturation', style: TextStyle(fontWeight: FontWeight.w600)),
									const SizedBox(height: 4),
								],
								Text('${_lineEditors.length} ligne(s)', style: const TextStyle(fontWeight: FontWeight.w700)),
								const SizedBox(height: 8),
								if (collapsed)
									IconButton(
										icon: Icon(_isTableFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
										onPressed: _lineEditors.isEmpty ? null : () => _toggleTableFullscreen(!_isTableFullscreen),
										tooltip: _isTableFullscreen ? 'Quitter le plein écran' : 'Afficher en plein écran',
									)
								else
									OutlinedButton.icon(
										onPressed: _lineEditors.isEmpty ? null : () => _toggleTableFullscreen(!_isTableFullscreen),
										icon: Icon(_isTableFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
										label: Text(_isTableFullscreen ? 'Quitter le plein écran' : 'Voir en plein écran'),
									),
							],
						),
					),
				],
			),
		);
	}
	*/

class BillingPageArguments {
  const BillingPageArguments({required this.missions, this.invoiceNumber});

  final List<Map<String, dynamic>> missions;
  /// Quand renseigné, la page s'ouvre directement sur cette facture (section Factures).
  final String? invoiceNumber;
}

enum BillingSection { creation, invoices, preparations }

enum _CreateInvoiceActionState { idle, loading, success, error }

class BillingPage extends StatefulWidget {
  const BillingPage({super.key, required this.userRights});

  final UserRights userRights;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  static const Set<String> _billableMissionStatuses = <String>{'0', '1'};

  BillingSection _activeSection = BillingSection.creation;
  bool _sidebarCollapsed = true;

  String _clientInput = '';
  int? _selectedClientId; // numeric fk_soc — set when a client is picked from autocomplete
  String? _loadError;
  bool _loadingMissions = false;
  bool _isTableFullscreen = false;
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _fullscreenVerticalController = ScrollController();
  final ScrollController _fullscreenHorizontalController = ScrollController();

  late final NumberFormat _currencyFormat;
  late final NumberFormat _quantityFormat;
  late final List<DateTime> _availableMonths;
  late DateTime _selectedMonth;

  List<Map<String, dynamic>> _allClientMissions = [];
  List<Map<String, dynamic>> _missions = [];
  final List<_EditableInvoiceLine> _lineEditors = [];
  int? _selectedLineIndex;
  bool _showLinePanel = false;
  bool _loadingDraft = false;
  bool _savingDraft = false;
  bool _savingDraftHeader = false;
  String? _draftKey;
  // AMI v1.3 : identifiant du draft persisté (null si pas de draft enregistré via save_invoice_draft.php)
  int? _draftId;

  // Pagination du tableau des lignes de mission
  int _missionTablePage = 1;
  int _missionTablePageSize = 100;
  String _missionTableSearch = '';
  final TextEditingController _missionTableSearchCtrl = TextEditingController();

  TextEditingController? _lineDesignationCtrl;
  TextEditingController? _lineQuantityCtrl;
  TextEditingController? _lineUnitPriceCtrl;
  TextEditingController? _lineNotesCtrl;
  final TextEditingController _invoiceSearchController =
      TextEditingController();

  Timer? _draftSaveTimer;
  Timer? _createInvoiceFeedbackTimer;

  bool _generatingPdf = false;
  _CreateInvoiceActionState _createInvoiceState =
      _CreateInvoiceActionState.idle;
  CompanyInfo? _companyInfo;
  bool _loadingCompanyInfo = false;
  List<CompanyBankAccount> _companyBankAccounts = [];
  bool _loadingCompanyBankAccounts = false;
  int? _selectedCompanyBankAccountId;
  List<ClientPaymentTerm> _clientPaymentTerms = [];
  bool _loadingClientPaymentTerms = false;
  int? _selectedClientPaymentTermId;
  pw.Font? _pdfFontRegular;
  pw.Font? _pdfFontBold;
  pw.MemoryImage? _pdfLogoImage;

  // AMI v1.3 — Préparations en cours
  List<InvoiceDraftSummary> _drafts = [];
  bool _loadingDrafts = false;
  String? _draftsError;

  List<ClientInvoiceSummary> _invoices = [];
  bool _loadingInvoices = false;
  String _invoiceSortColumn = 'invoiceNumber';
  bool _invoiceSortAscending = false;
  int _invoicePage = 1;
  final int _invoicePageSize = 1000;
  int _invoiceTotal = 0;
  String _invoiceClientFilter = 'Tous les clients';
  String _invoiceMonthFilter = 'Tous les mois';
  String _invoiceStatusFilter = 'Tous les statuts';
  String _invoiceSearchQuery = '';
  String? _invoiceError;
  bool _routeArgsHandled = false;
  String? _pendingOpenInvoiceNumber;
  final ScrollController _invoiceScrollController = ScrollController();
  final ScrollController _invoiceHorizontalController = ScrollController();
  ClientInvoiceSummary? _selectedInvoice;
  ClientInvoiceLinesResult? _selectedInvoiceLines;
  String? _selectedInvoiceMissionRef;
  final List<_EditableInvoiceLine> _selectedInvoiceLineEditors = [];
  bool _loadingInvoiceLinesPanel = false;
  bool _savingInvoiceLinesPanel = false;
  final Set<String> _updatingInvoiceStatus = <String>{};
  final Set<String> _updatingInvoiceBankAccount = <String>{};
  final Set<String> _updatingInvoicePaymentTerm = <String>{};
  final Set<String> _updatingInvoiceDate = <String>{};
  List<ClientPaymentTerm> _invoiceDetailPaymentTerms = [];
  final List<ClientInvoiceSummary> _creationClientInvoices = [];
  bool _loadingCreationClientInvoices = false;

  bool _isMissionEligibleForBilling(Map<String, dynamic> mission) {
    final status = (mission['mission_status'] ?? '').toString().trim();
    return _billableMissionStatuses.contains(status);
  }

  static const List<String> _invoiceStatusLabels = [
    'Brouillon',
    'Validée',
    'Payée',
    'Annulée',
  ];

  static const Map<String, String> _invoiceStatusToCode = {
    'Brouillon': 'draft',
    'Validée': 'validated',
    'Payée': 'paid',
    'Annulée': 'cancelled',
  };

  static const Map<String, String> _invoiceCodeToLabel = {
    'draft': 'Brouillon',
    'validated': 'Validée',
    'paid': 'Payée',
    'cancelled': 'Annulée',
  };

  Widget _buildSectionPageTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Color(0xFF000091),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildCreationView(double spacing) {
    return Container(
      color: const Color(0xFFF6F6F6),
      child: ResponsiveContainer(
        maxWidth: double.infinity,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionPageTitle('Création des factures'),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientSection(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _loadingMissions
                          ? _buildMissionsLoadingState()
                          : _lineEditors.isEmpty
                              ? _buildEmptyState()
                              : Stack(
                                  children: [
                                    _buildInvoiceCard(spacing),
                                    if (_savingDraft)
                                      const Positioned(
                                        right: 16,
                                        top: 16,
                                        child: _SavingDraftBadge(),
                                      ),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesView(double spacing) {
    return Container(
      color: const Color(0xFFF6F6F6),
      child: ResponsiveContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionPageTitle('Tableau des factures'),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(spacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInvoiceFilters(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildInvoiceTable()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    );
    _quantityFormat = NumberFormat.decimalPattern('fr_FR')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 3;
    _availableMonths = _buildAvailableMonths();
    _selectedMonth = _availableMonths.first;
    unawaited(_loadCompanyInfo());
    unawaited(_loadCompanyBankAccounts());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsHandled) return;
    _routeArgsHandled = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is BillingPageArguments &&
        args.invoiceNumber != null &&
        args.invoiceNumber!.trim().isNotEmpty) {
      _pendingOpenInvoiceNumber = args.invoiceNumber!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _activeSection = BillingSection.invoices);
        unawaited(_loadInvoices(reset: true));
      });
    }
  }

  Widget _buildInvoiceListFooter({
    required List<ClientInvoiceSummary> invoices,
    required bool compact,
  }) {
    final activeInvoices = invoices.where(
      (inv) => inv.statusCode.trim().toLowerCase() != 'cancelled' &&
          _invoiceStatusLabelFor(inv) != 'Annulée',
    );
    final totalDisplayed = activeInvoices.fold<double>(
      0,
      (sum, invoice) =>
          sum +
          (invoice.invoiceTotalHt > 0
              ? invoice.invoiceTotalHt
              : invoice.amountHt),
    );
    final summary =
        '${invoices.length} facture${invoices.length > 1 ? 's' : ''} affichée${invoices.length > 1 ? 's' : ''}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Text(
                    'Total: ${_formatCurrency(totalDisplayed)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompactInvoiceMetric(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    _fullscreenVerticalController.dispose();
    _fullscreenHorizontalController.dispose();
    _invoiceHorizontalController.dispose();
    _invoiceScrollController.dispose();
    _lineDesignationCtrl?.dispose();
    _lineQuantityCtrl?.dispose();
    _lineUnitPriceCtrl?.dispose();
    _lineNotesCtrl?.dispose();
    _invoiceSearchController.dispose();
    _missionTableSearchCtrl.dispose();
    _draftSaveTimer?.cancel();
    _createInvoiceFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveHelper.getSpacing(context);
    final viewportWidth = MediaQuery.of(context).size.width;
    final isCompactLayout = viewportWidth < 860;
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            if (isCompactLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCompactSectionSwitcher(),
                  Expanded(child: _buildActiveView(spacing)),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(context),
                  Expanded(child: _buildActiveView(spacing)),
                ],
              ),
            if (_activeSection == BillingSection.creation &&
                _showLinePanel &&
                _selectedLineIndex != null)
              _buildLineEditorPanel(spacing),
            if (_activeSection == BillingSection.creation && _isTableFullscreen)
              _buildFullscreenOverlay(spacing),
            if (_activeSection == BillingSection.invoices &&
                _selectedInvoice != null)
              _buildInvoiceDetailsPanel(spacing),
          ],
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: BrandFooter(),
      ),
    );
  }

  Widget _buildCompactSectionSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Facturation',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<BillingSection>(
            multiSelectionEnabled: false,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<BillingSection>(
                value: BillingSection.creation,
                icon: Icon(Icons.description_outlined),
                label: Text('Préparation'),
              ),
              ButtonSegment<BillingSection>(
                value: BillingSection.invoices,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text('Factures'),
              ),
              ButtonSegment<BillingSection>(
                value: BillingSection.preparations,
                icon: Icon(Icons.folder_copy_outlined),
                label: Text('Factures initiées'),
              ),
            ],
            selected: <BillingSection>{_activeSection},
            onSelectionChanged: (selection) {
              final section = selection.firstOrNull;
              if (section != null) {
                _setActiveSection(section);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    const collapsedWidth = 68.0;
    const expandedWidth = 240.0;
    final collapsed = _sidebarCollapsed;
    final horizontalPadding = collapsed ? 8.0 : 12.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
                    child: !collapsed
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Facturation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Navigation générale',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  tooltip: collapsed
                      ? 'Déplier la navigation'
                      : 'Réduire la navigation',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SidebarEntry(
                  icon: Icons.description_outlined,
                  label: 'Préparation',
                  selected: _activeSection == BillingSection.creation,
                  onTap: () => _setActiveSection(BillingSection.creation),
                  collapsed: collapsed,
                ),
                _SidebarEntry(
                  icon: Icons.receipt_long_outlined,
                  label: 'Factures',
                  selected: _activeSection == BillingSection.invoices,
                  onTap: () => _setActiveSection(BillingSection.invoices),
                  collapsed: collapsed,
                ),
                _SidebarEntry(
                  icon: Icons.folder_copy_outlined,
                  label: 'Factures initiées',
                  selected: _activeSection == BillingSection.preparations,
                  onTap: () => _setActiveSection(BillingSection.preparations),
                  collapsed: collapsed,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              16,
            ),
            child: Column(
              crossAxisAlignment: collapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (!collapsed) ...[
                  const Text(
                    'Détail des lignes de facturation',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '${_lineEditors.length} ligne(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (collapsed)
                  IconButton(
                    icon: Icon(
                      _isTableFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                    ),
                    onPressed: _lineEditors.isEmpty
                        ? null
                        : () => _toggleTableFullscreen(!_isTableFullscreen),
                    tooltip: _isTableFullscreen
                        ? 'Quitter le plein écran'
                        : 'Afficher en plein écran',
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _lineEditors.isEmpty
                        ? null
                        : () => _toggleTableFullscreen(!_isTableFullscreen),
                    icon: Icon(
                      _isTableFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                    ),
                    label: Text(
                      _isTableFullscreen
                          ? 'Quitter le plein écran'
                          : 'Voir en plein écran',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(double spacing) {
    switch (_activeSection) {
      case BillingSection.creation:
        return _buildCreationView(spacing);
      case BillingSection.invoices:
        return _buildInvoicesView(spacing);
      case BillingSection.preparations:
        return _buildPreparationsView(spacing);
    }
  }

  void _setActiveSection(BillingSection section) {
    if (_activeSection == section) return;
    setState(() {
      _activeSection = section;
      if (section != BillingSection.creation) {
        _showLinePanel = false;
        _selectedLineIndex = null;
      }
      if (section != BillingSection.invoices) {
        _selectedInvoice = null;
        _selectedInvoiceLines = null;
        _selectedInvoiceMissionRef = null;
        _selectedInvoiceLineEditors.clear();
        _loadingInvoiceLinesPanel = false;
        _savingInvoiceLinesPanel = false;
      }
    });
    if (section == BillingSection.invoices &&
        _invoices.isEmpty &&
        !_loadingInvoices) {
      unawaited(_loadInvoices(reset: true));
    }
    if (section == BillingSection.preparations && !_loadingDrafts) {
      unawaited(_loadDrafts());
    }
  }

  Widget _buildClientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 960;
            final isWideDesktop = constraints.maxWidth >= 1180;
            final clientField = _buildToolbarField(
              label: 'Client',
              width: isCompact ? constraints.maxWidth : 300.0,
              child: ClientAutocompleteField(
                value: _clientInput,
                hintText: 'Sélectionner un client',
                onChanged: (value) => setState(() {
                  _clientInput = value;
                  _selectedClientId = null; // reset when user types manually
                  _creationClientInvoices.clear();
                }),
                onSummarySelected: (summary) => setState(() {
                  _selectedClientId = summary.id > 0 ? summary.id : null;
                }),
                onSelected: (_) {},
                onSubmitted: (_) {},
                trailingBuilder: (context, controller, loading) => [
                  IconButton(
                    icon: _loadingMissions
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    onPressed: _canLoadMissions ? _loadMissionsForClient : null,
                    tooltip: 'Charger les missions',
                  ),
                ],
              ),
            );
            final monthField = _buildToolbarField(
              label: 'Mois',
              width: isCompact ? constraints.maxWidth : 220.0,
              child: DropdownButtonFormField<DateTime>(
                initialValue: _selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: _availableMonths
                    .map(
                      (month) => DropdownMenuItem(
                        value: month,
                        child: _buildDropdownOverflowLabel(_monthLabel(month)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedMonth = value);
                  _applyMonthFilter();
                },
              ),
            );
            final bankField = _buildToolbarField(
              label: 'Compte bancaire',
              width: isCompact ? constraints.maxWidth : 320.0,
              child: DropdownButtonFormField<int>(
                key: ValueKey(_selectedCompanyBankAccountId),
                initialValue: _selectedCompanyBankAccountId,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: _loadingCompanyBankAccounts
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.account_balance_outlined),
                ),
                hint: const Text('Compte par défaut entreprise'),
                items: _companyBankAccounts
                    .map(
                      (account) => DropdownMenuItem<int>(
                        value: account.id,
                        child: _buildDropdownOverflowLabel(
                          account.dropdownLabel,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _companyBankAccounts.isEmpty
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedCompanyBankAccountId = value);
                      },
              ),
            );
            final paymentTermField = _buildToolbarField(
              label: 'Condition de règlement',
              width: isCompact ? constraints.maxWidth : 340.0,
              child: DropdownButtonFormField<int>(
                key: ValueKey(_selectedClientPaymentTermId),
                initialValue: _selectedClientPaymentTermId,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: _loadingClientPaymentTerms
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                ),
                hint: const Text('Condition par défaut du client'),
                items: _clientPaymentTerms
                    .map(
                      (term) => DropdownMenuItem<int>(
                        value: term.id,
                        child: _buildDropdownOverflowLabel(term.dropdownLabel),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _clientPaymentTerms.isEmpty
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedClientPaymentTermId = value);
                      },
              ),
            );

            if (isWideDesktop) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreparationTopBar(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        clientField,
                        const SizedBox(width: 18),
                        monthField,
                        const SizedBox(width: 18),
                        Container(
                          width: 1,
                          height: 46,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: _buildToolbarButtons(allowWrap: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInvoiceSettingsBlock(
                    fields: [paymentTermField, bankField],
                    compact: false,
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreparationTopBar(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [clientField, monthField],
                      ),
                      const SizedBox(height: 12),
                      _buildToolbarButtons(
                        allowWrap: !isCompact,
                        width: isCompact ? constraints.maxWidth : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildInvoiceSettingsBlock(
                  fields: [paymentTermField, bankField],
                  compact: true,
                ),
              ],
            );
          },
        ),
        if (_loadingDraft)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _loadError!,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ),
        if (_loadingCreationClientInvoices)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_currentPeriodInvoiceConflictMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _currentPeriodInvoiceConflictMessage!,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreparationTopBar({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildToolbarField({
    required String label,
    required Widget child,
    double? width,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
    if (width == null) return content;
    return SizedBox(width: width, child: content);
  }

  Widget _buildDropdownOverflowLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  Widget _buildToolbarButtons({required bool allowWrap, double? width}) {
    final createTooltipMessage = _createInvoiceActionTooltip;
    final actionButtons = [
      ElevatedButton.icon(
        onPressed: _canLoadMissions ? _loadMissionsForClient : null,
        icon: _loadingMissions
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: Text(
          _loadingMissions ? 'Chargement...' : 'Charger les missions',
        ),
      ),
      Tooltip(
        message: createTooltipMessage,
        waitDuration: const Duration(milliseconds: 250),
        child: FilledButton.icon(
          onPressed: _canCreateInvoice ? _handleCreateInvoice : null,
          style: FilledButton.styleFrom(
            backgroundColor: switch (_createInvoiceState) {
              _CreateInvoiceActionState.success => const Color(0xFF15803D),
              _CreateInvoiceActionState.error => const Color(0xFFB91C1C),
              _ => null,
            },
          ),
          icon: _buildCreateInvoiceButtonIcon(),
          label: Text(_createInvoiceButtonLabel),
        ),
      ),
      FilledButton.icon(
        onPressed: _canGeneratePdf ? _generatePdfFromTable : null,
        icon: _generatingPdf
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(
          _generatingPdf ? 'Préparation...' : 'Générer facture (PDF)',
        ),
      ),
      OutlinedButton.icon(
        onPressed: _canSaveDraft ? _saveCurrentDraftHeader : null,
        icon: _savingDraftHeader
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_add_outlined),
        label: Text(_savingDraftHeader ? 'Sauvegarde...' : 'Sauvegarder la préparation'),
      ),
      OutlinedButton.icon(
        onPressed: _resetPreparationState,
        icon: const Icon(Icons.restore),
        label: const Text('Réinitialiser tout'),
      ),
    ];

    final buttons = allowWrap
        ? Wrap(spacing: 10, runSpacing: 10, children: actionButtons)
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < actionButtons.length; index++) ...[
                  actionButtons[index],
                  if (index < actionButtons.length - 1)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          );
    if (width == null) return buttons;
    return SizedBox(width: width, child: buttons);
  }

  String get _createInvoiceActionTooltip {
    if (_canCreateInvoice) {
      return 'Créer et enregistrer la facture pour la période sélectionnée.';
    }
    if (_createInvoiceState == _CreateInvoiceActionState.loading) {
      return 'Création de la facture en cours.';
    }
    if (_loadingCreationClientInvoices) {
      return 'Vérification des factures existantes en cours.';
    }
    return _validateInvoiceActionRequirements(forCreation: true) ??
        'Action indisponible pour le moment.';
  }

  Widget _buildInvoiceSettingsBlock({
    required List<Widget> fields,
    required bool compact,
  }) {
    final fieldsContent = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          )
        : Wrap(spacing: 16, runSpacing: 12, children: fields);

    final intro = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.settings, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paramètres de facture',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Appliqués au PDF généré',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E0EA)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 14), fieldsContent],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 240, child: intro),
                const SizedBox(width: 18),
                Expanded(child: fieldsContent),
              ],
            ),
    );
  }

  Widget _buildInvoiceCard(double spacing) {
    const borderRadius = 10.0;
    const borderColor = Color(0xFFE5E7EB);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: const BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing,
              vertical: spacing / 1.5,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.table_rows, color: Color(0xFF000091)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Tableau des lignes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: _lineEditors.isEmpty
                              ? ' • aucune ligne sélectionnée'
                              : ' • ${_lineEditors.length} ligne(s) prête(s)',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isTableFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                  ),
                  onPressed: _lineEditors.isEmpty
                      ? null
                      : () => _toggleTableFullscreen(!_isTableFullscreen),
                  tooltip: _isTableFullscreen
                      ? 'Quitter le plein écran'
                      : 'Afficher en plein écran',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          _buildMissionTableToolbar(spacing),
          const Divider(height: 1, color: borderColor),
          Expanded(
            child: _buildLinesTable(
              verticalController: _tableVerticalController,
              horizontalController: _tableHorizontalController,
              indexedEditors: _paginatedIndexedEditors,
            ),
          ),
          const Divider(height: 1, color: borderColor),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing,
              vertical: spacing / 1.5,
            ),
            child: Row(
              children: [
                if (_lineEditors.isNotEmpty)
                  Text(
                    '${_lineEditors.length} ligne(s)',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                if (_lineEditors.isNotEmpty) const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total HT : ${_formatCurrency(_currentTotalHt)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000091),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Total TTC : ${_formatCurrency(_currentTotalTtc)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(
    int index,
    _EditableInvoiceLine editor,
    List<double> columnWidths,
  ) {
    final line = editor.currentLine;
    final ref = editor.missionRef ?? line.missionRef ?? '-';
    return DataRow(
      selected: _selectedLineIndex == index,
      onSelectChanged: (_) => _openLineEditor(index),
      cells: [
        DataCell(
          SizedBox(
            width: columnWidths[0],
            child: Tooltip(
              message: 'Supprimer cette ligne',
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C), size: 20),
                onPressed: () => _deleteLine(index),
              ),
            ),
          ),
        ),
        _buildSelectableCell(ref.isEmpty ? '-' : ref, width: columnWidths[1]),
        _buildEditableDesignationCell(index, columnWidths[2]),
        _buildTvaDropdownCell(index, columnWidths[3]),
        _buildEditableNumberCell(
          label: 'P.U. HT',
          index: index,
          width: columnWidths[4],
          value: line.unitPrice,
          fractionDigits: 2,
          onChanged: (value) {
            if (value != null && value >= 0) {
              _updateLineFields(index, unitPrice: value);
            }
          },
        ),
        _buildSelectableCell(
          _formatCurrency(line.unitPriceTtc),
          width: columnWidths[5],
          align: TextAlign.right,
        ),
        _buildEditableNumberCell(
          label: 'Réduc.',
          index: index,
          width: columnWidths[6],
          value: line.discount,
          fractionDigits: 2,
          onChanged: (value) {
            if (value != null && value >= 0 && value <= 100) {
              _updateLineFields(index, discount: value);
            }
          },
        ),
        _buildEditableNumberCell(
          label: 'Quantité',
          index: index,
          width: columnWidths[7],
          value: line.quantity,
          fractionDigits: 3,
          onChanged: (value) {
            if (value != null && value > 0) {
              _updateLineFields(index, quantity: value);
            }
          },
        ),
        _buildSelectableCell(
          _formatCurrency(line.totalHt),
          width: columnWidths[8],
          align: TextAlign.right,
        ),
        _buildSelectableCell(
          _formatCurrency(line.totalTtc),
          width: columnWidths[9],
          align: TextAlign.right,
        ),
      ],
    );
  }

  DataCell _buildEditableDesignationCell(int index, double width) {
    final editor = _lineEditors[index];
    return DataCell(
      _InlineEditableTextCell(
        key: ValueKey('designation_$index'),
        width: width,
        text: editor.currentLine.designation,
        maxLines: 4,
        onChanged: (value) => _updateLineFields(index, designation: value),
      ),
    );
  }

  DataCell _buildTvaDropdownCell(int index, double width) {
    final line = _lineEditors[index].currentLine;
    final current = _tvaOptionFor(line.tvaRate) ?? _tvaRates.first;
    return DataCell(
      SizedBox(
        width: width,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<double>(
            value: current,
            isDense: true,
            items: _tvaRates
                .map(
                  (rate) => DropdownMenuItem<double>(
                    value: rate,
                    child: Text(
                      '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _updateLineFields(index, tvaRate: value);
              }
            },
          ),
        ),
      ),
    );
  }

  DataCell _buildEditableNumberCell({
    required String label,
    required int index,
    required double width,
    required double value,
    required int fractionDigits,
    required ValueChanged<double?> onChanged,
  }) {
    return DataCell(
      _InlineEditableNumberCell(
        key: ValueKey('$label-$index'),
        width: width,
        value: value,
        fractionDigits: fractionDigits,
        onNumberChanged: onChanged,
      ),
    );
  }

  DataCell _buildSelectableCell(
    String value, {
    double? width,
    TextAlign align = TextAlign.left,
  }) {
    final widget = SelectableText(
      value,
      textAlign: align,
      style: const TextStyle(height: 1.2),
    );
    if (width != null) {
      return DataCell(SizedBox(width: width, child: widget));
    }
    return DataCell(widget);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            'Aucune mission à afficher',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Saisissez un client, choisissez un mois puis cliquez sur "Charger les missions" pour préparer la facture.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionsLoadingState() {
    const borderRadius = 10.0;
    const borderColor = Color(0xFFE5E7EB);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: const BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.table_rows, color: Color(0xFF000091)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chargement des missions en cours\u2026',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF000091),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: borderColor),
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _buildSkeletonBox(width: 32, height: 12),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 80, height: 12),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSkeletonBox(height: 12)),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 52, height: 12),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 64, height: 12),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 64, height: 12),
                    const SizedBox(width: 16),
                    _buildSkeletonBox(width: 48, height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildInvoiceFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1200;
        final refreshButton = FilledButton.icon(
          onPressed: _loadingInvoices ? null : () => _loadInvoices(reset: true),
          icon: _loadingInvoices
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(_loadingInvoices ? 'Actualisation...' : 'Mettre à jour'),
        );

        final filterFields = [
          TextFormField(
            controller: _invoiceSearchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Rechercher une facture, un client ou un mois...',
              hintStyle: const TextStyle(fontSize: 12),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _invoiceSearchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _invoiceSearchController.clear();
                        setState(() => _invoiceSearchQuery = '');
                      },
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Effacer',
                    ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (value) => setState(() => _invoiceSearchQuery = value),
          ),
          _buildInvoiceFilterDropdown(
            value: _invoiceMonthFilter,
            items: _invoiceMonthOptions,
            icon: Icons.calendar_month_outlined,
            onChanged: (value) =>
                setState(() => _invoiceMonthFilter = value ?? 'Tous les mois'),
          ),
          _buildInvoiceFilterDropdown(
            value: _invoiceStatusFilter,
            items: _invoiceStatusOptions,
            icon: Icons.flag_outlined,
            onChanged: (value) {
              final next = value ?? 'Tous les statuts';
              setState(() => _invoiceStatusFilter = next);
              _loadInvoices(reset: true);
            },
          ),
          _buildInvoiceFilterDropdown(
            value: _invoiceClientFilter,
            items: _invoiceClientOptions,
            icon: Icons.business_outlined,
            onChanged: (value) {
              final next = value ?? 'Tous les clients';
              setState(() => _invoiceClientFilter = next);
              _loadInvoices(reset: true);
            },
          ),
          SizedBox(
            width: double.infinity,
            child: refreshButton,
          ),
        ];

        if (!isCompact) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7E0EA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 30,
                  child: TextFormField(
                    controller: _invoiceSearchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une facture, un client ou un mois...',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _invoiceSearchQuery.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _invoiceSearchController.clear();
                                setState(() => _invoiceSearchQuery = '');
                              },
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: 'Effacer',
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _invoiceSearchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 18,
                  child: _buildInvoiceFilterDropdown(
                    value: _invoiceMonthFilter,
                    items: _invoiceMonthOptions,
                    icon: Icons.calendar_month_outlined,
                    onChanged: (value) => setState(
                      () => _invoiceMonthFilter = value ?? 'Tous les mois',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 18,
                  child: _buildInvoiceFilterDropdown(
                    value: _invoiceStatusFilter,
                    items: _invoiceStatusOptions,
                    icon: Icons.flag_outlined,
                    onChanged: (value) {
                      final next = value ?? 'Tous les statuts';
                      setState(() => _invoiceStatusFilter = next);
                      _loadInvoices(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 20,
                  child: _buildInvoiceFilterDropdown(
                    value: _invoiceClientFilter,
                    items: _invoiceClientOptions,
                    icon: Icons.business_outlined,
                    onChanged: (value) {
                      final next = value ?? 'Tous les clients';
                      setState(() => _invoiceClientFilter = next);
                      _loadInvoices(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 158,
                  child: SizedBox(width: double.infinity, child: refreshButton),
                ),
              ],
            ),
          );
        }

        return _buildInvoiceFilterFieldsBlock(
          fields: filterFields,
          compact: isCompact,
        );
      },
    );
  }

  Widget _buildInvoiceFilterFieldsBlock({
    required List<Widget> fields,
    required bool compact,
  }) {
    final fieldsContent = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          )
        : Wrap(spacing: 16, runSpacing: 12, children: fields);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E0EA)),
      ),
      child: compact
          ? fieldsContent
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 240, child: _buildInvoiceFilterFieldsIntro()),
                const SizedBox(width: 18),
                Expanded(child: fieldsContent),
              ],
            ),
    );
  }

  Widget _buildInvoiceFilterFieldsIntro() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtres de liste',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Affinent les résultats affichés',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceFilterDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: _buildDropdownOverflowLabel(item),
              ))
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _buildInvoiceTable() {
    if (_invoiceError != null) {
      return _buildInvoiceStateCard(
        icon: Icons.error_outline,
        title: 'Impossible de charger les factures',
        subtitle: _invoiceError!,
        foregroundColor: const Color(0xFFB91C1C),
      );
    }
    if (_loadingInvoices) {
      return _buildInvoiceLoadingStateCard();
    }
    if (_invoices.isEmpty) {
      return _buildInvoiceStateCard(
        icon: Icons.receipt_long_outlined,
        title: 'Aucune facture trouvée',
        subtitle: 'Modifiez les filtres pour relancer la recherche.',
      );
    }
    final invoices = _filteredInvoicesForDisplay;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1240;
        return Column(
          children: [
            Expanded(
              child: invoices.isEmpty
                  ? _buildInvoiceStateCard(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Aucun résultat',
                      subtitle:
                          'Aucune facture ne correspond aux filtres sélectionnés.',
                    )
                  : isCompact
                  ? _buildCompactInvoiceList(invoices)
                  : _buildInvoiceDesktopTable(invoices),
            ),
            const SizedBox(height: 12),
            _buildInvoiceListFooter(
              invoices: invoices,
              compact: isCompact,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSortHeader(String label, String column, {bool alignRight = false}) {
    final isActive = _invoiceSortColumn == column;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => setState(() {
        if (_invoiceSortColumn == column) {
          _invoiceSortAscending = !_invoiceSortAscending;
        } else {
          _invoiceSortColumn = column;
          _invoiceSortAscending = true;
        }
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF2563EB) : null,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (_invoiceSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDesktopTable(List<ClientInvoiceSummary> invoices) {
    final selectedInvoiceNumber = _selectedInvoice?.invoiceNumber;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  flex: 18,
                  child: _buildSortHeader('N° facture', 'invoiceNumber'),
                ),
                Expanded(
                  flex: 19,
                  child: _buildSortHeader('Client', 'client'),
                ),
                Expanded(
                  flex: 15,
                  child: _buildSortHeader('Mois', 'month'),
                ),
                Expanded(
                  flex: 13,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildSortHeader('Total HT', 'totalHt', alignRight: true),
                    ),
                  ),
                ),
                Expanded(
                  flex: 13,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: _buildSortHeader('Statut', 'status'),
                  ),
                ),
                Expanded(
                  flex: 13,
                  child: _buildSortHeader('Date création', 'createdAt'),
                ),
                const Expanded(
                  flex: 10,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                final isSelected =
                    invoice.invoiceNumber == selectedInvoiceNumber;
                return InkWell(
                  onTap: () => _openInvoiceDetails(invoice),
                  child: Container(
                    color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 18,
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 19,
                          child: _buildInvoiceClientCell(invoice.clientName),
                        ),
                        Expanded(
                          flex: 15,
                          child: Text(_invoiceMonthLabel(invoice)),
                        ),
                        Expanded(
                          flex: 13,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatCurrency(
                                  invoice.invoiceTotalHt > 0
                                      ? invoice.invoiceTotalHt
                                      : invoice.amountHt,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 13,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildInvoiceStatusBadge(invoice),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 13,
                          child: Text(
                            _formatInvoiceListDate(
                              invoice.createdAt ?? invoice.billedAt,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 10,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                _buildInvoiceActionButton(
                                  icon: Icons.visibility_outlined,
                                  tooltip: 'Voir',
                                  onPressed: () => _openInvoiceDetails(invoice),
                                ),
                                if (_hasStoredInvoicePdf(invoice))
                                  _buildInvoiceActionButton(
                                    icon: Icons.open_in_new_outlined,
                                    tooltip: 'Ouvrir le PDF serveur',
                                    onPressed: () => _openStoredInvoicePdf(invoice),
                                  ),
                                _buildInvoiceActionButton(
                                  icon: Icons.picture_as_pdf_outlined,
                                  tooltip: 'Générer le PDF',
                                  onPressed: _generatingPdf
                                      ? null
                                      : () => _generateInvoicePdf(invoice),
                                ),
                                _buildInvoiceActionButton(
                                  icon: Icons.cancel_outlined,
                                  tooltip: 'Annuler la facture',
                                  color: const Color(0xFFE11D48),
                                  onPressed: _canCancelInvoice(invoice)
                                      ? () => _cancelInvoice(invoice)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceClientCell(String clientName) {
    final parts = _splitInvoiceClientLabel(clientName);
    final primary = parts.first;
    final secondary = parts.length > 1 ? parts[1] : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: secondary == null ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 3),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }

  List<String> _splitInvoiceClientLabel(String clientName) {
    final normalized = _textOrDash(clientName);
    if (normalized == '-') {
      return const ['-'];
    }
    const separators = [' - ', ' – ', ' — ', ' / ', ', '];
    for (final separator in separators) {
      final index = normalized.indexOf(separator);
      if (index <= 0) continue;
      final primary = normalized.substring(0, index).trim();
      final secondary = normalized.substring(index + separator.length).trim();
      if (primary.isNotEmpty && secondary.isNotEmpty) {
        return [primary, secondary];
      }
    }
    return [normalized];
  }

  Widget _buildCompactInvoiceList(List<ClientInvoiceSummary> invoices) {
    final selectedInvoiceNumber = _selectedInvoice?.invoiceNumber;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final isSelected = invoice.invoiceNumber == selectedInvoiceNumber;
        return Material(
          color: isSelected ? const Color(0xFFF5F7FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF000091)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openInvoiceDetails(invoice),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      _buildInvoiceStatusBadge(invoice),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _textOrDash(invoice.clientName),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildCompactInvoiceMetric(
                        'Mois',
                        _invoiceMonthLabel(invoice),
                      ),
                      _buildCompactInvoiceMetric(
                        'Total HT',
                        _formatCurrency(
                          invoice.invoiceTotalHt > 0
                              ? invoice.invoiceTotalHt
                              : invoice.amountHt,
                        ),
                      ),
                      _buildCompactInvoiceMetric(
                        'Date création',
                        _formatInvoiceListDate(
                          invoice.createdAt ?? invoice.billedAt,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildInvoiceActionButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'Voir',
                        onPressed: () => _openInvoiceDetails(invoice),
                      ),
                      if (_hasStoredInvoicePdf(invoice)) ...[
                        const SizedBox(width: 6),
                        _buildInvoiceActionButton(
                          icon: Icons.open_in_new_outlined,
                          tooltip: 'Ouvrir le PDF serveur',
                          onPressed: () => _openStoredInvoicePdf(invoice),
                        ),
                      ],
                      const SizedBox(width: 6),
                      _buildInvoiceActionButton(
                        icon: Icons.picture_as_pdf_outlined,
                        tooltip: 'Générer le PDF',
                        onPressed: _generatingPdf
                            ? null
                            : () => _generateInvoicePdf(invoice),
                      ),
                      const SizedBox(width: 6),
                      _buildInvoiceActionButton(
                        icon: Icons.cancel_outlined,
                        tooltip: 'Annuler la facture',
                        color: const Color(0xFFE11D48),
                        onPressed: _canCancelInvoice(invoice)
                            ? () => _cancelInvoice(invoice)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color foregroundColor = const Color(0xFF334155),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 38, color: foregroundColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: foregroundColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceLoadingStateCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Chargement des factures...',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _textOrDash(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  List<String> get _invoiceMonthOptions {
    final months =
        _invoices
            .map((invoice) => invoice.periodMonth ?? invoice.billedAt)
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month))
            .toSet()
            .toList(growable: false)
          ..sort((left, right) => right.compareTo(left));
    return <String>['Tous les mois', ...months.map(_monthLabel)];
  }

  List<String> get _invoiceStatusOptions => <String>[
    'Tous les statuts',
    ..._invoiceStatusLabels,
  ];

  List<String> get _invoiceClientOptions {
    final clients =
        _invoices
            .map((invoice) => invoice.clientName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    return <String>['Tous les clients', ...clients];
  }

  List<ClientInvoiceSummary> get _filteredInvoicesForDisplay {
    final normalizedQuery = _invoiceSearchQuery.trim().toLowerCase();
    return _invoices
        .where((invoice) {
          if (_invoiceClientFilter != 'Tous les clients' &&
              invoice.clientName.trim() != _invoiceClientFilter) {
            return false;
          }
          if (_invoiceMonthFilter != 'Tous les mois' &&
              _invoiceMonthLabel(invoice) != _invoiceMonthFilter) {
            return false;
          }
          if (_invoiceStatusFilter != 'Tous les statuts' &&
              _invoiceStatusLabelFor(invoice) != _invoiceStatusFilter) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final haystack = <String>[
            invoice.invoiceNumber,
            invoice.clientName,
            _invoiceMonthLabel(invoice),
            _invoiceStatusLabelFor(invoice),
          ].join(' ').toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: true)
      ..sort((a, b) {
        int cmp;
        switch (_invoiceSortColumn) {
          case 'client':
            cmp = a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
            break;
          case 'month':
            final da = a.periodMonth ?? a.billedAt ?? DateTime(0);
            final db = b.periodMonth ?? b.billedAt ?? DateTime(0);
            cmp = da.compareTo(db);
            break;
          case 'totalHt':
            final ta = a.invoiceTotalHt > 0 ? a.invoiceTotalHt : a.amountHt;
            final tb = b.invoiceTotalHt > 0 ? b.invoiceTotalHt : b.amountHt;
            cmp = ta.compareTo(tb);
            break;
          case 'status':
            cmp = _invoiceStatusLabelFor(a).compareTo(_invoiceStatusLabelFor(b));
            break;
          case 'createdAt':
            final ca = a.createdAt ?? a.billedAt ?? DateTime(0);
            final cb = b.createdAt ?? b.billedAt ?? DateTime(0);
            cmp = ca.compareTo(cb);
            break;
          default: // invoiceNumber
            cmp = a.invoiceNumber.compareTo(b.invoiceNumber);
        }
        return _invoiceSortAscending ? cmp : -cmp;
      });
  }

  String _invoiceMonthLabel(ClientInvoiceSummary invoice) {
    final period = invoice.periodMonth ?? invoice.billedAt;
    if (period == null) return '-';
    return _monthLabel(DateTime(period.year, period.month));
  }

  String _formatInvoiceListDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildInvoiceStatusBadge(ClientInvoiceSummary invoice) {
    final label = _invoiceStatusLabelFor(invoice);
    final normalized = label.trim().toLowerCase();
    Color backgroundColor;
    Color foregroundColor;
    switch (normalized) {
      case 'validée':
        backgroundColor = const Color(0xFFDCFCE7);
        foregroundColor = const Color(0xFF166534);
        break;
      case 'payée':
        backgroundColor = const Color(0xFFDBEAFE);
        foregroundColor = const Color(0xFF1D4ED8);
        break;
      case 'annulée':
        backgroundColor = const Color(0xFFFEE2E2);
        foregroundColor = const Color(0xFFB91C1C);
        break;
      default:
        backgroundColor = const Color(0xFFF1F5F9);
        foregroundColor = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInvoiceActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final resolvedColor = color ?? const Color(0xFF334155);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        style: IconButton.styleFrom(
          foregroundColor: resolvedColor,
          backgroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF94A3B8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }

  bool _hasStoredInvoicePdf(ClientInvoiceSummary invoice) {
    final path = invoice.pdfPath?.trim() ?? '';
    return path.isNotEmpty;
  }

  Uri? _storedInvoicePdfUri(String? relativePath) {
    final trimmedPath = relativePath?.trim() ?? '';
    if (trimmedPath.isEmpty) return null;
    final baseUrl = AppConfig.instance.apiBaseUrl;
    final appRoot = baseUrl.replaceFirst(RegExp(r'api/?$'), '');
    return Uri.tryParse('$appRoot${trimmedPath.replaceFirst(RegExp(r'^/+'), '')}');
  }

  Future<void> _openStoredInvoicePdf(ClientInvoiceSummary invoice) async {
    final uri = _storedInvoicePdfUri(invoice.pdfPath);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun PDF serveur disponible.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d’ouvrir le PDF: $uri')),
    );
  }

  Future<void> _generateInvoicePdf(ClientInvoiceSummary invoice) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      await _ensurePdfAssets();
      final linesResult = await BillingService.fetchInvoiceLines(
        invoice.invoiceNumber,
      );
      final lines = linesResult.lines;
      if (lines.isEmpty) {
        throw Exception('Aucune ligne disponible pour cette facture.');
      }

      final companyInfo = _companyInfoForInvoicePdf(
        await _loadCompanyInfoForPdf(),
        invoice,
      );
      final clientMission = await _findClientMissionForInvoicePdf(invoice);
      final clientName = invoice.clientName.trim().isEmpty
          ? 'Client non renseigné'
          : invoice.clientName.trim();
      final paymentTermLabel = _normalizedInvoiceParameterValue(
        _invoicePaymentTermLabel(invoice),
      );
      final billedAt = invoice.createdAt ?? invoice.billedAt ?? DateTime.now();

      await _saveInvoicePdf(
        invoiceNumber: invoice.invoiceNumber,
        billedAt: billedAt,
        clientName: clientName,
        clientAddressLines: _clientAddressLinesFromMission(clientMission),
        clientCode: _clientCodeFromMission(clientMission),
        paymentTermLabel: paymentTermLabel,
        companyInfo: companyInfo,
        lines: lines,
        filenameClientSeed: clientName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF généré pour ${invoice.invoiceNumber}.')),
      );
    } catch (error, stack) {
      debugPrint('Invoice PDF generation failed: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Impossible de générer le PDF.' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingPdf = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _findClientMissionForInvoicePdf(
    ClientInvoiceSummary invoice,
  ) async {
    final normalizedClient = invoice.clientName.trim().toLowerCase();
    if (normalizedClient.isEmpty) return null;

    Map<String, dynamic>? firstMatch;
    for (final mission in [..._missions, ..._allClientMissions]) {
      if (!_missionMatchesClient(mission, normalizedClient)) continue;
      firstMatch ??= mission;
      if (_hasClientAddressData(mission)) {
        return mission;
      }
    }

    final fetched = await MissionService.getMissionsDatatableAll(
      q: invoice.clientName,
    );
    for (final mission in fetched) {
      if (!_missionMatchesClient(mission, normalizedClient)) continue;
      firstMatch ??= mission;
      if (_hasClientAddressData(mission)) {
        return mission;
      }
    }
    return firstMatch;
  }

  CompanyInfo _companyInfoForInvoicePdf(
    CompanyInfo companyInfo,
    ClientInvoiceSummary invoice,
  ) {
    final bankLabel = _normalizedInvoiceParameterValue(
      _invoiceBankLabel(invoice),
    );
    if (bankLabel == null) {
      return companyInfo;
    }
    final account = _findCompanyBankAccountForInvoiceLabel(bankLabel);
    if (account != null) {
      return account.applyTo(companyInfo);
    }
    return companyInfo;
  }

  CompanyBankAccount? _findCompanyBankAccountForInvoiceLabel(String label) {
    final normalized = _normalizeLooseLabel(label);
    if (normalized.isEmpty) return null;
    for (final account in _companyBankAccounts) {
      final candidates = <String>[
        account.dropdownLabel,
        account.bankLabel,
        account.bankName,
      ];
      if (candidates.any(
        (candidate) => _normalizeLooseLabel(candidate) == normalized,
      )) {
        return account;
      }
    }
    return null;
  }

  String? _normalizedInvoiceParameterValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return null;
    }
    return trimmed;
  }

  String _normalizeLooseLabel(String value) {
    return value.trim().toUpperCase();
  }

  String _invoicePaymentTermLabel(ClientInvoiceSummary invoice) {
    final rawValue = _invoiceNoteValue(invoice, 'Condition de règlement');
    if (rawValue == null) return '-';
    final translated = BillingService.translatePaymentTermLabel(rawValue);
    return translated.trim().isEmpty ? '-' : translated;
  }

  String _invoiceBankLabel(ClientInvoiceSummary invoice) {
    return _invoiceNoteValue(invoice, 'Compte bancaire') ?? '-';
  }

  String? _invoiceNoteValue(ClientInvoiceSummary invoice, String label) {
    final notes = invoice.notes?.trim() ?? '';
    if (notes.isEmpty) return null;
    final normalizedLabel = label.toLowerCase();
    for (final rawLine in notes.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separatorIndex = line.indexOf(':');
      if (separatorIndex <= 0) continue;
      final key = line.substring(0, separatorIndex).trim().toLowerCase();
      if (key != normalizedLabel) continue;
      final value = line.substring(separatorIndex + 1).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  List<_InvoiceMissionGroup> _buildInvoiceMissionGroups(
    List<InvoiceLine> lines,
  ) {
    final grouped = <String, List<InvoiceLine>>{};
    for (final line in lines) {
      final ref = (line.missionRef ?? '').trim();
      if (ref.isEmpty) continue;
      grouped.putIfAbsent(ref, () => <InvoiceLine>[]).add(line);
    }
    final groups =
        grouped.entries
            .map((entry) => _InvoiceMissionGroup(entry.key, entry.value))
            .toList(growable: false)
          ..sort((left, right) => left.missionRef.compareTo(right.missionRef));
    return groups;
  }

  String _invoiceMissionDesignation(_InvoiceMissionGroup group) {
    if (group.lines.isEmpty) return '-';
    final first = group.lines.first.designation.trim();
    if (group.lines.length == 1) {
      return first.isEmpty ? 'Ligne sans libellé' : first;
    }
    final base = first.isEmpty ? 'Plusieurs lignes' : first;
    return '$base +${group.lines.length - 1}';
  }

  String _invoiceMissionUnitPriceLabel(_InvoiceMissionGroup group) {
    if (group.lines.length != 1) return '-';
    return _formatCurrency(group.lines.first.unitPrice);
  }

  bool _canCancelInvoice(ClientInvoiceSummary invoice) {
    final code = invoice.statusCode.trim().toLowerCase();
    return code != 'paid' && code != 'cancelled';
  }

  Future<void> _cancelInvoice(ClientInvoiceSummary invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la facture'),
        content: Text(
          'Confirmer l\'annulation de la facture ${invoice.invoiceNumber} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler la facture'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _changeInvoiceStatus(invoice, 'Annulée');
  }

  Widget _invoiceStatusDropdown(
    ClientInvoiceSummary invoice, {
    bool compact = true,
  }) {
    final label = _invoiceStatusLabelFor(invoice);
    final isUpdating = _isInvoiceStatusBeingUpdated(invoice.invoiceNumber);
    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: label,
        isDense: compact,
        isExpanded: true,
        onChanged: isUpdating
            ? null
            : (value) {
                if (value == null || value == label) return;
                _changeInvoiceStatus(invoice, value);
              },
        items: _invoiceStatusLabels
            .map(
              (status) =>
                  DropdownMenuItem<String>(value: status, child: Text(status)),
            )
            .toList(),
      ),
    );
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        dropdown,
        if (isUpdating)
          const Positioned(
            right: 4,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildMissionTableToolbar(double spacing) {
    const pageSizes = <int>[50, 100, 250, 500, 1000, 5000];
    final filteredCount = _missionTableFilteredCount;
    final pageCount = _missionTablePageCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: TextField(
              controller: _missionTableSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filtrer les lignes...',
                hintStyle: const TextStyle(fontSize: 12),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _missionTableSearch.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                          _missionTableSearch = '';
                          _missionTableSearchCtrl.clear();
                          _missionTablePage = 1;
                        }),
                        icon: const Icon(Icons.close, size: 14),
                        tooltip: 'Effacer le filtre',
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (value) => setState(() {
                _missionTableSearch = value;
                _missionTablePage = 1;
              }),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: pageSizes.contains(_missionTablePageSize)
                  ? _missionTablePageSize
                  : pageSizes.first,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              items: pageSizes
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: s,
                      child: Text('$s / page'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                if (value != null) {
                  _missionTablePageSize = value;
                  _missionTablePage = 1;
                }
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _missionTableSearch.trim().isEmpty
                ? '$filteredCount ligne(s)'
                : '$filteredCount / ${_lineEditors.length} ligne(s)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _missionTablePage > 1
                ? () => setState(() => _missionTablePage = 1)
                : null,
            icon: const Icon(Icons.first_page, size: 18),
            tooltip: 'Première page',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            onPressed: _missionTablePage > 1
                ? () => setState(() => _missionTablePage--)
                : null,
            icon: const Icon(Icons.chevron_left, size: 18),
            tooltip: 'Page précédente',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text(
            'Page $_missionTablePage / $pageCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          IconButton(
            onPressed: _missionTablePage < pageCount
                ? () => setState(() => _missionTablePage++)
                : null,
            icon: const Icon(Icons.chevron_right, size: 18),
            tooltip: 'Page suivante',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            onPressed: _missionTablePage < pageCount
                ? () => setState(() => _missionTablePage = pageCount)
                : null,
            icon: const Icon(Icons.last_page, size: 18),
            tooltip: 'Dernière page',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesTable({
    required ScrollController verticalController,
    required ScrollController horizontalController,
    double minWidth = 1100,
    List<MapEntry<int, _EditableInvoiceLine>>? indexedEditors,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final tableWidth = math.max(viewportWidth, minWidth);
        const fractions = <double>[0.05, 0.09, 0.22, 0.07, 0.09, 0.09, 0.07, 0.07, 0.12, 0.13];
        final columnWidths = fractions
            .map((ratio) => tableWidth * ratio)
            .toList();
        return Scrollbar(
          controller: verticalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: verticalController,
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableWidth),
                child: DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 42,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 140,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[0],
                        child: const Text(''),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[1],
                        child: const Text('Ref. mission'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[2],
                        child: const Text('Désignation'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[3],
                        child: const Text('TVA'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[4],
                        child: const Text('P.U. HT'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[5],
                        child: const Text('P.U. TTC'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[6],
                        child: const Text('Réduc. %'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[7],
                        child: const Text('Qté'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[8],
                        child: const Text('Total HT'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: columnWidths[9],
                        child: const Text('Total TTC'),
                      ),
                    ),
                  ],
                  rows: (indexedEditors ?? _lineEditors.asMap().entries.toList())
                      .map(
                        (entry) =>
                            _buildRow(entry.key, entry.value, columnWidths),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullscreenOverlay(double spacing) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacing),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fullscreen,
                            color: Color(0xFF000091),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Vue plein écran des lignes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text('${_lineEditors.length} ligne(s)'),
                          IconButton(
                            onPressed: () => _toggleTableFullscreen(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    _buildMissionTableToolbar(spacing),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Expanded(
                      child: _buildLinesTable(
                        verticalController: _fullscreenVerticalController,
                        horizontalController: _fullscreenHorizontalController,
                        minWidth: 1200,
                        indexedEditors: _paginatedIndexedEditors,
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total HT : ${_formatCurrency(_currentTotalHt)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Color(0xFF000091),
                              ),
                            ),
                            Text(
                              'Total TTC : ${_formatCurrency(_currentTotalTtc)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailsPanel(double spacing) {
    final invoice = _selectedInvoice;
    if (invoice == null) return const SizedBox.shrink();
    final isCompactPanel = MediaQuery.of(context).size.width < 860;
    final missionRef = _selectedInvoiceMissionRef;
    final isLocked = _isInvoiceLockedForEdition(invoice);
    final lines = _selectedInvoiceLineEditors
        .map((editor) => editor.currentLine)
        .toList(growable: false);
    final invoiceTotal = invoice.invoiceTotalHt > 0
        ? invoice.invoiceTotalHt
        : invoice.amountHt;
    final missionTotal = lines.isNotEmpty
        ? _selectedMissionTotalHt
        : (_selectedInvoiceLines?.totalHt ?? invoice.amountHt);
    final missionGroups = _buildInvoiceMissionGroups(lines);
    final hasMissionSelection =
        missionRef != null && missionRef.trim().isNotEmpty;
    final paymentTermLabel = _invoicePaymentTermLabel(invoice);
    final bankLabel = _invoiceBankLabel(invoice);
    final createdAtLabel = _formatInvoiceListDate(
      invoice.createdAt ?? invoice.billedAt,
    );
    final scopeLabel = hasMissionSelection
        ? 'Mission ${missionRef.trim()}'
        : 'Toute la facture';
    final selectedMissionGroup = hasMissionSelection
        ? missionGroups
              .where((group) => group.missionRef == missionRef)
              .firstOrNull
        : null;

    final detailBody = Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              spacing,
              spacing,
              spacing,
              spacing - 2,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isCompactPanel
                  ? BorderRadius.zero
                  : const BorderRadius.only(topLeft: Radius.circular(18)),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(0xFF2563EB),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              invoice.invoiceNumber,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildInvoiceStatusBadge(invoice),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        invoice.clientName.isEmpty
                            ? 'Client non renseigné'
                            : invoice.clientName,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInvoiceMetaPill(
                            Icons.calendar_month_outlined,
                            _invoiceMonthLabel(invoice),
                          ),
                          _buildInvoiceMetaPill(
                            Icons.schedule_outlined,
                            createdAtLabel,
                          ),
                          _buildInvoiceMetaPill(
                            Icons.account_tree_outlined,
                            scopeLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _closeInvoiceDetails,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(spacing, 18, spacing, spacing),
              children: [
                _buildInvoiceSectionCard(
                  title: 'Vue d\'ensemble',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInvoiceInfoTile(
                              'Mois',
                              _invoiceMonthLabel(invoice),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: isLocked
                                ? _buildInvoiceInfoTile(
                                    'Date création',
                                    createdAtLabel,
                                  )
                                : _buildInvoiceDateEditor(
                                    invoice,
                                    invoice.createdAt ?? invoice.billedAt,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 190,
                            child: _buildInvoiceSummaryCard(
                              label: 'Total HT',
                              value: _formatCurrency(
                                hasMissionSelection
                                    ? missionTotal
                                    : invoiceTotal,
                              ),
                              highlighted: true,
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: _buildInvoiceSummaryCard(
                              label: 'Statut',
                              value: _invoiceStatusLabelFor(invoice),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Statut de la facture',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 220,
                        child: _invoiceStatusDropdown(invoice, compact: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildInvoiceSectionCard(
                  title: 'Paramètres',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLocked || _invoiceDetailPaymentTerms.isEmpty)
                        _buildInvoiceParameterBlock(
                          label: 'Condition de règlement',
                          value: paymentTermLabel,
                        )
                      else
                        _buildInvoicePaymentTermDropdown(
                            invoice, paymentTermLabel),
                      const SizedBox(height: 14),
                      if (isLocked || _companyBankAccounts.isEmpty)
                        _buildInvoiceParameterBlock(
                          label: 'Compte bancaire',
                          value: bankLabel,
                        )
                      else
                        _buildInvoiceBankAccountDropdown(invoice, bankLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildInvoiceSectionCard(
                  title: 'Missions associées (${missionGroups.length})',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasMissionSelection)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openInvoiceDetails(
                                invoice,
                                missionRef: null,
                              ),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('Toute la facture'),
                            ),
                          ),
                        ),
                      if (_loadingInvoiceLinesPanel)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (missionGroups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucune mission associée à cette facture.',
                          ),
                        )
                      else
                        _buildInvoiceMissionTable(
                          invoice: invoice,
                          groups: missionGroups,
                          selectedMissionRef: missionRef,
                        ),
                    ],
                  ),
                ),
                if (hasMissionSelection && selectedMissionGroup != null) ...[
                  const SizedBox(height: 18),
                  _buildInvoiceSectionCard(
                    title: 'Détail ${selectedMissionGroup.missionRef}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedMissionGroup.lines.length} ligne(s)',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isLocked)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            child: const Text(
                              'Facture payée : les lignes du détail sont verrouillées.',
                            ),
                          ),
                        if (!isLocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _selectedInvoiceLineEditors.isEmpty
                                      ? null
                                      : _resetSelectedInvoiceLines,
                                  icon: const Icon(Icons.restore),
                                  label: const Text('Réinitialiser'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        _savingInvoiceLinesPanel ||
                                            !_hasSelectedInvoiceLineChanges
                                        ? null
                                        : _saveSelectedInvoiceLines,
                                    icon: _savingInvoiceLinesPanel
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                      _savingInvoiceLinesPanel
                                          ? 'Enregistrement...'
                                          : 'Enregistrer les lignes',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (var index = 0; index < lines.length; index++) ...[
                          _buildStoredInvoiceLineTile(
                            index,
                            isLocked: isLocked,
                          ),
                          if (index < lines.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generatingPdf
                        ? null
                        : () => _generateInvoicePdf(invoice),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Générer PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canCancelInvoice(invoice)
                        ? () => _cancelInvoice(invoice)
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler la facture'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isCompactPanel) {
      return Positioned.fill(
        child: Material(
          color: Colors.black38,
          child: SafeArea(bottom: false, child: detailBody),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          elevation: 8,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
          child: detailBody,
        ),
      ),
    );
  }

  Widget _buildInvoiceParameterBlock({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceBankAccountDropdown(
    ClientInvoiceSummary invoice,
    String currentBankLabel,
  ) {
    final invoiceNumber = invoice.invoiceNumber;
    final isUpdating = _updatingInvoiceBankAccount.contains(invoiceNumber);
    final currentAccount =
        _findCompanyBankAccountForInvoiceLabel(currentBankLabel);
    final currentId = currentAccount?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compte bancaire',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: currentId,
                isExpanded: true,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: _companyBankAccounts.map((account) {
                  return DropdownMenuItem<int>(
                    value: account.id,
                    child: Text(
                      account.dropdownLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: isUpdating
                    ? null
                    : (newId) {
                        if (newId != null && newId != currentId) {
                          _changeInvoiceBankAccount(invoice, newId);
                        }
                      },
              ),
            ),
            if (isUpdating) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInvoicePaymentTermDropdown(
    ClientInvoiceSummary invoice,
    String currentTermLabel,
  ) {
    final invoiceNumber = invoice.invoiceNumber;
    final isUpdating = _updatingInvoicePaymentTerm.contains(invoiceNumber);
    final currentTerm = _findPaymentTermForInvoiceLabel(currentTermLabel);
    final currentId = currentTerm?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Condition de règlement',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: currentId,
                isExpanded: true,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: _invoiceDetailPaymentTerms.map((term) {
                  return DropdownMenuItem<int>(
                    value: term.id,
                    child: Text(
                      term.displayLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: isUpdating
                    ? null
                    : (newId) {
                        if (newId != null && newId != currentId) {
                          _changeInvoicePaymentTerm(invoice, newId);
                        }
                      },
              ),
            ),
            if (isUpdating) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceDateEditor(
    ClientInvoiceSummary invoice,
    DateTime? currentDate,
  ) {
    final invoiceNumber = invoice.invoiceNumber;
    final isUpdating = _updatingInvoiceDate.contains(invoiceNumber);
    final displayText = currentDate != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(currentDate)
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date création',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: isUpdating
                    ? null
                    : () => _pickInvoiceDate(invoice, currentDate),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF94A3B8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isUpdating) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickInvoiceDate(
    ClientInvoiceSummary invoice,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final initial = current ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: 'Date de création de la facture',
      cancelText: 'Annuler',
      confirmText: 'Sélectionner',
    );
    if (!mounted || picked == null) return;

    // Keep existing time if there was one, else use current time
    final existingTime = current != null
        ? TimeOfDay(hour: current.hour, minute: current.minute)
        : TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: existingTime,
      helpText: 'Heure',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (!mounted) return;

    final time = pickedTime ?? existingTime;
    final newDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    _changeInvoiceDate(invoice, newDate);
  }

  Future<void> _changeInvoiceDate(
    ClientInvoiceSummary invoice,
    DateTime newDate,
  ) async {
    final invoiceNumber = invoice.invoiceNumber;
    if (_updatingInvoiceDate.contains(invoiceNumber)) return;

    final optimistic = invoice.copyWith(
      createdAt: newDate,
      billedAt: newDate,
    );

    setState(() {
      _updatingInvoiceDate.add(invoiceNumber);
      _replaceInvoice(invoiceNumber, optimistic);
      if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
        _selectedInvoice = optimistic;
      }
    });

    try {
      await BillingService.updateInvoiceDate(
        invoiceNumber: invoiceNumber,
        newDate: newDate,
      );
      // confirmed — optimistic already applied
    } catch (_) {
      if (mounted) {
        setState(() {
          _replaceInvoice(invoiceNumber, invoice);
          if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
            _selectedInvoice = invoice;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mise à jour de la date impossible. Vérifiez votre connexion.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingInvoiceDate.remove(invoiceNumber));
      }
    }
  }

  Widget _buildInvoiceMissionTable({
    required ClientInvoiceSummary invoice,
    required List<_InvoiceMissionGroup> groups,
    required String? selectedMissionRef,
  }) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: Color(0xFF0F172A),
      fontSize: 12,
    );
    const cellStyle = TextStyle(color: Color(0xFF0F172A), fontSize: 12);

    Widget buildCell(
      String value, {
      required int flex,
      TextAlign textAlign = TextAlign.left,
      TextStyle? style,
    }) {
      return Expanded(
        flex: flex,
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style ?? cellStyle,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                buildCell('Réf mission', flex: 22, style: headerStyle),
                buildCell('Désignation', flex: 38, style: headerStyle),
                buildCell(
                  'P.U. HT',
                  flex: 16,
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
                buildCell(
                  'Qté',
                  flex: 10,
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
                buildCell(
                  'Total HT',
                  flex: 18,
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ],
            ),
          ),
          for (var index = 0; index < groups.length; index++) ...[
            Material(
              color: groups[index].missionRef == selectedMissionRef
                  ? const Color(0xFFF5F7FF)
                  : Colors.white,
              child: InkWell(
                onTap: () => _openInvoiceDetails(
                  invoice,
                  missionRef: groups[index].missionRef,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      buildCell(
                        groups[index].missionRef,
                        flex: 22,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      buildCell(
                        _invoiceMissionDesignation(groups[index]),
                        flex: 38,
                      ),
                      buildCell(
                        _invoiceMissionUnitPriceLabel(groups[index]),
                        flex: 16,
                        textAlign: TextAlign.right,
                      ),
                      buildCell(
                        _formatQuantity(groups[index].quantity),
                        flex: 10,
                        textAlign: TextAlign.right,
                      ),
                      buildCell(
                        _formatCurrency(groups[index].totalHt),
                        flex: 18,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index < groups.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceSummaryCard({
    required String label,
    required String value,
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
              fontSize: highlighted ? 20 : 18,
              color: highlighted ? const Color(0xFF000091) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInvoiceInfoTile(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 190),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceMetaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceLineTile(InvoiceLine line) {
    final designation = line.designation.trim().isEmpty
        ? 'Ligne sans libellé'
        : line.designation.trim();
    final notes = line.notes?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(designation, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Qté ${_formatQuantity(line.quantity)} • P.U. HT ${_formatCurrency(line.unitPrice)}',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          'Total HT ${_formatCurrency(line.totalHt)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            notes,
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildStoredInvoiceLineTile(int index, {required bool isLocked}) {
    final editor = _selectedInvoiceLineEditors[index];
    final line = editor.currentLine;
    if (isLocked) {
      return _buildInvoiceLineTile(line);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ligne ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _resetStoredInvoiceLine(index),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Annuler'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Désignation',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          _InlineEditableTextCell(
            key: ValueKey('detail-designation-$index'),
            width: double.infinity,
            text: line.designation,
            onChanged: (value) =>
                _updateStoredInvoiceLine(index, designation: value),
          ),
          const SizedBox(height: 10),
          const Text(
            'TVA',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<double>(
            initialValue: _tvaOptionFor(line.tvaRate),
            items: _tvaRates
                .map(
                  (rate) => DropdownMenuItem(
                    value: rate,
                    child: Text(
                      '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                _updateStoredInvoiceLine(index, tvaRate: value ?? 0),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'P.U. HT',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _InlineEditableNumberCell(
                      key: ValueKey('detail-unit-price-$index'),
                      width: double.infinity,
                      value: line.unitPrice,
                      onNumberChanged: (value) =>
                          _updateStoredInvoiceLine(index, unitPrice: value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qté',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _InlineEditableNumberCell(
                      key: ValueKey('detail-quantity-$index'),
                      width: double.infinity,
                      value: line.quantity,
                      fractionDigits: 3,
                      onNumberChanged: (value) =>
                          _updateStoredInvoiceLine(index, quantity: value),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'P.U. TTC',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        _formatCurrency(line.unitPriceTtc),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Réduc. %',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _InlineEditableNumberCell(
                      key: ValueKey('detail-discount-$index'),
                      width: double.infinity,
                      value: line.discount,
                      fractionDigits: 2,
                      onNumberChanged: (value) {
                        if (value != null && value >= 0 && value <= 100) {
                          _updateStoredInvoiceLine(index, discount: value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Notes',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          _InlineEditableTextCell(
            key: ValueKey('detail-notes-$index'),
            width: double.infinity,
            text: line.notes ?? '',
            onChanged: (value) => _updateStoredInvoiceLine(index, notes: value),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total HT : ${_formatCurrency(line.totalHt)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF000091),
                ),
              ),
              Text(
                'Total TTC : ${_formatCurrency(line.totalTtc)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openInvoiceDetails(ClientInvoiceSummary invoice, {String? missionRef}) {
    final effectiveMissionRef =
        (missionRef == null || missionRef.trim().isEmpty)
        ? null
        : missionRef.trim();
    final alreadySelected =
        _selectedInvoice?.invoiceNumber == invoice.invoiceNumber &&
        _selectedInvoiceMissionRef == effectiveMissionRef;
    setState(() {
      _selectedInvoice = invoice;
      _selectedInvoiceMissionRef = effectiveMissionRef;
      if (!alreadySelected) {
        _loadingInvoiceLinesPanel = true;
        _selectedInvoiceLineEditors.clear();
        _selectedInvoiceLines = null;
      }
    });
    if (!alreadySelected) {
      _loadInvoiceLines(invoice, missionRef: effectiveMissionRef);
      _loadInvoiceDetailPaymentTerms();
    }
  }

  void _closeInvoiceDetails() {
    setState(() {
      _selectedInvoice = null;
      _selectedInvoiceLines = null;
      _selectedInvoiceMissionRef = null;
      _selectedInvoiceLineEditors.clear();
      _loadingInvoiceLinesPanel = false;
      _savingInvoiceLinesPanel = false;
    });
  }

  Future<void> _loadInvoiceLines(
    ClientInvoiceSummary invoice, {
    String? missionRef,
  }) async {
    try {
      final result = await BillingService.fetchInvoiceLines(
        invoice.invoiceNumber,
        missionRef: missionRef,
      );
      if (!mounted) return;
      if (_selectedInvoice?.invoiceNumber != invoice.invoiceNumber ||
          _selectedInvoiceMissionRef != missionRef) {
        return;
      }
      setState(() {
        _selectedInvoiceLines = result;
        _selectedInvoiceLineEditors
          ..clear()
          ..addAll(
            result.lines.map(
              (line) => _EditableInvoiceLine(
                mission: null,
                originalLine: line.copy(),
                currentLine: line.copy(),
              ),
            ),
          );
        _loadingInvoiceLinesPanel = false;
      });
    } catch (error, stack) {
      debugPrint('Failed to load invoice lines: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() => _loadingInvoiceLinesPanel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger les lignes de ${invoice.invoiceNumber}.',
          ),
        ),
      );
    }
  }

  Future<void> _saveSelectedInvoiceLines() async {
    final invoice = _selectedInvoice;
    final missionRef = _selectedInvoiceMissionRef;
    if (invoice == null || missionRef == null || missionRef.trim().isEmpty) {
      return;
    }
    setState(() => _savingInvoiceLinesPanel = true);
    try {
      final result = await BillingService.updateInvoiceLines(
        invoiceNumber: invoice.invoiceNumber,
        missionRef: missionRef,
        lines: _selectedInvoiceLineEditors
            .map((editor) => editor.currentLine)
            .toList(growable: false),
        userId: AuthManager.userId,
        userName: AuthManager.userFullName,
      );
      if (!mounted) return;
      setState(() {
        _selectedInvoiceLines = result;
        _selectedInvoiceLineEditors
          ..clear()
          ..addAll(
            result.lines.map(
              (line) => _EditableInvoiceLine(
                mission: null,
                originalLine: line.copy(),
                currentLine: line.copy(),
              ),
            ),
          );
        _savingInvoiceLinesPanel = false;
      });
      await _loadInvoices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les lignes de facture ont été mises à jour.'),
        ),
      );
    } catch (error, stack) {
      debugPrint('Failed to update invoice lines: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() => _savingInvoiceLinesPanel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _updateStoredInvoiceLine(
    int index, {
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discount,
    String? notes,
  }) {
    if (index < 0 || index >= _selectedInvoiceLineEditors.length) return;
    setState(() {
      final line = _selectedInvoiceLineEditors[index].currentLine;
      if (designation != null) {
        line.designation = designation;
      }
      if (quantity != null && quantity > 0) {
        line.quantity = quantity;
      }
      if (unitPrice != null && unitPrice >= 0) {
        line.unitPrice = unitPrice;
      }
      if (tvaRate != null && tvaRate >= 0) {
        line.tvaRate = tvaRate;
      }
      if (discount != null && discount >= 0 && discount <= 100) {
        line.discount = discount;
      }
      if (notes != null) {
        line.notes = notes.trim().isEmpty ? null : notes;
      }
    });
  }

  void _resetStoredInvoiceLine(int index) {
    if (index < 0 || index >= _selectedInvoiceLineEditors.length) return;
    setState(() => _selectedInvoiceLineEditors[index].reset());
  }

  void _resetSelectedInvoiceLines() {
    setState(() {
      for (final editor in _selectedInvoiceLineEditors) {
        editor.reset();
      }
    });
  }

  Future<void> _changeInvoiceStatus(
    ClientInvoiceSummary invoice,
    String newLabel,
  ) async {
    final newCode = _invoiceStatusCodeForLabel(newLabel);
    final updated = invoice.copyWith(
      statusCode: newCode,
      statusLabel: newLabel,
    );
    final invoiceNumber = invoice.invoiceNumber;
    setState(() {
      _updatingInvoiceStatus.add(invoiceNumber);
      _replaceInvoice(invoiceNumber, updated);
      if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
        _selectedInvoice = updated;
      }
    });
    try {
      await BillingService.updateInvoiceStatus(
        invoiceNumber: invoiceNumber,
        statusCode: newCode,
        statusLabel: newLabel,
        userId: AuthManager.userId,
        userName: AuthManager.userFullName,
      );
    } catch (error, stack) {
      debugPrint('Failed to update invoice status: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() {
        _replaceInvoice(invoiceNumber, invoice);
        if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
          _selectedInvoice = invoice;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mise à jour du statut impossible. Vérifiez votre connexion.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingInvoiceStatus.remove(invoiceNumber));
      }
    }
  }

  void _replaceInvoice(String invoiceNumber, ClientInvoiceSummary replacement) {
    for (var index = 0; index < _invoices.length; index++) {
      if (_invoices[index].invoiceNumber == invoiceNumber) {
        _invoices[index] = _invoices[index].copyWith(
          statusCode: replacement.statusCode,
          statusLabel: replacement.statusLabel,
          invoiceTotalHt: replacement.invoiceTotalHt,
          amountHt: _invoices[index].amountHt,
          notes: replacement.notes,
          createdAt: replacement.createdAt,
          billedAt: replacement.billedAt,
        );
      }
    }
  }

  Future<void> _changeInvoiceBankAccount(
    ClientInvoiceSummary invoice,
    int bankAccountId,
  ) async {
    final invoiceNumber = invoice.invoiceNumber;
    if (_updatingInvoiceBankAccount.contains(invoiceNumber)) return;

    // Optimistic update
    final account = _companyBankAccounts.firstWhere(
      (a) => a.id == bankAccountId,
      orElse: () => _companyBankAccounts.first,
    );
    final optimisticLabel = account.dropdownLabel;
    final oldNotes = invoice.notes ?? '';
    final newNotes = _replaceNotesBankLabel(oldNotes, optimisticLabel);
    final optimistic = invoice.copyWith(notes: newNotes);

    setState(() {
      _updatingInvoiceBankAccount.add(invoiceNumber);
      _replaceInvoice(invoiceNumber, optimistic);
      if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
        _selectedInvoice = optimistic;
      }
    });

    try {
      final result = await BillingService.updateInvoiceBankAccount(
        invoiceNumber: invoiceNumber,
        bankAccountId: bankAccountId,
      );
      final confirmedNotes = result['notes'] ?? newNotes;
      final confirmed = invoice.copyWith(notes: confirmedNotes);
      if (mounted) {
        setState(() {
          _replaceInvoice(invoiceNumber, confirmed);
          if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
            _selectedInvoice = confirmed;
          }
        });
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _replaceInvoice(invoiceNumber, invoice);
          if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
            _selectedInvoice = invoice;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mise à jour du compte bancaire impossible. Vérifiez votre connexion.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingInvoiceBankAccount.remove(invoiceNumber));
      }
    }
  }

  /// Replaces the "Compte bancaire : ..." line in [notes] with [newLabel].
  String _replaceNotesBankLabel(String notes, String newLabel) {
    final newLine = 'Compte bancaire : $newLabel';
    final lines = notes.split('\n');
    var found = false;
    final updated = lines.map((line) {
      final trimmed = line.trim();
      final colonIdx = trimmed.indexOf(':');
      if (!found && colonIdx > 0) {
        final key = trimmed.substring(0, colonIdx).trim().toLowerCase();
        if (key == 'compte bancaire') {
          found = true;
          return newLine;
        }
      }
      return line;
    }).toList();
    if (!found) updated.add(newLine);
    return updated.join('\n').trim();
  }

  Future<void> _loadInvoiceDetailPaymentTerms() async {
    // Only load if we don't have them already
    if (_invoiceDetailPaymentTerms.isNotEmpty) return;
    try {
      final result = await BillingService.getAllPaymentTerms();
      if (mounted) {
        setState(() {
          _invoiceDetailPaymentTerms = result.paymentTerms;
        });
      }
    } catch (_) {
      // Payment terms will just not be editable; static display remains
    }
  }

  ClientPaymentTerm? _findPaymentTermForInvoiceLabel(String label) {
    final normalized = _normalizeLooseLabel(label);
    if (normalized.isEmpty) return null;
    for (final term in _invoiceDetailPaymentTerms) {
      final candidates = <String>[
        term.displayLabel,
        term.dropdownLabel,
        term.label,
        term.code,
      ];
      if (candidates.any(
        (c) => _normalizeLooseLabel(c) == normalized,
      )) {
        return term;
      }
    }
    return null;
  }

  Future<void> _changeInvoicePaymentTerm(
    ClientInvoiceSummary invoice,
    int termId,
  ) async {
    final invoiceNumber = invoice.invoiceNumber;
    if (_updatingInvoicePaymentTerm.contains(invoiceNumber)) return;

    final term = _invoiceDetailPaymentTerms.firstWhere(
      (t) => t.id == termId,
      orElse: () => _invoiceDetailPaymentTerms.first,
    );
    final optimisticLabel = term.displayLabel;
    final oldNotes = invoice.notes ?? '';
    final newNotes = _replaceNotesPaymentTermLabel(oldNotes, optimisticLabel);
    final optimistic = invoice.copyWith(notes: newNotes);

    setState(() {
      _updatingInvoicePaymentTerm.add(invoiceNumber);
      _replaceInvoice(invoiceNumber, optimistic);
      if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
        _selectedInvoice = optimistic;
      }
    });

    try {
      final result = await BillingService.updateInvoicePaymentTerm(
        invoiceNumber: invoiceNumber,
        termLabel: optimisticLabel,
      );
      final confirmedNotes = result['notes'] ?? newNotes;
      final confirmed = invoice.copyWith(notes: confirmedNotes);
      if (mounted) {
        setState(() {
          _replaceInvoice(invoiceNumber, confirmed);
          if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
            _selectedInvoice = confirmed;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _replaceInvoice(invoiceNumber, invoice);
          if (_selectedInvoice?.invoiceNumber == invoiceNumber) {
            _selectedInvoice = invoice;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mise à jour de la condition de règlement impossible. Vérifiez votre connexion.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingInvoicePaymentTerm.remove(invoiceNumber));
      }
    }
  }

  /// Replaces the "Condition de règlement : ..." line in [notes] with [newLabel].
  String _replaceNotesPaymentTermLabel(String notes, String newLabel) {
    final newLine = 'Condition de règlement : $newLabel';
    final lines = notes.split('\n');
    var found = false;
    final updated = lines.map((line) {
      final trimmed = line.trim();
      final colonIdx = trimmed.indexOf(':');
      if (!found && colonIdx > 0) {
        final key = trimmed.substring(0, colonIdx).trim().toLowerCase();
        if (key == 'condition de règlement') {
          found = true;
          return newLine;
        }
      }
      return line;
    }).toList();
    if (!found) updated.add(newLine);
    return updated.join('\n').trim();
  }

  Widget _buildLineEditorPanel(double spacing) {
    final index = _selectedLineIndex;
    if (index == null || index < 0 || index >= _lineEditors.length) {
      return const SizedBox.shrink();
    }
    final editor = _lineEditors[index];
    final line = editor.currentLine;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          elevation: 8,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          child: Container(
            padding: EdgeInsets.all(spacing),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Édition de la ligne',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: _closeLineEditor,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lineDesignationCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _updateSelectedLine(designation: value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lineQuantityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _updateSelectedLine(
                          quantity: double.tryParse(value.replaceAll(',', '.')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lineUnitPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Prix unitaire HT',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _updateSelectedLine(
                          unitPrice: double.tryParse(
                            value.replaceAll(',', '.'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: _tvaOptionFor(line.tvaRate),
                  items: _tvaRates
                      .map(
                        (rate) => DropdownMenuItem(
                          value: rate,
                          child: Text(
                            '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      _updateSelectedLine(tvaRate: value ?? 0),
                  decoration: const InputDecoration(
                    labelText: 'TVA',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lineNotesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _updateSelectedLine(notes: value),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total HT de la ligne : ${_formatCurrency(line.totalHt)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (editor.missionRef != null)
                        Text(
                          'Mission liée : ${editor.missionRef}',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _resetSelectedLine,
                      icon: const Icon(Icons.restore),
                      label: const Text('Réinitialiser la ligne'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _lineEditors.length == 1
                          ? null
                          : _resetAllLines,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Réinitialiser tout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLineEditor(int index) {
    if (index < 0 || index >= _lineEditors.length) return;
    setState(() {
      _selectedLineIndex = index;
      _showLinePanel = true;
    });
    _initLineControllers();
  }

  void _initLineControllers() {
    final index = _selectedLineIndex;
    if (index == null || index < 0 || index >= _lineEditors.length) return;
    final line = _lineEditors[index].currentLine;
    _lineDesignationCtrl?.dispose();
    _lineQuantityCtrl?.dispose();
    _lineUnitPriceCtrl?.dispose();
    _lineNotesCtrl?.dispose();
    _lineDesignationCtrl = TextEditingController(text: line.designation);
    _lineQuantityCtrl = TextEditingController(
      text: _quantityFormat.format(line.quantity),
    );
    _lineUnitPriceCtrl = TextEditingController(
      text: line.unitPrice.toStringAsFixed(2),
    );
    _lineNotesCtrl = TextEditingController(text: line.notes ?? '');
  }

  void _closeLineEditor() {
    setState(() {
      _showLinePanel = false;
      _selectedLineIndex = null;
    });
  }

  void _resetSelectedLine() {
    final index = _selectedLineIndex;
    if (index == null || index < 0 || index >= _lineEditors.length) return;
    setState(() {
      _lineEditors[index].reset();
    });
    _initLineControllers();
    _scheduleDraftSave();
  }

  void _resetAllLines() {
    if (_lineEditors.isEmpty) return;
    setState(() {
      for (final editor in _lineEditors) {
        editor.reset();
      }
    });
    _initLineControllers();
    _scheduleDraftSave();
  }

  void _deleteLine(int index) {
    if (index < 0 || index >= _lineEditors.length) return;
    setState(() {
      _lineEditors.removeAt(index);
      if (_selectedLineIndex == index) {
        _selectedLineIndex = null;
        _showLinePanel = false;
      } else if (_selectedLineIndex != null && _selectedLineIndex! > index) {
        _selectedLineIndex = _selectedLineIndex! - 1;
      }
    });
    _scheduleDraftSave();
  }

  void _updateLineFields(
    int index, {
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discount,
  }) {
    if (index < 0 || index >= _lineEditors.length) return;
    var changed = false;
    setState(() {
      final line = _lineEditors[index].currentLine;
      if (designation != null && designation != line.designation) {
        line.designation = designation;
        changed = true;
      }
      if (quantity != null && quantity > 0 && quantity != line.quantity) {
        line.quantity = quantity;
        changed = true;
      }
      if (unitPrice != null && unitPrice >= 0 && unitPrice != line.unitPrice) {
        line.unitPrice = unitPrice;
        changed = true;
      }
      if (tvaRate != null && tvaRate >= 0 && tvaRate != line.tvaRate) {
        line.tvaRate = tvaRate;
        changed = true;
      }
      if (discount != null && discount >= 0 && discount <= 100 && discount != line.discount) {
        line.discount = discount;
        changed = true;
      }
    });
    if (!changed) return;
    if (_selectedLineIndex == index) {
      final line = _lineEditors[index].currentLine;
      _lineDesignationCtrl?.text = line.designation;
      _lineQuantityCtrl?.text = _quantityFormat.format(line.quantity);
      _lineUnitPriceCtrl?.text = line.unitPrice.toStringAsFixed(2);
    }
    _scheduleDraftSave();
  }

  void _updateSelectedLine({
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    String? notes,
  }) {
    final index = _selectedLineIndex;
    if (index == null || index < 0 || index >= _lineEditors.length) return;
    setState(() {
      final line = _lineEditors[index].currentLine;
      if (designation != null) {
        line.designation = designation;
      }
      if (quantity != null && quantity > 0) {
        line.quantity = quantity;
      }
      if (unitPrice != null && unitPrice >= 0) {
        line.unitPrice = unitPrice;
      }
      if (tvaRate != null && tvaRate >= 0) {
        line.tvaRate = tvaRate;
      }
      if (notes != null) {
        line.notes = notes.isEmpty ? null : notes;
      }
    });
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 800),
      _persistDraftLines,
    );
  }

  Future<void> _saveCurrentDraftHeader() async {
    if (!_canSaveDraft) return;
    setState(() => _savingDraftHeader = true);
    try {
      final period = DateTime(_selectedMonth.year, _selectedMonth.month);
      final newDraftId = await BillingService.saveInvoiceDraft(
        draftId: _draftId,
        clientName: _currentClientName,
        periodMonth: period,
        paymentConditionId: _selectedClientPaymentTermId,
        bankAccountId: _selectedCompanyBankAccountId,
        totalHt: _currentTotalHt,
        userId: AuthManager.userId,
      );
      if (!mounted) return;
      setState(() => _draftId = newDraftId);
      // Synchroniser les lignes dans invoice_draft_lines maintenant que _draftId est connu
      _draftSaveTimer?.cancel();
      await _persistDraftLines();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préparation sauvegardée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );
    } finally {
      if (mounted) setState(() => _savingDraftHeader = false);
    }
  }

  Future<void> _persistDraftLines() async {
    if (!mounted || _lineEditors.isEmpty || _currentClientName.isEmpty) return;
    setState(() => _savingDraft = true);
    final period = DateTime(_selectedMonth.year, _selectedMonth.month);
    try {
      final key = await BillingService.saveInvoiceDraftLines(
        clientName: _currentClientName,
        periodMonth: period,
        lines: _lineEditors.map((editor) => editor.currentLine).toList(),
        userId: AuthManager.userId,
        userName: AuthManager.userFullName,
        draftKey: _draftKey,
        draftId: _draftId,
      );
      if (!mounted) return;
      setState(() => _draftKey = key);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d\'enregistrer les modifications (${error.toString()})',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _loadDraftLines() async {
    if (_currentClientName.isEmpty || _missions.isEmpty) return;
    setState(() => _loadingDraft = true);
    final period = DateTime(_selectedMonth.year, _selectedMonth.month);
    final key = BillingService.buildDraftKey(_currentClientName, period);
    try {
      final drafts = await BillingService.fetchInvoiceDraftLines(
        clientName: _currentClientName,
        periodMonth: period,
        draftKey: key,
      );
      if (!mounted) return;
      if (drafts.isNotEmpty) {
        setState(() => _draftKey = key);
        _rebuildInvoiceLines(draftLines: drafts);
      }
    } catch (error) {
      debugPrint('Draft load error: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingDraft = false);
      }
    }
  }

  Future<void> _loadMissionsForClient() async {
    final client = _currentClientName;
    if (client.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client.')),
      );
      return;
    }
    setState(() {
      _loadingMissions = true;
      _loadError = null;
      _draftId = null;
      _draftKey = null;
    });
    final normalized = client.toLowerCase();
    final capturedClientId = _selectedClientId;
    try {
      final missions = await MissionService.getMissionsDatatableAll(
        q: capturedClientId != null ? null : client,
        clientId: capturedClientId,
      );
      if (!mounted) return;
      final filtered = missions
          .where((mission) => _missionMatchesClient(mission, normalized, capturedClientId))
          .where(_isMissionEligibleForBilling)
          .map((mission) => Map<String, dynamic>.from(mission))
          .toList();
      setState(() {
        _allClientMissions = filtered;
        _loadingMissions = false;
        _missionTablePage = 1;
        _missionTableSearch = '';
      });
      _missionTableSearchCtrl.clear();
      await _loadClientPaymentTermsForMissions(filtered);
      await _loadCreationInvoicesForClient(force: true);
      // AMI v1.3 — RM-07 : proposer Reprendre/Ignorer si draft existe
      await _checkForExistingDraft();
      _applyMonthFilter();
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune mission facturable trouvée pour ce client sur les 12 derniers mois. Seules les missions Brouillon et Validées sont prises en compte.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMissions = false;
        _allClientMissions = [];
        _missions = [];
        _lineEditors.clear();
        _creationClientInvoices.clear();
        _clientPaymentTerms = [];
        _selectedClientPaymentTermId = null;
        _loadError = 'Impossible de récupérer les missions (connexion ou API).';
      });
    }
  }

  // ---------------------------------------------------------------
  // AMI v1.3 — Chargement des préparations
  // ---------------------------------------------------------------

  Future<void> _loadDrafts() async {
    if (mounted) setState(() { _loadingDrafts = true; _draftsError = null; });
    try {
      final drafts = await BillingService.getInvoiceDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loadingDrafts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDrafts = false;
        _draftsError = e.toString();
      });
    }
  }

  /// Vérifie si un draft actif existe pour le client + mois sélectionnés.
  /// Si oui, propose Reprendre / Ignorer (RM-07).
  /// Retourne true si l'utilisateur a choisi de reprendre.
  Future<bool> _checkForExistingDraft() async {
    final client = _currentClientName;
    final period = _selectedMonth;
    if (client.isEmpty) return false;

    List<InvoiceDraftSummary> existing;
    try {
      existing = await BillingService.getInvoiceDrafts(
        clientName: client,
        month: '${period.year}-${period.month.toString().padLeft(2, '0')}',
      );
    } catch (_) {
      return false; // En cas d'erreur API, on n'interrompt pas le workflow
    }

    if (existing.isEmpty) return false;

    final draft = existing.first;
    if (!mounted) return false;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Préparation en cours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Une préparation existe pour ${draft.clientName ?? client}.'),
            const SizedBox(height: 4),
            Text('Mois : ${draft.month}   Total : ${draft.totalHt.toStringAsFixed(2)} €',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Que souhaitez-vous faire ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('ignore'),
            child: const Text('Ignorer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('resume'),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );

    if (choice == 'resume') {
      await _restoreFromDraft(draft);
      return true;
    }
    // 'ignore' ou fermeture : draft intact, on charge les missions brutes
    return false;
  }

  /// Restaure les lignes de facturation depuis un draft existant.
  Future<void> _restoreFromDraft(InvoiceDraftSummary draft) async {
    if (!mounted) return;
    setState(() => _loadingDraft = true);
    try {
      final result = await BillingService.fetchInvoiceDraftLines(
        clientName: draft.clientName ?? _currentClientName,
        periodMonth: DateTime(
          int.parse(draft.month.split('-')[0]),
          int.parse(draft.month.split('-')[1]),
        ),
      );
      if (!mounted) return;
      setState(() {
        _draftId = draft.draftId;
        _draftKey = null; // sera regénéré au prochain autosave
        _lineEditors.clear();
        for (final line in result) {
          _lineEditors.add(_EditableInvoiceLine(
            mission: null,
            originalLine: line.copy(),
            currentLine: line.copy(),
          ));
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de restaurer la préparation : $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  // ---------------------------------------------------------------
  // AMI v1.3/1.4 — Vue Préparations + Devis
  // ---------------------------------------------------------------

  Widget _buildPreparationsView(double spacing) {
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Factures initiées',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
                onPressed: _loadDrafts,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Factures sauvegardées mais non encore finalisées.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildDraftsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList() {
    if (_loadingDrafts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_draftsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 32),
            const SizedBox(height: 8),
            Text(_draftsError!, style: const TextStyle(color: Color(0xFFB91C1C))),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadDrafts, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_drafts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_copy_outlined, size: 40, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text('Aucune préparation en cours.',
                style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _drafts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        return ListTile(
          leading: const Icon(Icons.description_outlined, color: Color(0xFF1E3A8A)),
          title: Text(draft.clientName ?? '(client inconnu)',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Mois : ${draft.month}   •   Total : ${draft.totalHt.toStringAsFixed(2)} €',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('Reprendre'),
                onPressed: () async {
                  await _restoreFromDraft(draft);
                  if (mounted) _setActiveSection(BillingSection.creation);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
                tooltip: 'Supprimer',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer la préparation ?'),
                      content: Text(
                        'La préparation de ${draft.clientName ?? 'ce client'} (${draft.month}) sera supprimée définitivement.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await BillingService.deleteInvoiceDraft(draftId: draft.draftId);
                      await _loadDrafts();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCreateInvoice() async {
    final validationMessage = _validateInvoiceActionRequirements(
      forCreation: true,
    );
    if (validationMessage != null) {
      _setCreateInvoiceState(_CreateInvoiceActionState.error);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer la facture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client : $_currentClientName'),
            Text('Mois : ${_monthLabel(_selectedMonth)}'),
            Text('Lignes : ${_lineEditors.length}'),
            Text('Total HT : ${_formatCurrency(_currentTotalHt)}'),
            Text('Total TTC : ${_formatCurrency(_currentTotalTtc)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _createInvoiceFromTable();
  }

  Future<void> _createInvoiceFromTable() async {
    final validationMessage = _validateInvoiceActionRequirements(
      forCreation: true,
    );
    if (validationMessage != null) {
      _setCreateInvoiceState(_CreateInvoiceActionState.error);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    final billingMissions = _buildBillingMissionsPayload(_lineEditors);
    if (billingMissions.isEmpty) {
      _setCreateInvoiceState(_CreateInvoiceActionState.error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de créer la facture : aucune référence mission exploitable n\'a été trouvée.',
          ),
        ),
      );
      return;
    }

    final lines = _lineEditors.map((editor) => editor.currentLine).toList();
    final now = DateTime.now();
    _setCreateInvoiceState(_CreateInvoiceActionState.loading, keepState: true);
    try {
      final invoiceNumber = await BillingService.reserveNextInvoiceNumber(
        year: now.year,
        month: now.month,
      );
      await _ensurePdfAssets();
      final pdfFile = await _buildInvoicePdfFile(
        invoiceNumber: invoiceNumber,
        billedAt: now,
        clientName: _currentClientName.isEmpty
            ? 'Client non renseigné'
            : _currentClientName,
        clientAddressLines: _clientAddressLinesForPdf(),
        clientCode: _clientCodeForPdf(),
        paymentTermLabel: _selectedClientPaymentTermLabel,
        companyInfo: await _loadCompanyInfoForPdf(),
        lines: lines,
        filenameSeed: invoiceNumber,
      );
      await BillingService.logClientBilling(
        clientName: _currentClientName,
        invoiceNumber: invoiceNumber,
        statusCode: 'draft',
        statusLabel: 'Brouillon',
        billedAt: now,
        amountTotal: _currentTotalHt,
        missions: billingMissions,
        invoiceLines: lines,
        userId: AuthManager.userId,
        userName: AuthManager.userFullName,
        pdfBytes: pdfFile.bytes,
        pdfFilename: pdfFile.filename,
        periodMonth: _selectedMonth,
        draftKey: _draftKey,
        draftId: _draftId,
        notes: _buildInvoiceCreationNotes(),
      );
      if (mounted) {
        setState(() { _draftKey = null; _draftId = null; });
      }
      await _loadCreationInvoicesForClient(force: true);
      await _loadInvoices(reset: true);
      _setCreateInvoiceState(_CreateInvoiceActionState.success);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Facture $invoiceNumber créée.')));
    } catch (error, stack) {
      debugPrint('Invoice creation failed: $error');
      debugPrint(stack.toString());
      _setCreateInvoiceState(_CreateInvoiceActionState.error);
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _generatePdfFromTable() async {
    final validationMessage = _validateInvoiceActionRequirements(
      forCreation: false,
    );
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    if (_lineEditors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chargez des missions avant de générer un PDF.'),
        ),
      );
      return;
    }
    setState(() => _generatingPdf = true);
    final lines = _lineEditors.map((editor) => editor.currentLine).toList();
    try {
      await _ensurePdfAssets();
      final clientLabel = _currentClientName.isEmpty
          ? 'Client non renseigné'
          : _currentClientName;
      final now = DateTime.now();
      final invoiceNumber = await BillingService.reserveNextInvoiceNumber(
        year: now.year,
        month: now.month,
      );
      await _saveInvoicePdf(
        invoiceNumber: invoiceNumber,
        billedAt: now,
        clientName: clientLabel,
        clientAddressLines: _clientAddressLinesForPdf(),
        clientCode: _clientCodeForPdf(),
        paymentTermLabel: _selectedClientPaymentTermLabel,
        companyInfo: await _loadCompanyInfoForPdf(),
        lines: lines,
        filenameClientSeed: _currentClientName,
      );
    } catch (e, stack) {
      debugPrint('PDF generation failed: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de générer le PDF. Veuillez réessayer.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingPdf = false);
      }
    }
  }

  Future<void> _saveInvoicePdf({
    required String invoiceNumber,
    required DateTime billedAt,
    required String clientName,
    required List<String> clientAddressLines,
    required String clientCode,
    required String? paymentTermLabel,
    required CompanyInfo companyInfo,
    required List<InvoiceLine> lines,
    required String filenameClientSeed,
  }) async {
    final pdfFile = await _buildInvoicePdfFile(
      invoiceNumber: invoiceNumber,
      billedAt: billedAt,
      clientName: clientName,
      clientAddressLines: clientAddressLines,
      clientCode: clientCode,
      paymentTermLabel: paymentTermLabel,
      companyInfo: companyInfo,
      lines: lines,
      filenameSeed: filenameClientSeed,
    );
    if (canSavePdfToDownloads) {
      await savePdfToDownloads(pdfFile.bytes, pdfFile.filename);
    } else {
      await Printing.layoutPdf(
        name: pdfFile.filename,
        onLayout: (_) async => pdfFile.bytes,
      );
    }
  }

  Future<({Uint8List bytes, String filename})> _buildInvoicePdfFile({
    required String invoiceNumber,
    required DateTime billedAt,
    required String clientName,
    required List<String> clientAddressLines,
    required String clientCode,
    required String? paymentTermLabel,
    required CompanyInfo companyInfo,
    required List<InvoiceLine> lines,
    required String filenameSeed,
  }) async {
    final headers = ['Désignation', 'TVA', 'P.U. HT', 'Qté', 'Total HT'];
    final rows = lines
        .map(
          (line) => [
            line.designation,
            _formatTvaValue(line.tvaRate),
            _formatCurrency(line.unitPrice),
            _formatQuantity(line.quantity),
            _formatCurrency(line.totalHt),
          ],
        )
        .toList(growable: false);
    final invoiceTotalHt = lines.fold<double>(
      0,
      (sum, line) => sum + line.totalHt,
    );
    final invoiceTotalTtc = lines.fold<double>(
      0,
      (sum, line) => sum + (line.totalHt * (1 + (line.tvaRate / 100))),
    );
    final billedAtLabel = DateFormat('dd/MM/yyyy').format(billedAt);
    final theme = pw.ThemeData.withFont(
      base: _pdfFontRegular!,
      bold: _pdfFontBold!,
    );
    final doc = pw.Document(theme: theme);
    final accent = PdfColor.fromHex('#000091');
    final borderColor = PdfColor.fromHex('#E5E7EB');
    final companyLines = _companyInfoLinesForPdf(companyInfo);
    final hasBankDetails = companyInfo.hasBankDetails;
    final hasLogo = _pdfLogoImage != null;
    final logoWidget = hasLogo
        ? pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            height: 48,
            child: pw.Image(_pdfLogoImage!, fit: pw.BoxFit.contain),
          )
        : null;
    final companyCard = (companyLines.isEmpty && !hasLogo)
        ? null
        : pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9FAFB'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Émetteur',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                    fontSize: _pdfFontSize(12),
                  ),
                ),
                pw.SizedBox(height: 4),
                ...companyLines.asMap().entries.map(
                  (entry) => pw.Text(
                    entry.value,
                    style: pw.TextStyle(
                      fontSize: _pdfFontSize(entry.key == 0 ? 11.6 : 11),
                      fontWeight: entry.key == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
    final clientCard = pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FDF2F8'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#FBCFE8'), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Destinataire',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#BE185D'),
              fontSize: _pdfFontSize(12),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            clientName,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: _pdfFontSize(11.6),
              lineSpacing: 1.05,
            ),
          ),
          if (clientAddressLines.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            ...clientAddressLines.map(
              (line) => pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: _pdfFontSize(12),
                  lineSpacing: 1.05,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    final invoiceMetaCard = pw.Container(
      constraints: const pw.BoxConstraints(maxWidth: 220),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EEF2FF'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE'), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Facture $invoiceNumber',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: _pdfFontSize(11.6),
              color: accent,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Date de facturation : $billedAtLabel',
            style: pw.TextStyle(fontSize: _pdfFontSize(9.5)),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Code client : $clientCode',
            style: pw.TextStyle(fontSize: _pdfFontSize(9.5)),
          ),
        ],
      ),
    );
    final headerColumns = <pw.Widget>[];
    if (companyCard != null) {
      headerColumns.add(pw.Expanded(flex: 3, child: companyCard));
      headerColumns.add(pw.SizedBox(width: 14));
    }
    headerColumns.add(pw.Expanded(flex: 3, child: clientCard));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        footer: (context) => _buildPdfFooter(context, companyInfo: companyInfo),
        build: (context) => [
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: logoWidget == null
                    ? pw.SizedBox()
                    : pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: logoWidget,
                      ),
              ),
              pw.SizedBox(width: 16),
              invoiceMetaCard,
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: headerColumns,
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: borderColor, width: 0.25),
              outside: pw.BorderSide(color: borderColor, width: 0.5),
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: _pdfFontSize(10.5),
            ),
            headerDecoration: pw.BoxDecoration(color: accent),
            cellStyle: pw.TextStyle(fontSize: _pdfFontSize(10.5)),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (hasBankDetails || paymentTermLabel != null)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (paymentTermLabel != null) ...[
                        _buildPdfPaymentTermBlock(
                          paymentTermLabel,
                          borderColor: borderColor,
                        ),
                        if (hasBankDetails) pw.SizedBox(height: 8),
                      ],
                      if (hasBankDetails)
                        _buildPdfBankTransferBlock(
                          companyInfo,
                          borderColor: borderColor,
                        ),
                    ],
                  ),
                )
              else
                pw.Spacer(),
              if (hasBankDetails || paymentTermLabel != null)
                pw.SizedBox(width: 16),
              pw.Container(
                width: 210,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfTotalRow(
                      label: 'Total HT',
                      value: _formatCurrency(invoiceTotalHt),
                    ),
                    _buildPdfTotalRow(
                      label: 'Total TTC',
                      value: _formatCurrency(invoiceTotalTtc),
                      highlighted: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(billedAt);
    final sanitizedInvoice = invoiceNumber.trim().isEmpty
      ? 'sans_numero'
      : invoiceNumber.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final sanitizedCompany = filenameSeed.trim().isEmpty
      ? clientName.trim().isEmpty
        ? 'client'
        : clientName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      : filenameSeed.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final filename =
      'Facture_${sanitizedInvoice}_${sanitizedCompany}_$timestamp.pdf';
    return (bytes: bytes, filename: filename);
  }

  Future<void> _loadCreationInvoicesForClient({bool force = false}) async {
    final client = _currentClientName;
    if (client.isEmpty) {
      if (!mounted) return;
      setState(() {
        _creationClientInvoices.clear();
        _loadingCreationClientInvoices = false;
      });
      return;
    }
    if (!force &&
        _creationClientInvoices.isNotEmpty &&
        !_loadingCreationClientInvoices) {
      return;
    }
    if (mounted) {
      setState(() => _loadingCreationClientInvoices = true);
    }
    try {
      final result = await BillingService.getClientInvoices(
        clientName: client,
        page: 1,
        pageSize: 200,
      );
      if (!mounted || client != _currentClientName) return;
      setState(() {
        _creationClientInvoices
          ..clear()
          ..addAll(result.invoices);
        _loadingCreationClientInvoices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCreationClientInvoices = false);
    }
  }

  Future<void> _ensurePdfAssets() async {
    _pdfFontRegular ??= await PdfGoogleFonts.openSansRegular();
    _pdfFontBold ??= await PdfGoogleFonts.openSansBold();
    if (_pdfLogoImage == null) {
      try {
        final data = await rootBundle.load('assets/logo.png');
        final Uint8List bytes = data.buffer.asUint8List();
        _pdfLogoImage = pw.MemoryImage(bytes);
      } catch (_) {
        _pdfLogoImage = null;
      }
    }
  }

  void _applyMonthFilter() {
    final filtered = _allClientMissions.where((mission) {
      if (!_isMissionEligibleForBilling(mission)) return false;
      final date = _missionDate(mission);
      if (date == null) return false;
      return date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();
    filtered.sort((a, b) {
      final dateA = _missionDate(a);
      final dateB = _missionDate(b);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final dc = dateA.compareTo(dateB);
      if (dc != 0) return dc;
      final heureA = (a['heuredebutmission'] ?? a['heure_debut'] ?? '').toString();
      final heureB = (b['heuredebutmission'] ?? b['heure_debut'] ?? '').toString();
      return heureA.compareTo(heureB);
    });
    setState(() {
      _missions = filtered;
    });
    _rebuildInvoiceLines();
    _loadDraftLines();
  }

  void _rebuildInvoiceLines({List<InvoiceLine>? draftLines}) {
    final missionByRef = <String, Map<String, dynamic>>{};
    for (final mission in _missions) {
      final ref = _missionRef(mission);
      if (ref != null && ref.isNotEmpty) {
        missionByRef[ref] = mission;
      }
    }
    final newEditors = <_EditableInvoiceLine>[];
    final consumedRefs = <String>{};
    if (draftLines != null && draftLines.isNotEmpty) {
      for (final draft in draftLines) {
        final mission = draft.missionRef != null
            ? missionByRef[draft.missionRef!]
            : null;
        final original = mission != null
            ? _invoiceLineFromMission(mission)
            : draft.copy();
        newEditors.add(
          _EditableInvoiceLine(
            mission: mission,
            originalLine: original,
            currentLine: draft.copy(),
          ),
        );
        if (draft.missionRef != null) consumedRefs.add(draft.missionRef!);
      }
    }
    for (final mission in _missions) {
      final ref = _missionRef(mission);
      if (ref != null && consumedRefs.contains(ref)) continue;
      final line = _invoiceLineFromMission(mission);
      newEditors.add(
        _EditableInvoiceLine(
          mission: mission,
          originalLine: line,
          currentLine: line.copy(),
        ),
      );
    }
    newEditors.sort((a, b) {
      final dateA = a.mission != null ? _missionDate(a.mission!) : null;
      final dateB = b.mission != null ? _missionDate(b.mission!) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final dc = dateA.compareTo(dateB);
      if (dc != 0) return dc;
      final heureA = (a.mission?['heuredebutmission'] ?? a.mission?['heure_debut'] ?? '').toString();
      final heureB = (b.mission?['heuredebutmission'] ?? b.mission?['heure_debut'] ?? '').toString();
      return heureA.compareTo(heureB);
    });
    setState(() {
      _lineEditors
        ..clear()
        ..addAll(newEditors);
      _selectedLineIndex = null;
      _showLinePanel = false;
    });
  }

  InvoiceLine _invoiceLineFromMission(Map<String, dynamic> mission) {
    return InvoiceLine.fromMission(
      mission,
      unitPriceResolver: _unitPriceForMission,
      lineTotalResolver: _lineTotalFor,
      designationResolver: _designationFor,
    );
  }

  Future<void> _loadCompanyInfo() async {
    if (_loadingCompanyInfo) return;
    setState(() => _loadingCompanyInfo = true);
    try {
      final info = await CompanyInfoService.fetch();
      if (!mounted) return;
      final selectedBankAccountId = _resolveSelectedCompanyBankAccountId(
        accounts: _companyBankAccounts,
        currentSelectedId: _selectedCompanyBankAccountId,
        companyInfo: info,
      );
      setState(() {
        _companyInfo = info;
        _selectedCompanyBankAccountId = selectedBankAccountId;
        _loadingCompanyInfo = false;
      });
    } catch (error, stack) {
      debugPrint('Failed to load company info: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      final fallbackInfo = CompanyInfo.fallback();
      final selectedBankAccountId = _resolveSelectedCompanyBankAccountId(
        accounts: _companyBankAccounts,
        currentSelectedId: _selectedCompanyBankAccountId,
        companyInfo: fallbackInfo,
      );
      setState(() {
        _companyInfo = fallbackInfo;
        _selectedCompanyBankAccountId = selectedBankAccountId;
        _loadingCompanyInfo = false;
      });
    }
  }

  Future<void> _loadCompanyBankAccounts() async {
    if (_loadingCompanyBankAccounts) return;
    setState(() => _loadingCompanyBankAccounts = true);
    try {
      final accounts = await CompanyInfoService.fetchBankAccounts();
      if (!mounted) return;
      final selectedBankAccountId = _resolveSelectedCompanyBankAccountId(
        accounts: accounts,
        currentSelectedId: _selectedCompanyBankAccountId,
        companyInfo: _companyInfo,
      );
      setState(() {
        _companyBankAccounts = accounts;
        _selectedCompanyBankAccountId = selectedBankAccountId;
        _loadingCompanyBankAccounts = false;
      });
    } catch (error, stack) {
      debugPrint('Failed to load company bank accounts: $error');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() => _loadingCompanyBankAccounts = false);
    }
  }

  Future<void> _loadClientPaymentTermsForMissions(
    List<Map<String, dynamic>> missions,
  ) async {
    final clientId = _clientIdFromMissions(missions);
    if (clientId == null || clientId <= 0) {
      if (!mounted) {
        _clientPaymentTerms = [];
        _selectedClientPaymentTermId = null;
        return;
      }
      setState(() {
        _clientPaymentTerms = [];
        _selectedClientPaymentTermId = null;
      });
      return;
    }
    if (mounted) {
      setState(() => _loadingClientPaymentTerms = true);
    } else {
      _loadingClientPaymentTerms = true;
    }
    try {
      final result = await BillingService.getClientPaymentTerms(
        clientId: clientId,
      );
      final selectedId = _resolveSelectedClientPaymentTermId(
        terms: result.paymentTerms,
        currentSelectedId: _selectedClientPaymentTermId,
        defaultTermId: result.defaultTermId,
      );
      if (!mounted) {
        _clientPaymentTerms = result.paymentTerms;
        _selectedClientPaymentTermId = selectedId;
        _loadingClientPaymentTerms = false;
        return;
      }
      setState(() {
        _clientPaymentTerms = result.paymentTerms;
        _selectedClientPaymentTermId = selectedId;
        _loadingClientPaymentTerms = false;
      });
    } catch (error, stack) {
      debugPrint('Failed to load client payment terms: $error');
      debugPrint(stack.toString());
      if (!mounted) {
        _clientPaymentTerms = [];
        _selectedClientPaymentTermId = null;
        _loadingClientPaymentTerms = false;
        return;
      }
      setState(() {
        _clientPaymentTerms = [];
        _selectedClientPaymentTermId = null;
        _loadingClientPaymentTerms = false;
      });
    }
  }

  Future<CompanyInfo> _loadCompanyInfoForPdf() async {
    try {
      final info = await CompanyInfoService.fetch();
      if (mounted) {
        setState(() => _companyInfo = info);
      } else {
        _companyInfo = info;
      }
      return _applySelectedCompanyBankAccount(info);
    } catch (_) {
      return _applySelectedCompanyBankAccount(_resolvedCompanyInfo);
    }
  }

  Future<void> _loadInvoices({bool reset = false}) async {
    if (reset) {
      _invoicePage = 1;
    }
    setState(() {
      _loadingInvoices = true;
      _invoiceError = null;
    });
    try {
      final result = await BillingService.getClientInvoices(
        page: _invoicePage,
        pageSize: _invoicePageSize,
        clientName:
            _invoiceClientFilter.isEmpty ||
                _invoiceClientFilter == 'Tous les clients'
            ? null
            : _invoiceClientFilter,
        invoiceNumber: _pendingOpenInvoiceNumber,
      );
      if (!mounted) return;
      final previouslySelected = _selectedInvoice;
      final selectedMissionRef = _selectedInvoiceMissionRef;
      setState(() {
        _invoices
          ..clear()
          ..addAll(result.invoices);
        _invoiceTotal = result.total;
        _invoicePage = result.page;
        _loadingInvoices = false;
        if (previouslySelected != null) {
          ClientInvoiceSummary? refreshed;
          for (final invoice in result.invoices) {
            if (invoice.invoiceNumber == previouslySelected.invoiceNumber &&
                invoice.missionRef == selectedMissionRef) {
              refreshed = invoice;
              break;
            }
          }
          refreshed ??= result.invoices
              .cast<ClientInvoiceSummary?>()
              .firstWhere(
                (invoice) =>
                    invoice?.invoiceNumber == previouslySelected.invoiceNumber,
                orElse: () => null,
              );
          if (refreshed != null) {
            _selectedInvoice = refreshed;
            _selectedInvoiceMissionRef = refreshed.missionRef;
          } else {
            _selectedInvoice = null;
            _selectedInvoiceLines = null;
            _selectedInvoiceMissionRef = null;
            _selectedInvoiceLineEditors.clear();
            _loadingInvoiceLinesPanel = false;
          }
        }
        // Auto-ouverture si navigation depuis le tableau des missions
        if (_pendingOpenInvoiceNumber != null && _selectedInvoice == null) {
          final pending = _pendingOpenInvoiceNumber!;
          final match = _invoices.cast<ClientInvoiceSummary?>().firstWhere(
            (inv) => inv?.invoiceNumber == pending,
            orElse: () => null,
          );
          if (match != null) {
            _pendingOpenInvoiceNumber = null;
            _selectedInvoice = match;
            _selectedInvoiceMissionRef = match.missionRef;
            _loadingInvoiceLinesPanel = true;
            _selectedInvoiceLineEditors.clear();
            _selectedInvoiceLines = null;
          }
        }
      });
      // Charger les lignes si auto-ouverture
      if (_pendingOpenInvoiceNumber == null && _selectedInvoice != null && _loadingInvoiceLinesPanel) {
        _loadInvoiceLines(_selectedInvoice!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingInvoices = false;
        _invoiceError = error.toString();
      });
    }
  }

  void _toggleTableFullscreen(bool value) {
    if (_isTableFullscreen == value) return;
    setState(() {
      _isTableFullscreen = value;
      if (value) {
        _showLinePanel = false;
      }
    });
  }

  String _invoiceStatusLabelFor(ClientInvoiceSummary invoice) {
    final code = invoice.statusCode.trim().toLowerCase();
    if (_invoiceCodeToLabel.containsKey(code)) {
      return _invoiceCodeToLabel[code]!;
    }
    final label = invoice.statusLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return 'Brouillon';
  }

  String _invoiceStatusCodeForLabel(String label) {
    return _invoiceStatusToCode[label] ?? 'draft';
  }

  bool _isInvoiceStatusBeingUpdated(String invoiceNumber) =>
      _updatingInvoiceStatus.contains(invoiceNumber);

  bool get _hasSelectedInvoiceLineChanges {
    for (final editor in _selectedInvoiceLineEditors) {
      if (!_invoiceLinesEqual(editor.originalLine, editor.currentLine)) {
        return true;
      }
    }
    return false;
  }

  double get _selectedMissionTotalHt => _selectedInvoiceLineEditors.fold(
    0,
    (sum, editor) => sum + editor.currentLine.totalHt,
  );

  bool _isInvoiceLockedForEdition(ClientInvoiceSummary invoice) {
    final statusCode = invoice.statusCode.trim().toLowerCase();
    if (statusCode == 'paid') {
      return true;
    }
    final statusLabel = _invoiceStatusLabelFor(invoice).trim().toLowerCase();
    return statusLabel == 'payée';
  }

  bool _invoiceLinesEqual(InvoiceLine left, InvoiceLine right) {
    return left.missionRef == right.missionRef &&
        left.designation == right.designation &&
        left.unitPrice == right.unitPrice &&
        left.quantity == right.quantity &&
        left.tvaRate == right.tvaRate &&
        left.discount == right.discount &&
        (left.notes ?? '') == (right.notes ?? '');
  }

  String get _currentClientName => _clientInput.trim();
  double get _currentTotalHt =>
      _lineEditors.fold(0, (sum, editor) => sum + editor.currentLine.totalHt);
  double get _currentTotalTtc =>
      _lineEditors.fold(0, (sum, editor) => sum + editor.currentLine.totalTtc);

  // --- Pagination / filtrage du tableau des lignes ---

  List<MapEntry<int, _EditableInvoiceLine>> get _filteredIndexedEditors {
    if (_missionTableSearch.trim().isEmpty) {
      return _lineEditors.asMap().entries.toList();
    }
    final q = _missionTableSearch.trim().toLowerCase();
    return _lineEditors.asMap().entries.where((e) {
      final line = e.value.currentLine;
      final ref = (e.value.missionRef ?? line.missionRef ?? '').toLowerCase();
      final designation = line.designation.toLowerCase();
      return ref.contains(q) || designation.contains(q);
    }).toList();
  }

  int get _missionTableFilteredCount => _filteredIndexedEditors.length;

  int get _missionTablePageCount {
    final count = _missionTableFilteredCount;
    if (count == 0) return 1;
    return (count / _missionTablePageSize).ceil();
  }

  List<MapEntry<int, _EditableInvoiceLine>> get _paginatedIndexedEditors {
    final filtered = _filteredIndexedEditors;
    final start = (_missionTablePage - 1) * _missionTablePageSize;
    if (start >= filtered.length) return filtered;
    final end = math.min(start + _missionTablePageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  bool get _hasRequiredInvoiceSettings =>
      _selectedClientPaymentTerm != null && _selectedCompanyBankAccount != null;

  bool get _canLoadMissions =>
      !_loadingMissions && _currentClientName.isNotEmpty;

  bool get _canSaveDraft =>
      !_savingDraftHeader &&
      _currentClientName.isNotEmpty &&
      _lineEditors.isNotEmpty;

  bool get _canGeneratePdf =>
      !_generatingPdf &&
      _currentClientName.isNotEmpty &&
      _lineEditors.isNotEmpty &&
      _hasRequiredInvoiceSettings;

  bool get _canCreateInvoice =>
      _createInvoiceState != _CreateInvoiceActionState.loading &&
      !_loadingCreationClientInvoices &&
      _currentClientName.isNotEmpty &&
      _lineEditors.isNotEmpty &&
      _hasRequiredInvoiceSettings &&
      _currentPeriodInvoiceConflictMessage == null;

  String get _createInvoiceButtonLabel {
    return switch (_createInvoiceState) {
      _CreateInvoiceActionState.loading => 'Création...',
      _CreateInvoiceActionState.success => 'Facture créée !',
      _CreateInvoiceActionState.error => 'Erreur',
      _ => 'Créer la facture',
    };
  }

  Widget _buildCreateInvoiceButtonIcon() {
    return switch (_createInvoiceState) {
      _CreateInvoiceActionState.loading => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      _CreateInvoiceActionState.success => const Icon(Icons.check),
      _CreateInvoiceActionState.error => const Icon(Icons.close),
      _ => const Icon(Icons.save_outlined),
    };
  }

  void _setCreateInvoiceState(
    _CreateInvoiceActionState state, {
    bool keepState = false,
  }) {
    _createInvoiceFeedbackTimer?.cancel();
    if (mounted) {
      setState(() => _createInvoiceState = state);
    } else {
      _createInvoiceState = state;
    }
    if (keepState ||
        (state != _CreateInvoiceActionState.success &&
            state != _CreateInvoiceActionState.error)) {
      return;
    }
    final delay = state == _CreateInvoiceActionState.success
        ? const Duration(seconds: 2)
        : const Duration(seconds: 3);
    _createInvoiceFeedbackTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _createInvoiceState = _CreateInvoiceActionState.idle);
    });
  }

  String? _validateInvoiceActionRequirements({required bool forCreation}) {
    if (_currentClientName.isEmpty) {
      return 'Veuillez sélectionner un client.';
    }
    if (_lineEditors.isEmpty) {
      return forCreation
          ? 'Chargez des missions avant de créer la facture.'
          : 'Chargez des missions avant de générer un PDF.';
    }
    if (_selectedClientPaymentTerm == null) {
      return 'Veuillez sélectionner une condition de règlement.';
    }
    if (_selectedCompanyBankAccount == null) {
      return 'Veuillez sélectionner un compte bancaire.';
    }
    if (forCreation && _currentPeriodInvoiceConflictMessage != null) {
      return _currentPeriodInvoiceConflictMessage;
    }
    return null;
  }

  ClientInvoiceSummary? get _existingInvoiceForCurrentPeriod {
    for (final invoice in _creationClientInvoices) {
      final period = invoice.periodMonth;
      if (period == null) continue;
      final sameMonth =
          period.year == _selectedMonth.year &&
          period.month == _selectedMonth.month;
      if (!sameMonth) continue;
      final statusCode = invoice.statusCode.trim().toLowerCase();
      if (statusCode == 'draft' || statusCode == 'validated') {
        return invoice;
      }
    }
    return null;
  }

  String? get _currentPeriodInvoiceConflictMessage {
    final invoice = _existingInvoiceForCurrentPeriod;
    if (invoice == null) return null;
    final statusCode = invoice.statusCode.trim().toLowerCase();
    if (statusCode == 'validated') {
      return 'Une facture validée existe déjà pour ce client et ce mois.';
    }
    return 'Une facture existe déjà pour ce client et ce mois.';
  }

  String _buildInvoiceCreationNotes() {
    final parts = <String>[];
    final paymentTermLabel = _selectedClientPaymentTermLabel;
    final bankLabel = _selectedCompanyBankAccount?.dropdownLabel.trim();
    if (paymentTermLabel != null && paymentTermLabel.isNotEmpty) {
      parts.add('Condition de règlement : $paymentTermLabel');
    }
    if (bankLabel != null && bankLabel.isNotEmpty) {
      parts.add('Compte bancaire : $bankLabel');
    }
    return parts.join('\n');
  }

  void _resetPreparationState() {
    final defaultBankAccountId = _resolveSelectedCompanyBankAccountId(
      accounts: _companyBankAccounts,
      currentSelectedId: null,
      companyInfo: _companyInfo,
    );
    _draftSaveTimer?.cancel();
    _createInvoiceFeedbackTimer?.cancel();
    setState(() {
      _clientInput = '';
      _loadError = null;
      _allClientMissions = [];
      _missions = [];
      _lineEditors.clear();
      _selectedLineIndex = null;
      _showLinePanel = false;
      _draftKey = null;
      _selectedMonth = _availableMonths.first;
      _missionTablePage = 1;
      _missionTableSearch = '';
      _clientPaymentTerms = [];
      _selectedClientPaymentTermId = null;
      _selectedCompanyBankAccountId = defaultBankAccountId;
      _creationClientInvoices.clear();
      _loadingCreationClientInvoices = false;
      _createInvoiceState = _CreateInvoiceActionState.idle;
    });
    _missionTableSearchCtrl.clear();
  }

  List<Map<String, dynamic>> _buildBillingMissionsPayload(
    List<_EditableInvoiceLine> editors,
  ) {
    final totalsByMission = <String, double>{};
    for (final editor in editors) {
      final ref = (editor.missionRef ?? editor.currentLine.missionRef ?? '')
          .trim();
      if (ref.isEmpty) continue;
      totalsByMission.update(
        ref,
        (current) => current + editor.currentLine.totalHt,
        ifAbsent: () => editor.currentLine.totalHt,
      );
    }

    return totalsByMission.entries
        .map(
          (entry) => <String, dynamic>{
            'reference': entry.key,
            'mission_ref': entry.key,
            'amount_ht': double.parse(entry.value.toStringAsFixed(2)),
          },
        )
        .toList(growable: false);
  }

  List<DateTime> _buildAvailableMonths({int monthsBack = 12}) {
    final now = DateTime.now();
    return List<DateTime>.generate(monthsBack, (index) {
      final date = DateTime(now.year, now.month - index, 1);
      return DateTime(date.year, date.month);
    });
  }

  String _monthLabel(DateTime month) {
    const monthNames = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    final index = (month.month - 1).clamp(0, monthNames.length - 1);
    return '${monthNames[index]} ${month.year}';
  }

  String _formatCurrency(double value) {
    final formatted = _currencyFormat.format(value);
    return formatted.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
  }

  String _formatQuantity(double value) {
    final formatted = _quantityFormat.format(value);
    return formatted.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
  }

  String _formatTvaValue(double value) {
    if (value <= 0) return '0 %';
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} %';
  }

  double _pdfFontSize(double size) => size * 0.8;

  double _unitPriceForMission(Map<String, dynamic> mission) {
    final productPrice = _parseAmount(mission['produit_price']);
    if (productPrice > 0) return productPrice;
    final total = _parseAmount(mission['montant_mission']);
    final qty = _quantityForMission(mission);
    if (total > 0 && qty > 0) {
      return total / qty;
    }
    return 0;
  }

  double _lineTotalFor(Map<String, dynamic> mission) {
    final total = _parseAmount(mission['montant_mission']);
    if (total > 0) return total;
    final unit = _unitPriceForMission(mission);
    final qty = _quantityForMission(mission);
    return unit * qty;
  }

  double _quantityForMission(Map<String, dynamic> mission) {
    final raw = mission['quantity'] ?? mission['qty'];
    if (raw != null) {
      final parsed = double.tryParse(raw.toString());
      if (parsed != null && parsed > 0) return parsed;
    }
    final minutes = _extractDurationMinutes(mission);
    if (minutes != null && minutes > 0) {
      final quantizedMinutes = _quantizeMinutes(minutes);
      return quantizedMinutes / 60;
    }
    return 1;
  }

  double _quantizeMinutes(double minutes) {
    if (minutes <= 0) return 0;
    if (minutes <= 15) return 15;
    if (minutes <= 30) return 30;
    if (minutes <= 60) return 60;
    return 15 * ((minutes / 15).ceilToDouble());
  }

  List<String> _designationLines(Map<String, dynamic> mission) {
    final lines = <String>[];
    final produitLabel = mission['produit_label']?.toString().trim();
    final produitRef = mission['produit_ref']?.toString().trim();
    final title = (produitLabel != null && produitLabel.isNotEmpty)
        ? produitLabel
        : ((produitRef != null && produitRef.isNotEmpty)
              ? produitRef
              : 'Mission');
    lines.add(title);
    final date = _missionDate(mission);
    final dateLabel = date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : '-';
    lines.add('Date : $dateLabel');
    final timeRange = _timeRangeLabel(mission);
    lines.add('Heure : ${timeRange.isNotEmpty ? timeRange : '-'}');
    final duration = _formatMissionDuration(mission);
    lines.add('Durée : ${duration.isNotEmpty ? duration : '-'}');
    final requester = _missionRequester(mission);
    lines.add('Demandeur : ${requester.isNotEmpty ? requester : '-'}');
    return lines;
  }

  String _designationFor(Map<String, dynamic> mission) =>
      _designationLines(mission).join('\n');

  String _formatMissionDuration(Map<String, dynamic> mission) {
    final raw =
        mission['dureemission'] ??
        mission['duration'] ??
        mission['duration_minutes'];
    final parsed = _parseDurationMinutes(raw);
    if (parsed == null || parsed <= 0) return '';
    if (parsed % 60 == 0) {
      return '${(parsed / 60).round()}h';
    }
    return '${parsed.round()} min';
  }

  String _timeRangeLabel(Map<String, dynamic> mission) {
    final start =
        (mission['heuredebutmission'] ??
                mission['heure_debut'] ??
                mission['start_time'] ??
                '')
            .toString()
            .trim();
    final end =
        (mission['heurefinmission'] ??
                mission['heure_fin'] ??
                mission['end_time'] ??
                '')
            .toString()
            .trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start → $end';
    }
    return start.isNotEmpty ? start : end;
  }

  String _missionRequester(Map<String, dynamic> mission) {
    final firstCandidates = [
      mission['prenom_demandeur'],
      mission['contactdemandeur_firstname'],
      mission['demandeur_firstname'],
    ];
    final lastCandidates = [
      mission['nom_demandeur'],
      mission['contactdemandeur_lastname'],
      mission['demandeur_lastname'],
    ];
    final first = _cleanPersonPart(firstCandidates);
    final last = _cleanPersonPart(lastCandidates);
    if (first != null && last != null) {
      return '${_capitalize(first)} ${last.toUpperCase()}';
    }
    final combinedCandidates = [
      mission['demandeur'],
      mission['contactdemandeur_name'],
    ];
    for (final raw in combinedCandidates) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return first ?? last ?? '';
  }

  String? _cleanPersonPart(List<dynamic> inputs) {
    for (final raw in inputs) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    final cleaned = raw
        .toString()
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  double? _parseDurationMinutes(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final normalized = text.replaceAll(',', '.');
    final hhmmMatch = RegExp(
      r'^(\d{1,2})[:hH](\d{1,2})$',
    ).firstMatch(normalized);
    if (hhmmMatch != null) {
      final hours = int.tryParse(hhmmMatch.group(1)!);
      final minutes = int.tryParse(hhmmMatch.group(2)!);
      if (hours != null && minutes != null) {
        return ((hours * 60) + minutes).toDouble();
      }
    }
    return double.tryParse(normalized);
  }

  double? _extractDurationMinutes(Map<String, dynamic> mission) {
    final direct =
        mission['dureemission'] ??
        mission['duration'] ??
        mission['duration_minutes'];
    final parsed = _parseDurationMinutes(direct);
    if (parsed != null) return parsed;
    final startRaw =
        mission['heuredebutmission'] ??
        mission['heure_debut'] ??
        mission['start_time'];
    final endRaw =
        mission['heurefinmission'] ??
        mission['heure_fin'] ??
        mission['end_time'];
    if (startRaw == null || endRaw == null) return null;
    final start = _parseTimeOfDay(startRaw.toString());
    final end = _parseTimeOfDay(endRaw.toString());
    if (start == null || end == null) return null;
    var duration = end.difference(start).inMinutes;
    if (duration <= 0) {
      duration = end.add(const Duration(days: 1)).difference(start).inMinutes;
    }
    return duration > 0 ? duration.toDouble() : null;
  }

  DateTime? _parseTimeOfDay(String input) {
    final match = RegExp(r'^(\d{1,2})[:hH](\d{1,2})$').firstMatch(input.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null) return null;
    return DateTime(2000, 1, 1, hours, minutes);
  }

  DateTime? _missionDate(Map<String, dynamic> mission) {
    final candidates = [
      mission['datemission_iso'],
      mission['datemission'],
      mission['date_mission'],
      mission['mission_date'],
      mission['date'],
    ];
    for (final raw in candidates) {
      final parsed = _parseDate(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw.toString().length > 10) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        return DateTime.parse(text.replaceAll(' ', 'T'));
      } catch (_) {
        for (final pattern in ['dd/MM/yyyy', 'dd/MM/yyyy HH:mm']) {
          try {
            return DateFormat(pattern).parseStrict(text);
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  bool _missionMatchesClient(
    Map<String, dynamic> mission,
    String normalizedClient, [
    int? clientId,
  ]) {
    // Prefer exact ID match when the user selected a client from the autocomplete
    if (clientId != null && clientId > 0) {
      final missionClientId =
          mission['client_id'] is int
              ? mission['client_id'] as int
              : int.tryParse(mission['client_id']?.toString() ?? '') ?? 0;
      return missionClientId == clientId;
    }
    // Fallback: name-based exact equality (avoids cross-contamination between
    // similarly-named structures such as sub-entities of the same group)
    final clientName =
        (mission['client_name'] ?? mission['nom'] ?? mission['company'] ?? '')
            .toString()
            .toLowerCase();
    return clientName == normalizedClient;
  }

  List<String> _clientAddressLinesForPdf() {
    return _clientAddressLinesFromMission(_missionWithClientDetails());
  }

  List<String> _clientAddressLinesFromMission(Map<String, dynamic>? mission) {
    if (mission == null) return [];
    final lines = <String>[];
    final address1 = _stringValueFromKeys(mission, const [
      'client_address',
      'client_address_line1',
      'client_address1',
      'adresse_client',
      'adresse',
      'address',
    ]);
    final address2 = _stringValueFromKeys(mission, const [
      'client_address2',
      'client_address_line2',
      'adresse_client2',
      'adresse2',
      'address2',
    ]);
    final zip = _stringValueFromKeys(mission, const [
      'client_zip',
      'zip',
      'cp',
    ]);
    final city = _stringValueFromKeys(mission, const [
      'client_town',
      'client_city',
      'ville',
      'town',
      'city',
    ]);
    if (address1.isNotEmpty) {
      lines.add(address1);
    }
    if (address2.isNotEmpty && address2 != address1) {
      lines.add(address2);
    }
    final cityLine = [zip, city].where((part) => part.isNotEmpty).join(' ');
    if (cityLine.isNotEmpty) {
      lines.add(cityLine);
    }
    return lines;
  }

  String _clientCodeForPdf() {
    return _clientCodeFromMission(_missionWithClientDetails());
  }

  String _clientCodeFromMission(Map<String, dynamic>? mission) {
    if (mission == null) return '-';
    final code = _stringValueFromKeys(mission, const [
      'client_code',
      'code_client',
      'customer_code',
    ]);
    if (code.isNotEmpty) return code;
    final clientId = _stringValueFromKeys(mission, const [
      'client_id',
      'fk_soc',
    ]);
    return clientId.isNotEmpty ? clientId : '-';
  }

  Map<String, dynamic>? _missionWithClientDetails() {
    for (final mission in _missions) {
      if (_hasClientAddressData(mission)) return mission;
    }
    if (_missions.isNotEmpty) return _missions.first;
    for (final mission in _allClientMissions) {
      if (_hasClientAddressData(mission)) return mission;
    }
    return _allClientMissions.isNotEmpty ? _allClientMissions.first : null;
  }

  bool _hasClientAddressData(Map<String, dynamic> mission) {
    return _stringValueFromKeys(mission, const [
          'client_address',
          'client_address_line1',
          'client_address1',
          'adresse_client',
          'adresse',
          'address',
        ]).isNotEmpty ||
        _stringValueFromKeys(mission, const [
          'client_zip',
          'zip',
          'cp',
          'client_town',
          'client_city',
          'ville',
          'town',
          'city',
        ]).isNotEmpty;
  }

  String _stringValueFromKeys(Map<String, dynamic> mission, List<String> keys) {
    for (final key in keys) {
      final value = mission[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  CompanyInfo get _resolvedCompanyInfo =>
      _companyInfo ?? CompanyInfo.fallback();

  ClientPaymentTerm? get _selectedClientPaymentTerm {
    final selectedId = _selectedClientPaymentTermId;
    if (selectedId == null) {
      return null;
    }
    for (final term in _clientPaymentTerms) {
      if (term.id == selectedId) {
        return term;
      }
    }
    return null;
  }

  String? get _selectedClientPaymentTermLabel {
    final term = _selectedClientPaymentTerm;
    if (term == null) {
      return null;
    }
    final label = term.displayLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    final code = term.code.trim();
    return code.isEmpty ? null : code;
  }

  int? _resolveSelectedClientPaymentTermId({
    required List<ClientPaymentTerm> terms,
    required int? currentSelectedId,
    required int? defaultTermId,
  }) {
    if (terms.isEmpty) {
      return null;
    }
    if (currentSelectedId != null &&
        terms.any((term) => term.id == currentSelectedId)) {
      return currentSelectedId;
    }
    if (defaultTermId != null &&
        terms.any((term) => term.id == defaultTermId)) {
      return defaultTermId;
    }
    for (final term in terms) {
      if (term.isDefault) {
        return term.id;
      }
    }
    return terms.first.id;
  }

  int? _clientIdFromMissions(List<Map<String, dynamic>> missions) {
    for (final mission in missions) {
      final rawClientId = _stringValueFromKeys(mission, const [
        'client_id',
        'fk_soc',
      ]);
      final parsed = int.tryParse(rawClientId);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  CompanyBankAccount? get _selectedCompanyBankAccount {
    final selectedId = _selectedCompanyBankAccountId;
    if (selectedId == null) {
      return null;
    }
    for (final account in _companyBankAccounts) {
      if (account.id == selectedId) {
        return account;
      }
    }
    return null;
  }

  CompanyInfo _applySelectedCompanyBankAccount(CompanyInfo info) {
    final selectedAccount = _selectedCompanyBankAccount;
    if (selectedAccount == null) {
      return info;
    }
    return selectedAccount.applyTo(info);
  }

  int? _resolveSelectedCompanyBankAccountId({
    required List<CompanyBankAccount> accounts,
    required int? currentSelectedId,
    CompanyInfo? companyInfo,
  }) {
    if (accounts.isEmpty) {
      return null;
    }
    if (currentSelectedId != null &&
        accounts.any((account) => account.id == currentSelectedId)) {
      return currentSelectedId;
    }
    if (companyInfo != null) {
      for (final account in accounts) {
        if (account.matchesCompanyInfo(companyInfo)) {
          return account.id;
        }
      }
    }
    for (final account in accounts) {
      if (account.isDefault) {
        return account.id;
      }
    }
    return accounts.first.id;
  }

  List<String> _companyInfoLinesForPdf(CompanyInfo info) {
    final lines = <String>[];
    final name = info.name.trim();
    if (name.isNotEmpty) lines.add(name);
    lines.addAll(info.addressLines);
    lines.addAll(_companyInfoMetaLines(info));
    return lines;
  }

  List<String> _companyInfoMetaLines(CompanyInfo info) {
    final lines = <String>[];
    final siret = info.siret.trim();
    if (siret.isNotEmpty) lines.add('SIRET : $siret');
    final phone = info.phone.trim();
    if (phone.isNotEmpty) lines.add('Tél. : $phone');
    final email = info.email.trim();
    if (email.isNotEmpty) lines.add('Email : $email');
    final website = info.website.trim();
    if (website.isNotEmpty) lines.add('Site : $website');
    return lines;
  }

  pw.Widget _buildPdfBankTransferBlock(
    CompanyInfo info, {
    required PdfColor borderColor,
  }) {
    final bankName = info.bankName.trim();
    final bankCode = info.bankCode.trim();
    final branchCode = info.bankBranchCode.trim();
    final accountNumber = info.bankAccountNumber.trim();
    final ribKey = info.bankRibKey.trim();
    final address = _companyBankAddressForPdf(info);
    final owner = info.bankAccountHolder.trim();
    final iban = info.bankIban.trim();
    final bic = info.bankBic.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RIB pour virement',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: _pdfFontSize(9.5),
            ),
          ),
          pw.SizedBox(height: 3),
          if (bankName.isNotEmpty)
            pw.Text(
              'Banque: $bankName',
              style: pw.TextStyle(fontSize: _pdfFontSize(8.5)),
            ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfBankInfoCell('Code banque', bankCode),
              _buildPdfBankInfoCell('Code guichet', branchCode),
              _buildPdfBankInfoCell('Numéro de compte', accountNumber, flex: 2),
              _buildPdfBankInfoCell('Clé', ribKey),
            ],
          ),
          pw.SizedBox(height: 4),
          if (address.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                'Adresse: $address',
                style: pw.TextStyle(fontSize: _pdfFontSize(8.2)),
              ),
            ),
          if (owner.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                'Titulaire: $owner',
                style: pw.TextStyle(fontSize: _pdfFontSize(8.2)),
              ),
            ),
          if (iban.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                'IBAN: $iban',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: _pdfFontSize(8.4),
                ),
              ),
            ),
          if (bic.isNotEmpty)
            pw.Text(
              'BIC: $bic',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: _pdfFontSize(8.4),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPaymentTermBlock(
    String paymentTermLabel, {
    required PdfColor borderColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Condition de règlement',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: _pdfFontSize(9.5),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            paymentTermLabel,
            style: pw.TextStyle(fontSize: _pdfFontSize(8.8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfBankInfoCell(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColor.fromHex('#9CA3AF'), width: 0.5),
            right: pw.BorderSide(
              color: PdfColor.fromHex('#9CA3AF'),
              width: 0.5,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: _pdfFontSize(7.4),
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(value, style: pw.TextStyle(fontSize: _pdfFontSize(8.2))),
          ],
        ),
      ),
    );
  }

  String _companyBankAddressForPdf(CompanyInfo info) {
    final domiciliation = info.bankDomiciliation.trim();
    if (domiciliation.isNotEmpty) {
      for (final line in domiciliation.split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    final ownerAddress = info.bankOwnerAddress.trim();
    final ownerCityLine = info.bankOwnerCityLine;
    return [
      ownerAddress,
      ownerCityLine,
    ].where((part) => part.isNotEmpty).join(', ');
  }

  pw.Widget _buildPdfTotalRow({
    required String label,
    required String value,
    bool highlighted = false,
  }) {
    return pw.Container(
      color: highlighted ? PdfColor.fromHex('#E5E7EB') : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: highlighted
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: highlighted
                    ? PdfColor.fromHex('#111827')
                    : PdfColors.black,
                fontSize: _pdfFontSize(12),
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: highlighted
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: highlighted
                  ? PdfColor.fromHex('#000091')
                  : PdfColors.black,
              fontSize: _pdfFontSize(12),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(
    pw.Context context, {
    required CompanyInfo companyInfo,
  }) {
    final siret = _formattedSiretForPdf(companyInfo.siret);
    final companyName = companyInfo.name.trim().isEmpty
        ? 'Planet Traduction'
        : companyInfo.name.trim();
    final footerLine1 =
        'Association loi 1901 ou assimilé - SIRET : $siret / NAF-APE : 74.30Z';
    final footerContacts = <String>[];
    final website = companyInfo.website.trim();
    if (website.isNotEmpty) {
      footerContacts.add(website);
    }
    final email = companyInfo.email.trim();
    if (email.isNotEmpty) {
      footerContacts.add(email);
    }
    final footerLine2 = footerContacts.join(' | ');

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 7),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(height: 0.5, color: PdfColor.fromHex('#D1D5DB')),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      companyName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: _pdfFontSize(8.6),
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#111827'),
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      footerLine1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: _pdfFontSize(7.9)),
                    ),
                    if (footerLine2.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        footerLine2,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: _pdfFontSize(7.9)),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: _pdfFontSize(8),
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#374151'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedSiretForPdf(String value) {
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (digits.length != 14) {
      return value.trim().isEmpty ? '912 824 158 00014' : value.trim();
    }
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9, 14)}';
  }

  String? _missionRef(Map<String, dynamic> mission) {
    final candidates = [
      mission['reference_devis'],
      mission['reference'],
      mission['ref'],
      mission['mission_ref'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  double? _tvaOptionFor(double value) {
    if (_tvaRates.contains(value)) return value;
    return _tvaRates.first;
  }

  static const List<double> _tvaRates = [0, 2.1, 5.5, 10, 20];

  @override
  void deactivate() {
    _draftSaveTimer?.cancel();
    super.deactivate();
  }
}

class _EditableInvoiceLine {
  _EditableInvoiceLine({
    required this.mission,
    required this.originalLine,
    required this.currentLine,
  });

  final Map<String, dynamic>? mission;
  final InvoiceLine originalLine;
  InvoiceLine currentLine;

  String? get missionRef =>
      mission?['reference_devis']?.toString() ??
      mission?['reference']?.toString() ??
      currentLine.missionRef;

  void reset() {
    currentLine = originalLine.copy();
  }
}

class _InvoiceMissionGroup {
  _InvoiceMissionGroup(this.missionRef, this.lines)
    : quantity = lines.fold<double>(0, (sum, line) => sum + line.quantity),
      totalHt = lines.fold<double>(0, (sum, line) => sum + line.totalHt);

  final String missionRef;
  final List<InvoiceLine> lines;
  final double quantity;
  final double totalHt;
}

class _SidebarEntry extends StatelessWidget {
  const _SidebarEntry({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.collapsed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE3E8FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF000091)
                    : const Color(0xFF4B5563),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? const Color(0xFF000091)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingDraftBadge extends StatelessWidget {
  const _SavingDraftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Sauvegarde…'),
        ],
      ),
    );
  }
}

class _InlineEditableTextCell extends StatefulWidget {
  const _InlineEditableTextCell({
    super.key,
    required this.width,
    required this.text,
    required this.onChanged,
    this.maxLines = 3,
  });

  final double width;
  final String text;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_InlineEditableTextCell> createState() =>
      _InlineEditableTextCellState();
}

class _InlineEditableTextCellState extends State<_InlineEditableTextCell> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _InlineEditableTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onChanged(_controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: 1,
        style: const TextStyle(fontSize: 13, height: 1.3),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _InlineEditableNumberCell extends StatefulWidget {
  const _InlineEditableNumberCell({
    super.key,
    required this.width,
    required this.value,
    required this.onNumberChanged,
    this.fractionDigits = 2,
  });

  final double width;
  final double value;
  final ValueChanged<double?> onNumberChanged;
  final int fractionDigits;

  @override
  State<_InlineEditableNumberCell> createState() =>
      _InlineEditableNumberCellState();
}

class _InlineEditableNumberCellState extends State<_InlineEditableNumberCell> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _InlineEditableNumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _applyRawValue(_controller.text, revertOnInvalid: true);
    }
  }

  void _onChanged(String raw) => _applyRawValue(raw);

  void _applyRawValue(String raw, {bool revertOnInvalid = false}) {
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      if (revertOnInvalid) {
        _controller.text = _format(widget.value);
      }
      widget.onNumberChanged(null);
      return;
    }
    widget.onNumberChanged(parsed);
  }

  String _format(double value) {
    return value.toStringAsFixed(widget.fractionDigits);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
