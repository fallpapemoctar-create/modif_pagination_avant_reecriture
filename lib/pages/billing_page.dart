import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/auth_manager.dart';
import '../core/brand_footer.dart';
import '../core/models/invoice_line.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../models/company_info.dart';
import '../services/billing_service.dart';
import '../services/company_info_service.dart';
import '../services/mission_service.dart';
import '../utils/pdf_download_helper_stub.dart'
	if (dart.library.html) '../utils/pdf_download_helper_web.dart';
import '../widgets/client_autocomplete_field.dart';

/*
		final headerChips = <Widget>[
			Container(
				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
				decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFD6DAE6))),
				child: Text('Émise le $billedAtLabel', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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

		final detailActions = <Widget>[
			if (isLocked)
				Container(
					width: double.infinity,
					margin: const EdgeInsets.only(bottom: 12),
					padding: const EdgeInsets.all(10),
					decoration: BoxDecoration(
						color: const Color(0xFFFEF3C7),
						borderRadius: BorderRadius.circular(8),
						border: Border.all(color: const Color(0xFFF59E0B)),
					),
					child: const Text('Facture payée : les lignes du détail sont verrouillées.'),
				),
			if (!isLocked && missionRef != null && missionRef.trim().isNotEmpty)
				Padding(
					padding: const EdgeInsets.only(bottom: 12),
					child: Row(
						children: [
							OutlinedButton.icon(
								onPressed: _selectedInvoiceLineEditors.isEmpty ? null : _resetSelectedInvoiceLines,
								icon: const Icon(Icons.restore),
								label: const Text('Réinitialiser'),
							),
							const SizedBox(width: 12),
							Expanded(
								child: FilledButton.icon(
									onPressed: _savingInvoiceLinesPanel || !_hasSelectedInvoiceLineChanges ? null : _saveSelectedInvoiceLines,
									icon: _savingInvoiceLinesPanel
										? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.save_outlined),
									label: Text(_savingInvoiceLinesPanel ? 'Enregistrement...' : 'Enregistrer les lignes'),
								),
							),
						],
					),
				),
		];

		final linesContent = _loadingInvoiceLinesPanel
			? const Center(child: CircularProgressIndicator())
			: missionRef == null || missionRef.trim().isEmpty
				? const Center(child: Text('Aucune référence mission disponible pour cette facture.'))
				: lines.isEmpty
					? const Center(child: Text('Aucune ligne trouvée pour cette mission.'))
					: Scrollbar(
						thumbVisibility: true,
						child: ListView.separated(
							itemCount: lines.length,
							separatorBuilder: (_, __) => const Divider(height: 20),
							itemBuilder: (context, index) => _buildStoredInvoiceLineTile(index, isLocked: isLocked),
						),
					);

		return Align(
			alignment: Alignment.centerRight,
			child: ConstrainedBox(
				constraints: const BoxConstraints(maxWidth: 470),
				child: Material(
					elevation: 8,
					borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
					child: Container(
						color: Colors.white,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(
									padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing - 2),
									decoration: const BoxDecoration(
										color: Color(0xFFF4F6FB),
										borderRadius: BorderRadius.only(topLeft: Radius.circular(18)),
										border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
									),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													Container(
														padding: const EdgeInsets.all(10),
														decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
														child: const Icon(Icons.account_tree_outlined, color: Color(0xFF000091)),
													),
													const SizedBox(width: 12),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text('Niveau 2 • Détail facture', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF000091), fontWeight: FontWeight.w700)),
																const SizedBox(height: 4),
																Text('Facture ${invoice.invoiceNumber}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
																const SizedBox(height: 2),
																Text(invoice.clientName.isEmpty ? 'Client non renseigné' : invoice.clientName, style: const TextStyle(color: Color(0xFF6B7280))),
															],
														),
													),
													IconButton(onPressed: _closeInvoiceDetails, icon: const Icon(Icons.close)),
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
	const BillingPageArguments({required this.missions});

	final List<Map<String, dynamic>> missions;
}

enum BillingSection { creation, invoices }

class BillingPage extends StatefulWidget {
	const BillingPage({super.key, required this.userRights});

	final UserRights userRights;

	@override
	State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
	BillingSection _activeSection = BillingSection.creation;
	bool _sidebarCollapsed = false;
	bool _routeArgsLoaded = false;

	String _clientInput = '';
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
	String? _draftKey;

	TextEditingController? _lineDesignationCtrl;
	TextEditingController? _lineQuantityCtrl;
	TextEditingController? _lineUnitPriceCtrl;
	TextEditingController? _lineNotesCtrl;

	Timer? _draftSaveTimer;

	bool _generatingPdf = false;
	CompanyInfo? _companyInfo;
	bool _loadingCompanyInfo = false;
	pw.Font? _pdfFontRegular;
	pw.Font? _pdfFontBold;
	pw.MemoryImage? _pdfLogoImage;

	List<ClientInvoiceSummary> _invoices = [];
	bool _loadingInvoices = false;
	int _invoicePage = 1;
	final int _invoicePageSize = 25;
	int _invoiceTotal = 0;
	String _invoiceClientFilter = '';
	String? _invoiceError;
	final ScrollController _invoiceScrollController = ScrollController();
	ClientInvoiceSummary? _selectedInvoice;
	ClientInvoiceLinesResult? _selectedInvoiceLines;
	String? _selectedInvoiceMissionRef;
	final List<_EditableInvoiceLine> _selectedInvoiceLineEditors = [];
	bool _loadingInvoiceLinesPanel = false;
	bool _savingInvoiceLinesPanel = false;
	final Set<String> _updatingInvoiceStatus = <String>{};

	static const List<String> _invoiceStatusLabels = ['Brouillon', 'Validée', 'Envoyée', 'Payée', 'Impayée'];
	static const Map<String, String> _invoiceStatusToCode = {
		'Brouillon': 'draft',
		'Validée': 'validated',
		'Envoyée': 'sent',
		'Payée': 'paid',
		'Impayée': 'unpaid',
	};
	static const Map<String, String> _invoiceCodeToLabel = {
		'draft': 'Brouillon',
		'validated': 'Validée',
		'sent': 'Envoyée',
		'paid': 'Payée',
		'unpaid': 'Impayée',
	};

	@override
	void initState() {
		super.initState();
		_currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);
		_quantityFormat = NumberFormat('#,##0.##', 'fr_FR');
		_availableMonths = _buildAvailableMonths();
		_selectedMonth = _availableMonths.first;
		_loadCompanyInfo();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (_routeArgsLoaded) return;
		_routeArgsLoaded = true;
		final args = ModalRoute.of(context)?.settings.arguments;
		if (args is BillingPageArguments && args.missions.isNotEmpty) {
			setState(() {
				_allClientMissions = args.missions.map((mission) => Map<String, dynamic>.from(mission)).toList();
				final inferredClient = (_allClientMissions.first['client_name'] ?? '').toString().trim();
				if (inferredClient.isNotEmpty) {
					_clientInput = inferredClient;
				}
				_applyMonthFilter();
			});
		}
	}

	@override
	void dispose() {
		_tableVerticalController.dispose();
		_tableHorizontalController.dispose();
		_fullscreenVerticalController.dispose();
		_fullscreenHorizontalController.dispose();
		_invoiceScrollController.dispose();
		_lineDesignationCtrl?.dispose();
		_lineQuantityCtrl?.dispose();
		_lineUnitPriceCtrl?.dispose();
		_lineNotesCtrl?.dispose();
		_draftSaveTimer?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final spacing = ResponsiveHelper.getSpacing(context);
		return Scaffold(
			body: SafeArea(
				top: true,
				bottom: false,
				child: Stack(
					children: [
						Row(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								_buildSidebar(context),
								Expanded(child: _buildActiveView(spacing)),
							],
						),
						if (_activeSection == BillingSection.creation && _showLinePanel && _selectedLineIndex != null)
							_buildLineEditorPanel(spacing),
						if (_activeSection == BillingSection.creation && _isTableFullscreen)
							_buildFullscreenOverlay(spacing),
						if (_activeSection == BillingSection.invoices && _selectedInvoice != null)
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

	Widget _buildSidebar(BuildContext context) {
		const collapsedWidth = 68.0;
		const expandedWidth = 240.0;
		final collapsed = _sidebarCollapsed;
		final horizontalPadding = collapsed ? 8.0 : 16.0;
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
						padding: EdgeInsets.fromLTRB(horizontalPadding, 16, 8, 16),
						child: Row(
							children: [
								if (!collapsed)
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: const [
												Text('Facturation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
												SizedBox(height: 2),
												Text('Navigation générale', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
											],
										),
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

	Widget _buildActiveView(double spacing) {
		switch (_activeSection) {
			case BillingSection.creation:
				return _buildCreationView(spacing);
			case BillingSection.invoices:
				return _buildInvoicesView(spacing);
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
		if (section == BillingSection.invoices && _invoices.isEmpty && !_loadingInvoices) {
			unawaited(_loadInvoices(reset: true));
		}
	}

	Widget _buildCreationView(double spacing) {
		return Container(
			color: const Color(0xFFF6F6F6),
			child: ResponsiveContainer(
				maxWidth: double.infinity,
				padding: EdgeInsets.zero,
				child: Padding(
					padding: EdgeInsets.fromLTRB(spacing, 0, spacing, spacing),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildClientSection(),
							const SizedBox(height: 4),
							Expanded(
								child: _loadingMissions
									? const Center(child: CircularProgressIndicator())
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
		);
	}

	Widget _buildInvoicesView(double spacing) {
		return Container(
			color: const Color(0xFFF6F6F6),
			child: ResponsiveContainer(
				padding: EdgeInsets.all(spacing),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text('Tableau des factures', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
						const SizedBox(height: 12),
						_buildInvoiceFilters(),
						const SizedBox(height: 16),
						Expanded(child: _buildInvoiceTable()),
					],
				),
			),
		);
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
								onChanged: (value) => setState(() => _clientInput = value),
								onSelected: (_) => _loadMissionsForClient(),
								onSubmitted: (_) => _loadMissionsForClient(),
								trailingBuilder: (context, controller, loading) => [
									IconButton(
										icon: _loadingMissions
											? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
											: const Icon(Icons.search),
										onPressed: _loadingMissions ? null : _loadMissionsForClient,
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
								decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.calendar_month)),
								items: _availableMonths
									.map((month) => DropdownMenuItem(value: month, child: Text(_monthLabel(month))))
									.toList(),
								onChanged: (value) {
									if (value == null) return;
									setState(() => _selectedMonth = value);
									_applyMonthFilter();
								},
							),
						);

						if (isWideDesktop) {
							return Row(
								crossAxisAlignment: CrossAxisAlignment.end,
								children: [
									clientField,
									const SizedBox(width: 16),
									monthField,
									const SizedBox(width: 16),
									Expanded(child: _buildToolbarButtons(allowWrap: true)),
								],
							);
						}

						return Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Wrap(
									spacing: 16,
									runSpacing: 6,
									crossAxisAlignment: WrapCrossAlignment.center,
									children: [clientField, monthField],
								),
								const SizedBox(height: 12),
								_buildToolbarButtons(allowWrap: !isCompact, width: isCompact ? constraints.maxWidth : null),
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
						child: Text(_loadError!, style: const TextStyle(color: Color(0xFFB91C1C))),
					),
			],
		);
	}

	Widget _buildToolbarField({required String label, required Widget child, double? width}) {
		final content = Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
				const SizedBox(height: 2),
				child,
			],
		);
		if (width == null) return content;
		return SizedBox(width: width, child: content);
	}

	Widget _buildToolbarButtons({required bool allowWrap, double? width}) {
		final actionButtons = [
			ElevatedButton.icon(
				onPressed: _loadingMissions ? null : _loadMissionsForClient,
				icon: _loadingMissions
					? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
					: const Icon(Icons.sync),
				label: Text(_loadingMissions ? 'Chargement...' : 'Charger les missions'),
			),
			FilledButton.icon(
				onPressed: (_lineEditors.isEmpty || _generatingPdf) ? null : _generatePdfFromTable,
				icon: _generatingPdf
					? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
					: const Icon(Icons.picture_as_pdf_outlined),
				label: Text(_generatingPdf ? 'Préparation...' : 'Générer facture (PDF)'),
			),
			OutlinedButton.icon(
				onPressed: _lineEditors.isEmpty ? null : _resetAllLines,
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
							if (index < actionButtons.length - 1) const SizedBox(width: 10),
						],
					],
				),
			);
		if (width == null) return buttons;
		return SizedBox(width: width, child: buttons);
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
						padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 1.5),
						decoration: const BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
						),
						child: Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Icon(Icons.table_rows, color: Color(0xFF000091)),
								const SizedBox(width: 12),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Tableau des lignes', style: TextStyle(fontWeight: FontWeight.w700)),
											const SizedBox(height: 2),
											Text(
												_lineEditors.isEmpty ? 'Aucune ligne sélectionnée' : '${_lineEditors.length} ligne(s) prêtes',
												style: const TextStyle(color: Color(0xFF6B7280)),
											),
										],
									),
								),
								IconButton(
									icon: Icon(_isTableFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
									onPressed: _lineEditors.isEmpty ? null : () => _toggleTableFullscreen(!_isTableFullscreen),
									tooltip: _isTableFullscreen ? 'Quitter le plein écran' : 'Afficher en plein écran',
								),
							],
						),
					),
					const Divider(height: 1, color: borderColor),
					Expanded(
						child: _buildLinesTable(
							verticalController: _tableVerticalController,
							horizontalController: _tableHorizontalController,
						),
					),
					const Divider(height: 1, color: borderColor),
					Padding(
						padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 1.5),
						child: Row(
							children: [
								if (_lineEditors.isNotEmpty)
									Text('${_lineEditors.length} ligne(s)', style: const TextStyle(color: Color(0xFF6B7280))),
								if (_lineEditors.isNotEmpty) const Spacer(),
								Text(
									'Total HT : ${_formatCurrency(_currentTotalHt)}',
									style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF000091), fontSize: 16),
								),
							],
						),
					),
				],
			),
		);
	}

	DataRow _buildRow(int index, _EditableInvoiceLine editor, List<double> columnWidths) {
		final line = editor.currentLine;
		final ref = editor.missionRef ?? line.missionRef ?? '-';
		return DataRow(
			selected: _selectedLineIndex == index,
			onSelectChanged: (_) => _openLineEditor(index),
			cells: [
				_buildSelectableCell(ref.isEmpty ? '-' : ref, width: columnWidths[0]),
				_buildEditableDesignationCell(index, columnWidths[1]),
				_buildTvaDropdownCell(index, columnWidths[2]),
				_buildEditableNumberCell(
					label: 'P.U. HT',
					index: index,
					width: columnWidths[3],
					value: line.unitPrice,
					fractionDigits: 2,
					onChanged: (value) {
						if (value != null && value >= 0) {
							_updateLineFields(index, unitPrice: value);
						}
					},
				),
				_buildEditableNumberCell(
					label: 'Quantité',
					index: index,
					width: columnWidths[4],
					value: line.quantity,
					fractionDigits: 3,
					onChanged: (value) {
						if (value != null && value > 0) {
							_updateLineFields(index, quantity: value);
						}
					},
				),
				_buildSelectableCell(_formatCurrency(line.totalHt), width: columnWidths[5], align: TextAlign.right),
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
							.map((rate) => DropdownMenuItem<double>(
								value: rate,
								child: Text('${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %'),
							))
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

	DataCell _buildSelectableCell(String value, {double? width, TextAlign align = TextAlign.left}) {
		final widget = SelectableText(value, textAlign: align, style: const TextStyle(height: 1.2));
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
					Text('Aucune mission à afficher', style: TextStyle(fontWeight: FontWeight.w600)),
					SizedBox(height: 4),
					Text(
						'Saisissez un client, choisissez un mois puis cliquez sur "Charger les missions" pour préparer la facture.',
						textAlign: TextAlign.center,
					),
				],
			),
		);
	}

	Widget _buildInvoiceFilters() {
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Wrap(
					spacing: 16,
					runSpacing: 12,
					crossAxisAlignment: WrapCrossAlignment.center,
					children: [
						SizedBox(
							width: 320,
							child: ClientAutocompleteField(
								value: _invoiceClientFilter,
								hintText: 'Filtrer par client',
								onChanged: (value) => setState(() => _invoiceClientFilter = value),
								onSelected: (_) => _loadInvoices(reset: true),
								onSubmitted: (_) => _loadInvoices(reset: true),
							),
						),
						FilledButton.icon(
							onPressed: _loadingInvoices ? null : () => _loadInvoices(reset: true),
							icon: _loadingInvoices
								? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
								: const Icon(Icons.search),
							label: Text(_loadingInvoices ? 'Recherche...' : 'Mettre à jour'),
						),
					],
				),
			),
		);
	}

	Widget _buildInvoiceTable() {
		if (_invoiceError != null) {
			return Center(child: Text(_invoiceError!, style: const TextStyle(color: Color(0xFFB91C1C))));
		}
		if (_loadingInvoices) {
			return const Center(child: CircularProgressIndicator());
		}
		if (_invoices.isEmpty) {
			return const Center(child: Text('Aucune facture trouvée. Modifiez les filtres pour relancer la recherche.'));
		}
		final totalPages = (_invoiceTotal / _invoicePageSize).ceil().clamp(1, 9999);
		final selectedInvoiceNumber = _selectedInvoice?.invoiceNumber;
		final selectedMissionRef = _selectedInvoiceMissionRef;
		return Column(
			children: [
				Expanded(
					child: Scrollbar(
						controller: _invoiceScrollController,
						thumbVisibility: true,
						child: SingleChildScrollView(
							controller: _invoiceScrollController,
							scrollDirection: Axis.vertical,
							child: DataTable(
								columnSpacing: 12,
								headingRowHeight: 40,
								columns: const [
									DataColumn(label: Text('Facture')),
									DataColumn(label: Text('Réf mission')),
									DataColumn(label: Text('Client')),
									DataColumn(label: Text('Statut')),
									DataColumn(label: Text('Montant HT'), numeric: true),
									DataColumn(label: Text('Date')), 
								],
								rows: _invoices
									.map((invoice) {
										final billedLabel = invoice.billedAt != null ? DateFormat('dd/MM/yyyy').format(invoice.billedAt!) : '-';
										final amount = invoice.amountHt > 0 ? invoice.amountHt : invoice.invoiceTotalHt;
										final isSelected = invoice.invoiceNumber == selectedInvoiceNumber && invoice.missionRef == selectedMissionRef;
										return DataRow(
											selected: isSelected,
											onSelectChanged: (_) => _openInvoiceDetails(invoice, missionRef: invoice.missionRef),
											cells: [
												DataCell(Text(invoice.invoiceNumber)),
												DataCell(_buildInvoiceMissionCell(invoice)),
												DataCell(Text(invoice.clientName.isEmpty ? '-' : invoice.clientName)),
												DataCell(SizedBox(width: 160, child: _invoiceStatusDropdown(invoice))),
												DataCell(Align(alignment: Alignment.centerRight, child: Text(_formatCurrency(amount)))),
												DataCell(Text(billedLabel)),
											],
										);
									})
									.toList(),
							),
						),
					),
				),
				const SizedBox(height: 8),
				Row(
					children: [
						Text('Page $_invoicePage / $totalPages ($_invoiceTotal facture${_invoiceTotal > 1 ? 's' : ''})'),
						const Spacer(),
						IconButton(
							icon: const Icon(Icons.chevron_left),
							onPressed: _invoicePage > 1 && !_loadingInvoices
								? () {
									setState(() => _invoicePage -= 1);
									_loadInvoices();
								}
								: null,
							tooltip: 'Page précédente',
						),

						IconButton(
							icon: const Icon(Icons.chevron_right),
							onPressed: _invoicePage < totalPages && !_loadingInvoices
								? () {
									setState(() => _invoicePage += 1);
									_loadInvoices();
								}
								: null,
							tooltip: 'Page suivante',
						),
					],
				),
			],
		);
	}

	Widget _invoiceStatusDropdown(ClientInvoiceSummary invoice, {bool compact = true}) {
		final label = _invoiceStatusLabelFor(invoice);
		final isUpdating = _isInvoiceStatusBeingUpdated(invoice.invoiceNumber);
		final dropdown = DropdownButtonHideUnderline(
			child: DropdownButton<String>(
				value: label,
				isDense: compact,
				isExpanded: true,
				onChanged: isUpdating ? null : (value) {
					if (value == null || value == label) return;
					_changeInvoiceStatus(invoice, value);
				},
				items: _invoiceStatusLabels
					.map((status) => DropdownMenuItem<String>(value: status, child: Text(status)))
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
						child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
					),
			],
		);
	}

	Widget _buildInvoiceMissionCell(ClientInvoiceSummary invoice) {
		final missionRef = invoice.missionRef?.trim() ?? '';
		if (missionRef.isEmpty) {
			return const Text('-');
		}
		return InkWell(
			onTap: () => _openInvoiceDetails(invoice, missionRef: missionRef),
			borderRadius: BorderRadius.circular(6),
			child: Padding(
				padding: const EdgeInsets.symmetric(vertical: 4),
				child: Text(
					missionRef,
					style: const TextStyle(
						color: Color(0xFF000091),
						fontWeight: FontWeight.w600,
						decoration: TextDecoration.underline,
					),
				),
			),
		);
	}

	Widget _buildLinesTable({
		required ScrollController verticalController,
		required ScrollController horizontalController,
		double minWidth = 960,
	}) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final viewportWidth = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.of(context).size.width;
				final tableWidth = math.max(viewportWidth, minWidth);
				const fractions = <double>[0.14, 0.36, 0.1, 0.14, 0.1, 0.16];
				final columnWidths = fractions.map((ratio) => tableWidth * ratio).toList();
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
										DataColumn(label: SizedBox(width: columnWidths[0], child: const Text('Ref. mission'))),
										DataColumn(label: SizedBox(width: columnWidths[1], child: const Text('Désignation'))),
										DataColumn(label: SizedBox(width: columnWidths[2], child: const Text('TVA'))),
										DataColumn(label: SizedBox(width: columnWidths[3], child: const Text('P.U. HT'))),
										DataColumn(label: SizedBox(width: columnWidths[4], child: const Text('Qté'))),
										DataColumn(label: SizedBox(width: columnWidths[5], child: const Text('Total HT'))),
									],
									rows: _lineEditors.asMap().entries.map((entry) => _buildRow(entry.key, entry.value, columnWidths)).toList(),
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
											padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
											child: Row(
												children: [
													const Icon(Icons.fullscreen, color: Color(0xFF000091)),
													const SizedBox(width: 8),
													const Text('Vue plein écran des lignes', style: TextStyle(fontWeight: FontWeight.w700)),
													const Spacer(),
													Text('${_lineEditors.length} ligne(s)'),
													IconButton(onPressed: () => _toggleTableFullscreen(false), icon: const Icon(Icons.close)),
												],
											),
										),
										const Divider(height: 1, color: Color(0xFFE5E7EB)),
										Expanded(
											child: _buildLinesTable(
												verticalController: _fullscreenVerticalController,
												horizontalController: _fullscreenHorizontalController,
												minWidth: 1200,
											),
										),
										const Divider(height: 1, color: Color(0xFFE5E7EB)),
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
											child: Align(
												alignment: Alignment.centerRight,
												child: Text(
													'Total HT: ${_formatCurrency(_currentTotalHt)}',
													style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF000091)),
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
		final missionRef = _selectedInvoiceMissionRef ?? invoice.missionRef;
		final isLocked = _isInvoiceLockedForEdition(invoice);
		final billedAtLabel = invoice.billedAt != null ? DateFormat('dd/MM/yyyy').format(invoice.billedAt!) : 'Non émise';
		final lines = _selectedInvoiceLineEditors.map((editor) => editor.currentLine).toList(growable: false);
		final totalHt = lines.isNotEmpty ? _selectedMissionTotalHt : (_selectedInvoiceLines?.totalHt ?? invoice.amountHt);

		final chips = <Widget>[
			Container(
				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
				decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFD6DAE6))),
				child: Text('Émise le $billedAtLabel', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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

		final actions = <Widget>[];
		if (isLocked) {
			actions.add(
				Container(
					width: double.infinity,
					margin: const EdgeInsets.only(bottom: 12),
					padding: const EdgeInsets.all(10),
					decoration: BoxDecoration(
						color: const Color(0xFFFEF3C7),
						borderRadius: BorderRadius.circular(8),
						border: Border.all(color: const Color(0xFFF59E0B)),
					),
					child: const Text('Facture payée : les lignes du détail sont verrouillées.'),
				),
			);
		}
		if (!isLocked && missionRef != null && missionRef.trim().isNotEmpty) {
			actions.add(
				Padding(
					padding: const EdgeInsets.only(bottom: 12),
					child: Row(
						children: [
							OutlinedButton.icon(
								onPressed: _selectedInvoiceLineEditors.isEmpty ? null : _resetSelectedInvoiceLines,
								icon: const Icon(Icons.restore),
								label: const Text('Réinitialiser'),
							),
							const SizedBox(width: 12),
							Expanded(
								child: FilledButton.icon(
									onPressed: _savingInvoiceLinesPanel || !_hasSelectedInvoiceLineChanges ? null : _saveSelectedInvoiceLines,
									icon: _savingInvoiceLinesPanel
										? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.save_outlined),
									label: Text(_savingInvoiceLinesPanel ? 'Enregistrement...' : 'Enregistrer les lignes'),
								),
							),
						],
					),
				),
			);
		}

		final linesContent = _loadingInvoiceLinesPanel
			? const Center(child: CircularProgressIndicator())
			: missionRef == null || missionRef.trim().isEmpty
				? const Center(child: Text('Aucune référence mission disponible pour cette facture.'))
				: lines.isEmpty
					? const Center(child: Text('Aucune ligne trouvée pour cette mission.'))
					: Scrollbar(
						thumbVisibility: true,
						child: ListView.separated(
							itemCount: lines.length,
							separatorBuilder: (_, __) => const Divider(height: 20),
							itemBuilder: (context, index) => _buildStoredInvoiceLineTile(index, isLocked: isLocked),
						),
					);

		return Align(
			alignment: Alignment.centerRight,
			child: ConstrainedBox(
				constraints: const BoxConstraints(maxWidth: 470),
				child: Material(
					elevation: 8,
					borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
					child: Container(
						color: Colors.white,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(
									padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing - 2),
									decoration: const BoxDecoration(
										color: Color(0xFFF4F6FB),
										borderRadius: BorderRadius.only(topLeft: Radius.circular(18)),
										border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
									),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													Container(
														padding: const EdgeInsets.all(10),
														decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
														child: const Icon(Icons.account_tree_outlined, color: Color(0xFF000091)),
													),
													const SizedBox(width: 12),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text('Niveau 2 • Détail facture', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF000091), fontWeight: FontWeight.w700)),
																const SizedBox(height: 4),
																Text('Facture ${invoice.invoiceNumber}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
																const SizedBox(height: 2),
																Text(invoice.clientName.isEmpty ? 'Client non renseigné' : invoice.clientName, style: const TextStyle(color: Color(0xFF6B7280))),
															],
														),
													),
													IconButton(onPressed: _closeInvoiceDetails, icon: const Icon(Icons.close)),
												],
											),
											const SizedBox(height: 12),
											Wrap(spacing: 8, runSpacing: 8, children: chips),
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
												...actions,
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
	}

	Widget _buildInvoiceLineTile(InvoiceLine line) {
		final designation = line.designation.trim().isEmpty ? 'Ligne sans libellé' : line.designation.trim();
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
				Text('Total HT ${_formatCurrency(line.totalHt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
				if (notes != null && notes.isNotEmpty) ...[
					const SizedBox(height: 6),
					Text(notes, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
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
							Expanded(child: Text('Ligne ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
							TextButton.icon(
								onPressed: () => _resetStoredInvoiceLine(index),
								icon: const Icon(Icons.undo, size: 18),
								label: const Text('Annuler'),
							),
						],
					),
					const SizedBox(height: 8),
					const Text('Désignation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
					const SizedBox(height: 4),
					_InlineEditableTextCell(
						key: ValueKey('detail-designation-$index'),
						width: double.infinity,
						text: line.designation,
						onChanged: (value) => _updateStoredInvoiceLine(index, designation: value),
					),
					const SizedBox(height: 10),
					const Text('TVA', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
					const SizedBox(height: 4),
					DropdownButtonFormField<double>(
						initialValue: _tvaOptionFor(line.tvaRate),
						items: _tvaRates
							.map((rate) => DropdownMenuItem(value: rate, child: Text('${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %')))
							.toList(),
						onChanged: (value) => _updateStoredInvoiceLine(index, tvaRate: value ?? 0),
						decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
					),
					const SizedBox(height: 10),
					Row(
						children: [
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('P.U. HT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
										const SizedBox(height: 4),
										_InlineEditableNumberCell(
											key: ValueKey('detail-unit-price-$index'),
											width: double.infinity,
											value: line.unitPrice,
											onNumberChanged: (value) => _updateStoredInvoiceLine(index, unitPrice: value),
										),
									],
								),
							),
							const SizedBox(width: 10),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Qté', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
										const SizedBox(height: 4),
										_InlineEditableNumberCell(
											key: ValueKey('detail-quantity-$index'),
											width: double.infinity,
											value: line.quantity,
											fractionDigits: 2,
											onNumberChanged: (value) => _updateStoredInvoiceLine(index, quantity: value),
										),
									],
								),
							),
						],
					),
					const SizedBox(height: 10),
					const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
					const SizedBox(height: 4),
					_InlineEditableTextCell(
						key: ValueKey('detail-notes-$index'),
						width: double.infinity,
						text: line.notes ?? '',
						onChanged: (value) => _updateStoredInvoiceLine(index, notes: value),
						maxLines: 2,
					),
					const SizedBox(height: 10),
					Text('Total HT ${_formatCurrency(line.totalHt)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF000091))),
				],
			),
		);
	}

	void _openInvoiceDetails(ClientInvoiceSummary invoice, {String? missionRef}) {
		final effectiveMissionRef = missionRef ?? invoice.missionRef;
		final alreadySelected = _selectedInvoice?.invoiceNumber == invoice.invoiceNumber && _selectedInvoiceMissionRef == effectiveMissionRef;
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

	Future<void> _loadInvoiceLines(ClientInvoiceSummary invoice, {String? missionRef}) async {
		try {
			final result = await BillingService.fetchInvoiceLines(invoice.invoiceNumber, missionRef: missionRef);
			if (!mounted) return;
			if (_selectedInvoice?.invoiceNumber != invoice.invoiceNumber || _selectedInvoiceMissionRef != missionRef) return;
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
				SnackBar(content: Text('Impossible de charger les lignes de ${invoice.invoiceNumber}.')),
			);
		}
	}

	Future<void> _saveSelectedInvoiceLines() async {
		final invoice = _selectedInvoice;
		final missionRef = _selectedInvoiceMissionRef;
		if (invoice == null || missionRef == null || missionRef.trim().isEmpty) return;
		setState(() => _savingInvoiceLinesPanel = true);
		try {
			final result = await BillingService.updateInvoiceLines(
				invoiceNumber: invoice.invoiceNumber,
				missionRef: missionRef,
				lines: _selectedInvoiceLineEditors.map((editor) => editor.currentLine).toList(growable: false),
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
				const SnackBar(content: Text('Les lignes de facture ont été mises à jour.')),
			);
		} catch (error, stack) {
			debugPrint('Failed to update invoice lines: $error');
			debugPrint(stack.toString());
			if (!mounted) return;
			setState(() => _savingInvoiceLinesPanel = false);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
			);
		}
	}

	void _updateStoredInvoiceLine(
		int index, {
		String? designation,
		double? quantity,
		double? unitPrice,
		double? tvaRate,
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

	Future<void> _changeInvoiceStatus(ClientInvoiceSummary invoice, String newLabel) async {
		final newCode = _invoiceStatusCodeForLabel(newLabel);
		final updated = invoice.copyWith(statusCode: newCode, statusLabel: newLabel);
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
				SnackBar(content: Text('Mise à jour du statut impossible. Vérifiez votre connexion.')),
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
				);
			}
		}
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
					borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
					child: Container(
						padding: EdgeInsets.all(spacing),
						color: Colors.white,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									children: [
										Expanded(
											child: Text('Édition de la ligne', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
										),
										IconButton(onPressed: _closeLineEditor, icon: const Icon(Icons.close)),
									],
								),
								const SizedBox(height: 12),
								TextFormField(
									controller: _lineDesignationCtrl,
									maxLines: 3,
									decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
									onChanged: (value) => _updateSelectedLine(designation: value),
								),
								const SizedBox(height: 12),
								Row(
									children: [
										Expanded(
											child: TextFormField(
												controller: _lineQuantityCtrl,
												keyboardType: const TextInputType.numberWithOptions(decimal: true),
												decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
												onChanged: (value) => _updateSelectedLine(quantity: double.tryParse(value.replaceAll(',', '.'))),
											),
										),
										const SizedBox(width: 12),
										Expanded(
											child: TextFormField(
												controller: _lineUnitPriceCtrl,
												keyboardType: const TextInputType.numberWithOptions(decimal: true),
												decoration: const InputDecoration(labelText: 'Prix unitaire HT', border: OutlineInputBorder()),
												onChanged: (value) => _updateSelectedLine(unitPrice: double.tryParse(value.replaceAll(',', '.'))),
											),
										),
									],
								),
								const SizedBox(height: 12),
								DropdownButtonFormField<double>(
									initialValue: _tvaOptionFor(line.tvaRate),
									items: _tvaRates
										.map((rate) => DropdownMenuItem(value: rate, child: Text('${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)} %')))
										.toList(),
									onChanged: (value) => _updateSelectedLine(tvaRate: value ?? 0),
									decoration: const InputDecoration(labelText: 'TVA', border: OutlineInputBorder()),
								),
								const SizedBox(height: 12),
								TextFormField(
									controller: _lineNotesCtrl,
									maxLines: 2,
									decoration: const InputDecoration(labelText: 'Notes (optionnel)', border: OutlineInputBorder()),
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
											Text('Total HT de la ligne : ${_formatCurrency(line.totalHt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
											if (editor.missionRef != null)
												Text('Mission liée : ${editor.missionRef}', style: const TextStyle(color: Color(0xFF6B7280))),
										],
									),
								),
								const SizedBox(height: 16),
								Row(
									children: [
										OutlinedButton.icon(onPressed: _resetSelectedLine, icon: const Icon(Icons.restore), label: const Text('Réinitialiser la ligne')),
										const SizedBox(width: 12),
										FilledButton.icon(onPressed: _lineEditors.length == 1 ? null : _resetAllLines, icon: const Icon(Icons.auto_fix_high), label: const Text('Réinitialiser tout')),
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
		_lineQuantityCtrl = TextEditingController(text: _quantityFormat.format(line.quantity));
		_lineUnitPriceCtrl = TextEditingController(text: line.unitPrice.toStringAsFixed(2));
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

	void _updateLineFields(int index, {String? designation, double? quantity, double? unitPrice, double? tvaRate}) {
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

	void _updateSelectedLine({String? designation, double? quantity, double? unitPrice, double? tvaRate, String? notes}) {
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
		_draftSaveTimer = Timer(const Duration(milliseconds: 800), _persistDraftLines);
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
			);
			if (!mounted) return;
			setState(() => _draftKey = key);
		} catch (error) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'enregistrer les modifications (${error.toString()})')));
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
			final drafts = await BillingService.fetchInvoiceDraftLines(clientName: _currentClientName, periodMonth: period, draftKey: key);
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
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un client.')));
			return;
		}
		setState(() {
			_loadingMissions = true;
			_loadError = null;
		});
		final normalized = client.toLowerCase();
		try {
			final missions = await MissionService.getMissionsDatatableAll(q: client);
			if (!mounted) return;
			final filtered = missions
				.where((mission) => _missionMatchesClient(mission, normalized))
				.map((mission) => Map<String, dynamic>.from(mission))
				.toList();
			setState(() {
				_allClientMissions = filtered;
				_loadingMissions = false;
			});
			_applyMonthFilter();
			if (filtered.isEmpty) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune mission trouvée pour ce client sur les 12 derniers mois.')));
			}
		} catch (_) {
			if (!mounted) return;
			setState(() {
				_loadingMissions = false;
				_allClientMissions = [];
				_missions = [];
				_lineEditors.clear();
				_loadError = 'Impossible de récupérer les missions (connexion ou API).';
			});
		}
	}

	Future<void> _generatePdfFromTable() async {
		if (_lineEditors.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargez des missions avant de générer un PDF.')));
			return;
		}
		setState(() => _generatingPdf = true);
		final lines = _lineEditors.map((editor) => editor.currentLine).toList();
		try {
			await _ensurePdfAssets();
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
				.toList();
			final clientLabel = _currentClientName.isEmpty ? 'Client non renseigné' : _currentClientName;
			final clientAddressLines = _clientAddressLinesForPdf();
			final now = DateTime.now();
			final theme = pw.ThemeData.withFont(base: _pdfFontRegular!, bold: _pdfFontBold!);
			final doc = pw.Document(theme: theme);
			final accent = PdfColor.fromHex('#000091');
			final borderColor = PdfColor.fromHex('#E5E7EB');
			final companyInfo = _resolvedCompanyInfo;
			final companyLines = _companyInfoLinesForPdf(companyInfo);
			final hasLogo = _pdfLogoImage != null;
			final logoWidget = hasLogo
				? pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), height: 48, child: pw.Image(_pdfLogoImage!, fit: pw.BoxFit.contain))
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
							pw.Text('Émetteur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accent)),
							pw.SizedBox(height: 4),
							...companyLines.map((line) => pw.Text(line, style: const pw.TextStyle(fontSize: 11))),
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
						pw.Text('Destinataire', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#BE185D'))),
						pw.SizedBox(height: 4),
						pw.Text(clientLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
						if (clientAddressLines.isNotEmpty) ...[
							pw.SizedBox(height: 2),
							...clientAddressLines.map((line) => pw.Text(line, style: const pw.TextStyle(fontSize: 11))),
						],
						pw.SizedBox(height: clientAddressLines.isNotEmpty ? 6 : 2),
						pw.Text('Période : ${_monthLabel(_selectedMonth)}', style: const pw.TextStyle(fontSize: 11)),
					],
				),
			);
			final headerColumns = <pw.Widget>[];
			if (companyCard != null) {
				headerColumns.add(pw.Expanded(flex: 3, child: companyCard));
			}
			if (companyCard != null) {
				headerColumns.add(pw.SizedBox(width: 14));
			}
			headerColumns.add(pw.Expanded(flex: 3, child: clientCard));
			final headerStack = <pw.Widget>[];
			if (logoWidget != null) {
				headerStack.add(pw.Align(alignment: pw.Alignment.centerLeft, child: logoWidget));
			}
			headerStack.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: headerColumns));
			doc.addPage(
				pw.MultiPage(
					pageFormat: PdfPageFormat.a4,
					margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
					build: (context) => [
						pw.SizedBox(height: 6),
						...headerStack,
						pw.SizedBox(height: 16),
						pw.TableHelper.fromTextArray(
							headers: headers,
							data: rows,
							border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: borderColor, width: 0.25), outside: pw.BorderSide(color: borderColor, width: 0.5)),
							headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
							headerDecoration: pw.BoxDecoration(color: accent),
							cellStyle: const pw.TextStyle(fontSize: 10.5),
							cellAlignments: {
								0: pw.Alignment.centerLeft,
								1: pw.Alignment.center,
								2: pw.Alignment.centerRight,
								3: pw.Alignment.centerRight,
								4: pw.Alignment.centerRight,
							},
							),
						],
						),
					);
					final bytes = await doc.save();
					final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);
					final sanitizedClient = _currentClientName.trim().isEmpty
						? 'client'
						: _currentClientName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
					final filename = 'Facture_${sanitizedClient}_$timestamp.pdf';
					if (canSavePdfToDownloads) {
						await savePdfToDownloads(bytes, filename);
					} else {
						await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
					}
		} catch (e, stack) {
			debugPrint('PDF generation failed: $e');
			debugPrint(stack.toString());
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de générer le PDF. Veuillez réessayer.')));
		} finally {
			if (mounted) {
				setState(() => _generatingPdf = false);
			}
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
			final date = _missionDate(mission);
			if (date == null) return false;
			return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
		}).toList();
		filtered.sort((a, b) {
			final dateA = _missionDate(a);
			final dateB = _missionDate(b);
			if (dateA == null && dateB == null) return 0;
			if (dateA == null) return 1;
			if (dateB == null) return -1;
			return dateB.compareTo(dateA);
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
				final mission = draft.missionRef != null ? missionByRef[draft.missionRef!] : null;
				final original = mission != null ? _invoiceLineFromMission(mission) : draft.copy();
				newEditors.add(_EditableInvoiceLine(mission: mission, originalLine: original, currentLine: draft.copy()));
				if (draft.missionRef != null) consumedRefs.add(draft.missionRef!);
			}
		}
		for (final mission in _missions) {
			final ref = _missionRef(mission);
			if (ref != null && consumedRefs.contains(ref)) continue;
			final line = _invoiceLineFromMission(mission);
			newEditors.add(_EditableInvoiceLine(mission: mission, originalLine: line, currentLine: line.copy()));
		}
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
			setState(() {
				_companyInfo = info;
				_loadingCompanyInfo = false;
			});
		} catch (error, stack) {
			debugPrint('Failed to load company info: $error');
			debugPrint(stack.toString());
			if (!mounted) return;
			setState(() {
				_companyInfo = CompanyInfo.fallback();
				_loadingCompanyInfo = false;
			});
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
				clientName: _invoiceClientFilter.isEmpty ? null : _invoiceClientFilter,
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
						if (invoice.invoiceNumber == previouslySelected.invoiceNumber && invoice.missionRef == selectedMissionRef) {
							refreshed = invoice;
							break;
						}
					}
					refreshed ??= result.invoices.cast<ClientInvoiceSummary?>().firstWhere(
						(invoice) => invoice?.invoiceNumber == previouslySelected.invoiceNumber,
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
			});
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

	bool _isInvoiceStatusBeingUpdated(String invoiceNumber) => _updatingInvoiceStatus.contains(invoiceNumber);

	bool get _hasSelectedInvoiceLineChanges {
		for (final editor in _selectedInvoiceLineEditors) {
			if (!_invoiceLinesEqual(editor.originalLine, editor.currentLine)) {
				return true;
			}
		}
		return false;
	}

	double get _selectedMissionTotalHt => _selectedInvoiceLineEditors.fold(0, (sum, editor) => sum + editor.currentLine.totalHt);

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
			(left.notes ?? '') == (right.notes ?? '');
	}

	String get _currentClientName => _clientInput.trim();
	double get _currentTotalHt => _lineEditors.fold(0, (sum, editor) => sum + editor.currentLine.totalHt);

	List<DateTime> _buildAvailableMonths({int monthsBack = 12}) {
		final now = DateTime.now();
		return List<DateTime>.generate(monthsBack, (index) {
			final date = DateTime(now.year, now.month - index, 1);
			return DateTime(date.year, date.month);
		});
	}

	String _monthLabel(DateTime month) {
		const monthNames = [
			'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
			'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
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
			: ((produitRef != null && produitRef.isNotEmpty) ? produitRef : 'Mission');
		lines.add(title);
		final date = _missionDate(mission);
		final dateLabel = date != null ? DateFormat('dd/MM/yyyy').format(date) : '-';
		lines.add('Date : $dateLabel');
		final timeRange = _timeRangeLabel(mission);
		lines.add('Heure : ${timeRange.isNotEmpty ? timeRange : '-'}');
		final duration = _formatMissionDuration(mission);
		lines.add('Durée : ${duration.isNotEmpty ? duration : '-'}');
		final requester = _missionRequester(mission);
		lines.add('Demandeur : ${requester.isNotEmpty ? requester : '-'}');
		return lines;
	}

	String _designationFor(Map<String, dynamic> mission) => _designationLines(mission).join('\n');

	String _formatMissionDuration(Map<String, dynamic> mission) {
		final raw = mission['dureemission'] ?? mission['duration'] ?? mission['duration_minutes'];
		final parsed = _parseDurationMinutes(raw);
		if (parsed == null || parsed <= 0) return '';
		if (parsed % 60 == 0) {
			return '${(parsed / 60).round()}h';
		}
		return '${parsed.round()} min';
	}

	String _timeRangeLabel(Map<String, dynamic> mission) {
		final start = (mission['heuredebutmission'] ?? mission['heure_debut'] ?? mission['start_time'] ?? '').toString().trim();
		final end = (mission['heurefinmission'] ?? mission['heure_fin'] ?? mission['end_time'] ?? '').toString().trim();
		if (start.isEmpty && end.isEmpty) return '';
		if (start.isNotEmpty && end.isNotEmpty) {
			return '$start → $end';
		}
		return start.isNotEmpty ? start : end;
	}

	String _missionRequester(Map<String, dynamic> mission) {
		final firstCandidates = [mission['prenom_demandeur'], mission['contactdemandeur_firstname'], mission['demandeur_firstname']];
		final lastCandidates = [mission['nom_demandeur'], mission['contactdemandeur_lastname'], mission['demandeur_lastname']];
		final first = _cleanPersonPart(firstCandidates);
		final last = _cleanPersonPart(lastCandidates);
		if (first != null && last != null) {
			return '${_capitalize(first)} ${last.toUpperCase()}';
		}
		final combinedCandidates = [mission['demandeur'], mission['contactdemandeur_name']];
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
		final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll(',', '.');
		return double.tryParse(cleaned) ?? 0;
	}

	double? _parseDurationMinutes(dynamic raw) {
		if (raw == null) return null;
		if (raw is num) return raw.toDouble();
		final text = raw.toString().trim();
		if (text.isEmpty) return null;
		final normalized = text.replaceAll(',', '.');
		final hhmmMatch = RegExp(r'^(\d{1,2})[:hH](\d{1,2})$').firstMatch(normalized);
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
		final direct = mission['dureemission'] ?? mission['duration'] ?? mission['duration_minutes'];
		final parsed = _parseDurationMinutes(direct);
		if (parsed != null) return parsed;
		final startRaw = mission['heuredebutmission'] ?? mission['heure_debut'] ?? mission['start_time'];
		final endRaw = mission['heurefinmission'] ?? mission['heure_fin'] ?? mission['end_time'];
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

	bool _missionMatchesClient(Map<String, dynamic> mission, String normalizedClient) {
		final clientName = (mission['client_name'] ?? mission['nom'] ?? mission['company'] ?? '').toString().toLowerCase();
		if (clientName.contains(normalizedClient)) return true;
		final ref = (mission['reference_devis'] ?? mission['ref'] ?? '').toString().toLowerCase();
		return ref.contains(normalizedClient);
	}

	List<String> _clientAddressLinesForPdf() {
		final mission = _missionWithClientDetails();
		if (mission == null) return [];
		final lines = <String>[];
		final address1 = _stringValueFromKeys(mission, const ['client_address', 'client_address_line1', 'client_address1', 'adresse_client', 'adresse', 'address']);
		final address2 = _stringValueFromKeys(mission, const ['client_address2', 'client_address_line2', 'adresse_client2', 'adresse2', 'address2']);
		final zip = _stringValueFromKeys(mission, const ['client_zip', 'zip', 'cp']);
		final city = _stringValueFromKeys(mission, const ['client_town', 'client_city', 'ville', 'town', 'city']);
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
		return _stringValueFromKeys(mission, const ['client_address', 'client_address_line1', 'client_address1', 'adresse_client', 'adresse', 'address']).isNotEmpty ||
			_stringValueFromKeys(mission, const ['client_zip', 'zip', 'cp', 'client_town', 'client_city', 'ville', 'town', 'city']).isNotEmpty;
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

	CompanyInfo get _resolvedCompanyInfo => _companyInfo ?? CompanyInfo.fallback();

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

	String? _missionRef(Map<String, dynamic> mission) {
		final candidates = [mission['reference_devis'], mission['reference'], mission['ref'], mission['mission_ref']];
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

	String? get missionRef => mission?['reference_devis']?.toString() ?? mission?['reference']?.toString() ?? currentLine.missionRef;

	void reset() {
		currentLine = originalLine.copy();
	}
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
							Icon(icon, color: selected ? const Color(0xFF000091) : const Color(0xFF4B5563)),
							if (!collapsed) ...[
								const SizedBox(width: 12),
								Expanded(
									child: Text(
										label,
										style: TextStyle(
											fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
											color: selected ? const Color(0xFF000091) : const Color(0xFF374151),
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
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: const [
					SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
	State<_InlineEditableTextCell> createState() => _InlineEditableTextCellState();
}

class _InlineEditableTextCellState extends State<_InlineEditableTextCell> {
	late final TextEditingController _controller = TextEditingController(text: widget.text);
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
	State<_InlineEditableNumberCell> createState() => _InlineEditableNumberCellState();
}

class _InlineEditableNumberCellState extends State<_InlineEditableNumberCell> {
	late final TextEditingController _controller = TextEditingController(text: _format(widget.value));
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