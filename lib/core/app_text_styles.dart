import 'package:flutter/material.dart';

/// Styles de texte centralisés — révisés pour une meilleure densité visuelle :
///   Texte général  : 12–13 px
///   Menus / Nav    : 12–13 px (réduit depuis 14–15 px)
///   Titres         : 16–18 px (réduit depuis 20 px)
///   Tableaux       : 12 px
abstract class AppTextStyles {
  // ── Corps ──────────────────────────────────────────────────────────────────
  /// Texte général principal (formulaires, contenu)
  static const body = TextStyle(fontSize: 13, color: Color(0xFF161616));

  /// Texte secondaire, métadonnées, notes
  static const bodySmall = TextStyle(fontSize: 12, color: Color(0xFF6B7280));

  // ── Tableaux ───────────────────────────────────────────────────────────────
  /// Cellules de tableau (données)
  static const tableCell = TextStyle(fontSize: 12, color: Color(0xFF0F172A));

  /// En-têtes de colonne
  static const tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF374151),
  );

  // ── Labels / Champs ────────────────────────────────────────────────────────
  /// Label de champ de formulaire
  static const fieldLabel = TextStyle(
    fontSize: 12,           // réduit : 13 → 12
    fontWeight: FontWeight.w600,
    color: Color(0xFF374151),
  );

  /// Valeur lue seule (read-only)
  static const fieldValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF374151),
  );

  // ── Menus / Navigation ─────────────────────────────────────────────────────
  /// Item de menu / onglet
  static const menuItem = TextStyle(fontSize: 13, color: Color(0xFF161616));

  /// Item de menu actif
  static const menuItemActive = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Color(0xFF000091),
  );

  // ── Titres ─────────────────────────────────────────────────────────────────
  /// Titre de page (réduit 20 → 18 px)
  static const pageTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Color(0xFF161616),
  );

  /// Titre de section / panneau (réduit 16 → 15 px)
  static const sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Color(0xFF161616),
  );

  /// Sous-titre / groupe (réduit 14 → 13 px)
  static const subTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF374151),
  );

  // ── Totaux / Montants ──────────────────────────────────────────────────────
  /// Total principal (bas de tableau)
  static const totalMain = TextStyle(
    fontSize: 14,           // réduit 16 → 14
    fontWeight: FontWeight.w700,
    color: Color(0xFF000091),
  );

  /// Total plein écran
  static const totalFullscreen = TextStyle(
    fontSize: 16,           // réduit 18 → 16
    fontWeight: FontWeight.w700,
    color: Color(0xFF000091),
  );

  /// Total TTC (accent bleu)
  static const totalTtc = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1D4ED8),
  );

  /// Total TTC plein écran
  static const totalTtcFullscreen = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1D4ED8),
  );

  // ── Badges / Tags ──────────────────────────────────────────────────────────
  /// Badge statut
  static const badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}
