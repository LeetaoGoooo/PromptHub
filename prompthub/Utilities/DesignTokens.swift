// DesignTokens.swift
// Canonical design system for PromptHub macOS
// Source of truth: screens/skills-unified-workbench-mock.html, prompts-*, agents-*
// All raw values are frozen — change here, not inline.

import SwiftUI

// MARK: - PH (PromptHub design namespace)
enum PH {}

// MARK: Color Tokens
extension PH {
    enum Color {
        // Text
        static let primary   = SwiftUI.Color(red: 0.122, green: 0.161, blue: 0.251)  // #1f2940
        static let secondary = SwiftUI.Color(red: 0.341, green: 0.388, blue: 0.490)  // #57637d
        static let tertiary  = SwiftUI.Color(red: 0.510, green: 0.565, blue: 0.659)  // #8290a8

        // Accent
        static let accent    = SwiftUI.Color(red: 0.239, green: 0.404, blue: 0.843)  // #3d67d7
        static let accentTint = SwiftUI.Color(red: 0.239, green: 0.404, blue: 0.843).opacity(0.10)

        // Status
        static let statusOK   = SwiftUI.Color(red: 0.102, green: 0.478, blue: 0.337)  // #1a7a56
        static let statusWarn = SwiftUI.Color(red: 0.659, green: 0.373, blue: 0.078)  // #a85f14
        static let statusFail = SwiftUI.Color(red: 0.627, green: 0.251, blue: 0.314)  // #a04050

        // Surfaces
        static let stroke     = SwiftUI.Color(red: 0.122, green: 0.176, blue: 0.290).opacity(0.09)
        static let strokeSoft = SwiftUI.Color(red: 0.122, green: 0.176, blue: 0.290).opacity(0.055)
        static let sidebarBg  = SwiftUI.Color(red: 0.129, green: 0.173, blue: 0.282).opacity(0.042)
        static let detailBg   = SwiftUI.Color.white.opacity(0.28)
        static let chipBg     = SwiftUI.Color(red: 0.122, green: 0.176, blue: 0.290).opacity(0.055)
        static let badgeBg    = SwiftUI.Color(red: 0.122, green: 0.176, blue: 0.290).opacity(0.07)
        static let filterBg   = SwiftUI.Color.white.opacity(0.30)
        static let buttonBg   = SwiftUI.Color.white.opacity(0.52)
        static let buttonBorder = SwiftUI.Color(red: 0.122, green: 0.176, blue: 0.290).opacity(0.09)

        // Dot status (6px inline indicator)
        static let dotNeutral = SwiftUI.Color(red: 0.592, green: 0.635, blue: 0.729)  // #97a2bb
    }
}

// MARK: Typography Tokens
extension PH {
    enum Font {
        /// Pane title — 15pt, bold, tracking -0.01em
        static let paneTitle: SwiftUI.Font = .system(size: 15, weight: .bold)
        static let paneTitleTracking: CGFloat = -0.15  // points equiv of -0.01em at 15pt

        /// Row primary name — 13pt, weight 650 (semibold maps closest)
        static let rowName: SwiftUI.Font = .system(size: 13, weight: .semibold)

        /// Row secondary / sub line — 11pt, regular
        static let rowSub: SwiftUI.Font = .system(size: 11, weight: .regular)

        /// Status / quality label — 11pt, bold
        static let statusLabel: SwiftUI.Font = .system(size: 11, weight: .bold)

        /// Detail body prose — 13pt, regular, line spacing ~1.58
        static let body: SwiftUI.Font = .system(size: 13, weight: .regular)
        static let bodyLineSpacing: CGFloat = 7.5  // ≈ (13 * 0.58) / 1

        /// Section head label — 11pt, bold (used next to icon in ds-head)
        static let sectionHead: SwiftUI.Font = .system(size: 11, weight: .bold)

        /// Group separator label — 10pt, bold, uppercase (sidebar SEC_LBL)
        static let groupLabel: SwiftUI.Font = .system(size: 10, weight: .bold)

        /// Badge / count — 10pt, bold
        static let badge: SwiftUI.Font = .system(size: 10, weight: .bold)

        /// KV key column — 12pt, semibold
        static let kvKey: SwiftUI.Font = .system(size: 12, weight: .semibold)

        /// KV value — 12pt, regular
        static let kvValue: SwiftUI.Font = .system(size: 12, weight: .regular)

        /// Monospace (paths, IDs, prompt body) — 11pt
        static let mono: SwiftUI.Font = .system(size: 11, design: .monospaced)
        static let monoBody: SwiftUI.Font = .system(size: 12, design: .monospaced)

        /// Toolbar filter placeholder — 12pt
        static let filter: SwiftUI.Font = .system(size: 12)

        /// Chip label — 11pt, bold
        static let chip: SwiftUI.Font = .system(size: 11, weight: .bold)

        /// Detail subtitle (below title in dh) — 12pt, regular
        static let detailSub: SwiftUI.Font = .system(size: 12, weight: .regular)
    }
}

// MARK: Spacing Tokens
extension PH {
    enum Spacing {
        static let rowH: CGFloat      = 8    // row vertical padding
        static let rowV: CGFloat      = 9    // row horizontal padding
        static let rowCorner: CGFloat = 7    // row border-radius
        static let rowGap: CGFloat    = 3    // gap between row line 1 and line 2
        static let rowItemGap: CGFloat = 8   // gap between icon and name inside row top

        static let sectionV: CGFloat  = 10   // section (ds) top/bottom padding
        static let sectionHeadGap: CGFloat = 5    // gap between icon and label in ds-head
        static let sectionHeadMB: CGFloat  = 7    // margin-bottom of ds-head
        static let detailH: CGFloat   = 15   // detail pane horizontal padding
        static let detailB: CGFloat   = 15   // detail pane bottom padding

        static let kvColWidth: CGFloat = 90  // KV left column fixed width
        static let kvRowGap: CGFloat   = 10  // horizontal gap between key and value
        static let kvRowV: CGFloat     = 5   // kv row vertical padding

        static let chipH: CGFloat     = 6    // chip horizontal padding
        static let chipCorner: CGFloat = 6   // chip border-radius
        static let chipMinH: CGFloat   = 20  // chip minimum height

        static let badgeH: CGFloat    = 5    // badge horizontal padding
        static let badgeCorner: CGFloat = 999  // pill shape
        static let badgeMinH: CGFloat  = 16   // badge minimum height
        static let badgeMinW: CGFloat  = 18   // badge minimum width

        static let paneHeaderV: CGFloat = 10  // ph: vertical padding
        static let paneHeaderH: CGFloat = 13  // ph: horizontal padding

        static let toolbarV: CGFloat   = 6   // tbar: vertical padding
        static let toolbarH: CGFloat   = 8   // tbar: horizontal padding
        static let toolbarGap: CGFloat = 6   // gap between search field and chips

        static let filterH: CGFloat    = 8   // filter field horizontal padding
        static let filterCorner: CGFloat = 7 // filter field radius

        static let sbSectionGap: CGFloat = 3 // top margin of sidebar SEC_LBL
        static let sbPad: CGFloat        = 6 // sidebar outer horizontal padding
        static let sbRowGap: CGFloat     = 7 // gap inside sidebar nav row (icon → label)
        static let sbChipGap: CGFloat    = 4 // gap between sidebar chips

        static let btnGap: CGFloat     = 5   // gap inside button (icon → text)
        static let btnH: CGFloat       = 9   // button horizontal padding
        static let btnHeight: CGFloat  = 27  // button standard height
        static let btnSqSize: CGFloat  = 27  // square button width = height
        static let btnCorner: CGFloat  = 8   // button border-radius
    }
}

// MARK: Layout Tokens
extension PH {
    enum Layout {
        static let sidebarWidth: CGFloat  = 216
        static let listPaneWidth: CGFloat = 316
        static let windowMaxWidth: CGFloat = 1560
        static let windowHeight: CGFloat   = 950
        static let titlebarHeight: CGFloat = 50
        static let windowCorner: CGFloat   = 22
        static let iconSize: CGFloat       = 14   // standard inline icon
        static let iconSizeSm: CGFloat     = 13   // section head icon
        static let iconStroke: CGFloat     = 1.5  // SF-style stroke width
        static let statusDotSize: CGFloat  = 6    // inline status indicator dot
    }
}

// MARK: Shadow Tokens
extension PH {
    enum Shadow {
        /// Window outer shadow — two-layer
        static let window: [(color: SwiftUI.Color, radius: CGFloat, x: CGFloat, y: CGFloat)] = [
            (SwiftUI.Color(red: 0.129, green: 0.192, blue: 0.329).opacity(0.17), 32, 0, 12),
            (SwiftUI.Color(red: 0.129, green: 0.192, blue: 0.329).opacity(0.09),  8, 0,  3),
        ]
    }
}

// MARK: - Convenience Color Extensions
extension SwiftUI.Color {
    // Shorthand access: Color.ph.accent
    static var ph: PH.Color.Type { PH.Color.self }
}
