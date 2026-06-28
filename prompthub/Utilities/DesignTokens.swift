// DesignTokens.swift
// Canonical design system for PromptHub macOS
// Source of truth: screens/skills-unified-workbench-mock.html, prompts-*, agents-*
// All raw values are frozen — change here, not inline.

import AppKit
import SwiftUI

// MARK: - PH (PromptHub design namespace)
enum PH {}

// MARK: Color Tokens
extension PH {
    enum Color {
        private static func adaptive(light: NSColor, dark: NSColor) -> SwiftUI.Color {
            SwiftUI.Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return isDark ? dark : light
                }
            )
        }

        private static func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
            NSColor(
                srgbRed: red / 255,
                green: green / 255,
                blue: blue / 255,
                alpha: alpha
            )
        }

        // Text
        static var primary: SwiftUI.Color { SwiftUI.Color(nsColor: .labelColor) }
        static var secondary: SwiftUI.Color { SwiftUI.Color(nsColor: .secondaryLabelColor) }
        static var tertiary: SwiftUI.Color { SwiftUI.Color(nsColor: .tertiaryLabelColor) }

        // Accent
        static var accent: SwiftUI.Color {
            adaptive(
                light: rgba(36, 99, 235),
                dark: rgba(125, 166, 255)
            )
        }
        static var accentTint: SwiftUI.Color {
            adaptive(
                light: rgba(36, 99, 235, 0.14),
                dark: rgba(44, 67, 112)
            )
        }

        // Status
        static var statusOK: SwiftUI.Color {
            adaptive(
                light: rgba(26, 122, 86),
                dark: rgba(88, 201, 149)
            )
        }
        static var statusWarn: SwiftUI.Color {
            adaptive(
                light: rgba(168, 95, 20),
                dark: rgba(240, 171, 79)
            )
        }
        static var statusFail: SwiftUI.Color {
            adaptive(
                light: rgba(160, 64, 80),
                dark: rgba(255, 138, 152)
            )
        }

        // Surfaces
        static var stroke: SwiftUI.Color {
            adaptive(
                light: rgba(17, 24, 39, 0.11),
                dark: rgba(255, 255, 255, 0.16)
            )
        }
        static var strokeSoft: SwiftUI.Color {
            adaptive(
                light: rgba(17, 24, 39, 0.06),
                dark: rgba(255, 255, 255, 0.10)
            )
        }
        static var sidebarBg: SwiftUI.Color {
            adaptive(
                light: rgba(244, 245, 247),
                dark: rgba(255, 255, 255, 0.06)
            )
        }
        static var detailBg: SwiftUI.Color {
            adaptive(
                light: rgba(255, 255, 255),
                dark: rgba(31, 36, 46)
            )
        }
        static var chipBg: SwiftUI.Color {
            adaptive(
                light: rgba(239, 241, 244),
                dark: rgba(255, 255, 255, 0.10)
            )
        }
        static var badgeBg: SwiftUI.Color {
            adaptive(
                light: rgba(239, 241, 244),
                dark: rgba(255, 255, 255, 0.12)
            )
        }
        static var filterBg: SwiftUI.Color {
            adaptive(
                light: rgba(244, 245, 247),
                dark: rgba(255, 255, 255, 0.12)
            )
        }
        static var buttonBg: SwiftUI.Color {
            adaptive(
                light: rgba(248, 249, 251),
                dark: rgba(255, 255, 255, 0.10)
            )
        }
        static var buttonBorder: SwiftUI.Color {
            adaptive(
                light: rgba(17, 24, 39, 0.10),
                dark: rgba(255, 255, 255, 0.16)
            )
        }
        static var selectedFill: SwiftUI.Color {
            adaptive(
                light: rgba(36, 99, 235),
                dark: rgba(72, 128, 255)
            )
        }
        static var hoverFill: SwiftUI.Color {
            adaptive(
                light: rgba(17, 24, 39, 0.035),
                dark: rgba(255, 255, 255, 0.08)
            )
        }
        static var windowBg: SwiftUI.Color {
            adaptive(
                light: rgba(249, 249, 250),
                dark: rgba(28, 29, 33)
            )
        }

        // Dot status (6px inline indicator)
        static var dotNeutral: SwiftUI.Color {
            adaptive(
                light: rgba(151, 162, 187),
                dark: rgba(127, 138, 163)
            )
        }
    }
}

// MARK: Typography Tokens
extension PH {
    enum Font {
        /// Pane title — 15pt, bold, tracking -0.01em
        static let paneTitle: SwiftUI.Font = .system(size: 14, weight: .semibold)
        static let paneTitleTracking: CGFloat = -0.15  // points equiv of -0.01em at 15pt

        /// Row primary name — 13pt, weight 650 (semibold maps closest)
        static let rowName: SwiftUI.Font = .system(size: 13, weight: .medium)

        /// Row secondary / sub line — 11pt, regular
        static let rowSub: SwiftUI.Font = .system(size: 11, weight: .regular)

        /// Status / quality label — 11pt, bold
        static let statusLabel: SwiftUI.Font = .system(size: 11, weight: .bold)

        /// Detail body prose — 13pt, regular, line spacing ~1.58
        static let body: SwiftUI.Font = .system(size: 13, weight: .regular)
        static let bodyLineSpacing: CGFloat = 7.5  // ≈ (13 * 0.58) / 1

        /// Section head label — 11pt, bold (used next to icon in ds-head)
        static let sectionHead: SwiftUI.Font = .system(size: 10, weight: .semibold)

        /// Group separator label — 10pt, bold, uppercase (sidebar SEC_LBL)
        static let groupLabel: SwiftUI.Font = .system(size: 10, weight: .semibold)

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
        static let chip: SwiftUI.Font = .system(size: 11, weight: .medium)

        /// Detail subtitle (below title in dh) — 12pt, regular
        static let detailSub: SwiftUI.Font = .system(size: 12, weight: .regular)

        /// Prompt detail headline
        static let heroTitle: SwiftUI.Font = .system(size: 28, weight: .bold)

        /// Drawer title used by prompt history panels
        static let drawerTitle: SwiftUI.Font = .system(size: 16, weight: .semibold)
    }
}

// MARK: Spacing Tokens
extension PH {
    enum Spacing {
        static let rowH: CGFloat      = 7    // row vertical padding
        static let rowV: CGFloat      = 10   // row horizontal padding
        static let rowCorner: CGFloat = 8    // row border-radius
        static let rowGap: CGFloat    = 3    // gap between row line 1 and line 2
        static let rowItemGap: CGFloat = 8   // gap between icon and name inside row top

        static let sectionV: CGFloat  = 8    // section (ds) top/bottom padding
        static let sectionHeadGap: CGFloat = 5    // gap between icon and label in ds-head
        static let sectionHeadMB: CGFloat  = 7    // margin-bottom of ds-head
        static let detailH: CGFloat   = 20   // detail pane horizontal padding
        static let detailB: CGFloat   = 18   // detail pane bottom padding

        static let kvColWidth: CGFloat = 90  // KV left column fixed width
        static let kvRowGap: CGFloat   = 10  // horizontal gap between key and value
        static let kvRowV: CGFloat     = 5   // kv row vertical padding

        static let chipH: CGFloat     = 7    // chip horizontal padding
        static let chipCorner: CGFloat = 6   // chip border-radius
        static let chipMinH: CGFloat   = 20  // chip minimum height

        static let badgeH: CGFloat    = 5    // badge horizontal padding
        static let badgeCorner: CGFloat = 999  // pill shape
        static let badgeMinH: CGFloat  = 16   // badge minimum height
        static let badgeMinW: CGFloat  = 18   // badge minimum width

        static let paneHeaderV: CGFloat = 8   // ph: vertical padding
        static let paneHeaderH: CGFloat = 14  // ph: horizontal padding

        static let toolbarV: CGFloat   = 5   // tbar: vertical padding
        static let toolbarH: CGFloat   = 10  // tbar: horizontal padding
        static let toolbarGap: CGFloat = 6   // gap between search field and chips

        static let filterH: CGFloat    = 8   // filter field horizontal padding
        static let filterCorner: CGFloat = 7 // filter field radius

        static let sbSectionGap: CGFloat = 2 // top margin of sidebar SEC_LBL
        static let sbPad: CGFloat        = 10 // sidebar outer horizontal padding
        static let sbRowGap: CGFloat     = 8 // gap inside sidebar nav row (icon → label)
        static let sbChipGap: CGFloat    = 4 // gap between sidebar chips

        static let btnGap: CGFloat     = 5   // gap inside button (icon → text)
        static let btnH: CGFloat       = 10  // button horizontal padding
        static let btnHeight: CGFloat  = 30  // button standard height
        static let btnSqSize: CGFloat  = 30  // square button width = height
        static let btnCorner: CGFloat  = 8   // button border-radius

        static let promptInset: CGFloat = 24
        static let promptHeaderGap: CGFloat = 8
        static let promptDrawerGap: CGFloat = 16
        static let promptDrawerCardGap: CGFloat = 10
        static let promptDrawerItemGap: CGFloat = 12
        static let promptPanelCorner: CGFloat = 12
        static let promptToolbarCapsuleH: CGFloat = 16
        static let promptToolbarCapsuleV: CGFloat = 10
        static let promptBodyLineSpacing: CGFloat = 4
    }
}

// MARK: Layout Tokens
extension PH {
    enum Layout {
        static let sidebarWidth: CGFloat  = 216
        static let listPaneWidth: CGFloat = 316
        static let windowMaxWidth: CGFloat = 1560
        static let windowHeight: CGFloat   = 950
        static let mainWindowMinHeightCap: CGFloat = 360
        static let mainWindowPromptsMinWidth: CGFloat = 740
        static let mainWindowPromptDetailMinWidth: CGFloat = 820
        static let mainWindowSkillsMinWidth: CGFloat = 740
        static let mainWindowSkillDetailMinWidth: CGFloat = 820
        static let mainWindowCLIMinWidth: CGFloat = 980
        static let mainWindowOnboardingMinWidth: CGFloat = 860
        static let titlebarHeight: CGFloat = 50
        static let windowCorner: CGFloat   = 22
        static let iconSize: CGFloat       = 14   // standard inline icon
        static let iconSizeSm: CGFloat     = 13   // section head icon
        static let iconStroke: CGFloat     = 1.5  // SF-style stroke width
        static let statusDotSize: CGFloat  = 6    // inline status indicator dot
        static let promptHistoryDrawerWidth: CGFloat = 360
        static let promptBrowserHistoryDrawerWidth: CGFloat = 320
        static let promptEditorIdealHeight: CGFloat = 320
    }
}

// MARK: Motion Tokens
extension PH {
    enum Motion {
        static let hover: Animation = .easeOut(duration: 0.18)
        static let hoverLift: CGFloat = 0
        static let hoverScale: CGFloat = 1
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
