import SwiftUI

/// Tab bar containing all open tabs
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager

    @State private var draggedTabId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: tabManager.activeTabId == tab.id,
                            onSelect: {
                                tabManager.selectTab(id: tab.id)
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            }
                        )
                        .id(tab.id)
                        .onDrag {
                            draggedTabId = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            tabId: tab.id,
                            draggedTabId: $draggedTabId,
                            tabManager: tabManager
                        ))
                    }

                    // New tab button
                    Button(action: {
                        tabManager.createNewTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "new.tab"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: tabManager.activeTabId) { newValue in
                if let id = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .closeOtherTabs)) { notification in
            if let tabId = notification.object as? UUID {
                tabManager.closeOtherTabs(except: tabId)
            }
        }
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tabId: UUID
    @Binding var draggedTabId: UUID?
    let tabManager: TabManager

    func performDrop(info: DropInfo) -> Bool {
        draggedTabId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTabId,
              draggedId != tabId,
              let fromIndex = tabManager.tabs.firstIndex(where: { $0.id == draggedId }),
              let toIndex = tabManager.tabs.firstIndex(where: { $0.id == tabId }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tabManager.moveTab(from: fromIndex, to: toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    let tabManager = TabManager()
    tabManager.createNewTab()
    tabManager.createNewTab()

    return TabBarView(tabManager: tabManager)
}
