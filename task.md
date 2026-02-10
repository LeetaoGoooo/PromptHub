# Task: Skill Asset Management Platform

## Phase 0: Native Experience (Completed)
- [x] **Native UI Refactor** <!-- id: 0 -->
    - [x] Refactor `PromptSideBar` to use standard Library/Explore sections.
    - [x] Move search to native `.searchable` toolbar item.
    - [x] Remove nested tab navigation from `UnifiedPromptBrowserView`.
- [x] **Apple Design Polish** <!-- id: 8 -->
    - [x] Fix Sidebar Icons (`tray.full` for All, `person.2` for Shared).
    - [x] Move "New Prompt" to Toolbar (Primary Action, `Cmd+N`).
    - [x] Clean up Sidebar bottom bar.
- [x] **Mac Interaction Polish** <!-- id: 9 -->
    - [x] Remove Sheet preview from "My Prompts" Grid.
    - [x] Implement Master-Detail navigation (Click in grid -> Open Detail).
    - [x] Refactor `UserPromptItemView` (Remove offset animation/inline buttons).
- [x] **Tri-Pane UI Refactor** <!-- id: 10 -->
    - [x] Create `InspectorView` for Metadata & History.
    - [x] Refactor `PromptDetail` to use `HStack` layout (Editor + Inspector).
    - [x] Clean up `LatestVersionView` (Remove button soup).
- [x] **Direct Creation Flow** <!-- id: 11 -->
    - [x] Remove `NewPromptDialog` (Anti-Pattern).
    - [x] Implement "Untitled Document" logic (Cmd+N -> Create & Open).

## Phase 0.5: Regression Fixes (Completed) <!-- id: 12 -->
- [x] **Fix Renaming**
- [x] **Restore Settings**
- [x] **Restore Sharing**

## Phase 0.6: Progressive Mac Refactor (Completed) <!-- id: 13 -->
- [x] **Standardize Component Cards**
    - [x] Remove jumping hover animations (`.offset`, heavy `.shadow`).
    - [x] Standardize corner radius to 8-10pt.
    - [x] Remove "Button Soup" from Grid Items.
- [x] **Refine Library Views**
    - [x] Use `HSplitView` or standard List styles where appropriate.
    - [x] Clean up `PromptViewHelpers` to use semantic Mac colors.
- [x] **Legacy Cleanup**
    - [x] Remove/Archive `UnifiedPromptBrowserView.swift` if redundant.

## Phase 1: The "Skill Pack" - Foundation (Current Focus)
- [x] **Define Skill Object Model** <!-- id: 1 -->
- [x] **Schema-First Editor** <!-- id: 2 -->
    - [x] Implement `SKILL.md` (YAML + Markdown) Support
    - [x] Create `SkillEditorView` with Live Simulation
- [x] **skills.sh Integration**
    - [x] Create `SkillRegistryService` (API/Scraping)
    - [x] Build `SkillStoreView` (The "Skill Store")
- [ ] **Minimal Evals** <!-- id: 3 -->

## Phase 2: The "Rack" (MCP Connection)
- [ ] **MCP Instrument Rack** <!-- id: 4 -->
- [ ] **Context Profiles** <!-- id: 5 -->

## Phase 3: The "Simulation" (Optimization)
- [ ] **Live Simulation View** <!-- id: 6 -->
- [ ] **Optimizer** <!-- id: 7 -->
