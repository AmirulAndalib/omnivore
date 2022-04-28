import Combine
import Models
import Services
import SwiftUI
import UserNotifications
import Utils
import Views

#if os(iOS)
  struct HomeFeedContainerView: View {
    @EnvironmentObject var dataService: DataService
    @AppStorage(UserDefaultKey.homeFeedlayoutPreference.rawValue) var prefersListLayout = UIDevice.isIPhone
    @ObservedObject var viewModel: HomeFeedViewModel

    func loadItems(isRefresh: Bool) {
      Task { await viewModel.loadItems(dataService: dataService, isRefresh: isRefresh) }
    }

    var body: some View {
      Group {
        HomeFeedView(
          prefersListLayout: $prefersListLayout,
          viewModel: viewModel
        )
        .refreshable {
          loadItems(isRefresh: true)
        }
        .searchable(
          text: $viewModel.searchTerm,
          placement: .navigationBarDrawer
        ) {
          if viewModel.searchTerm.isEmpty {
            Text("Inbox").searchCompletion("in:inbox ")
            Text("All").searchCompletion("in:all ")
            Text("Archived").searchCompletion("in:archive ")
            Text("Files").searchCompletion("type:file ")
          }
        }
        .onChange(of: viewModel.searchTerm) { _ in
          // Maybe we should debounce this, but
          // it feels like it works ok without
          loadItems(isRefresh: true)
        }
        .onChange(of: viewModel.selectedLabels) { _ in
          loadItems(isRefresh: true)
        }
        .onSubmit(of: .search) {
          loadItems(isRefresh: true)
        }
        .sheet(item: $viewModel.itemUnderLabelEdit) { item in
          ApplyLabelsView(mode: .item(item)) { _ in }
        }
      }
      .navigationTitle("Home")
      .navigationBarTitleDisplayMode(.inline)
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        // Don't refresh the list if the user is currently reading an article
        if viewModel.selectedLinkItem == nil {
          loadItems(isRefresh: true)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PushJSONArticle"))) { notification in
        guard let jsonArticle = notification.userInfo?["article"] as? JSONArticle else { return }
        guard let objectID = dataService.persist(jsonArticle: jsonArticle) else { return }
        guard let linkedItem = dataService.viewContext.object(with: objectID) as? LinkedItem else { return }
        viewModel.pushFeedItem(item: linkedItem)
        viewModel.selectedLinkItem = linkedItem
      }
      .formSheet(isPresented: $viewModel.snoozePresented) {
        SnoozeView(snoozePresented: $viewModel.snoozePresented, itemToSnoozeID: $viewModel.itemToSnoozeID) {
          viewModel.snoozeUntil(
            dataService: dataService,
            linkId: $0.feedItemId,
            until: $0.snoozeUntilDate,
            successMessage: $0.successMessage
          )
        }
      }
      .onAppear { // TODO: use task instead
        if viewModel.items.isEmpty {
          loadItems(isRefresh: true)
        }
      }
    }
  }

  struct HomeFeedView: View {
    @EnvironmentObject var dataService: DataService
    @Binding var prefersListLayout: Bool
    @State private var showLabelsSheet = false
    @ObservedObject var viewModel: HomeFeedViewModel

    var body: some View {
      VStack(spacing: 0) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            TextChipButton.makeAddLabelButton {
              showLabelsSheet = true
            }
            ForEach(viewModel.selectedLabels, id: \.self) { label in
              TextChipButton.makeRemovableLabelButton(feedItemLabel: label) {
                viewModel.selectedLabels.removeAll { $0.id == label.id }
              }
            }
            Spacer()
          }
          .padding(.horizontal)
          .sheet(isPresented: $showLabelsSheet) {
            ApplyLabelsView(mode: .list(viewModel.selectedLabels)) { labels in
              viewModel.selectedLabels = labels
            }
          }
        }
        if prefersListLayout {
          HomeFeedListView(prefersListLayout: $prefersListLayout, viewModel: viewModel)
        } else {
          HomeFeedGridView(viewModel: viewModel)
            .toolbar {
              ToolbarItem {
                Button("", action: {})
                  .disabled(true)
                  .overlay {
                    if viewModel.isLoading {
                      ProgressView()
                    }
                  }
              }
              ToolbarItem {
                if UIDevice.isIPad {
                  Button(
                    action: { prefersListLayout.toggle() },
                    label: {
                      Label("Toggle Feed Layout", systemImage: prefersListLayout ? "square.grid.2x2" : "list.bullet")
                    }
                  )
                }
              }
            }
        }
      }
    }
  }

  struct HomeFeedListView: View {
    @EnvironmentObject var dataService: DataService
    @Binding var prefersListLayout: Bool

    @State private var itemToRemove: LinkedItem?
    @State private var confirmationShown = false

    @ObservedObject var viewModel: HomeFeedViewModel

    var body: some View {
      List {
        Section {
          ForEach(viewModel.items) { item in
            FeedCardNavigationLink(
              item: item,
              viewModel: viewModel
            )
            .contextMenu {
              Button(
                action: { viewModel.itemUnderLabelEdit = item },
                label: { Label("Edit Labels", systemImage: "tag") }
              )
              Button(action: {
                withAnimation(.linear(duration: 0.4)) {
                  viewModel.setLinkArchived(
                    dataService: dataService,
                    objectID: item.objectID,
                    archived: !item.isArchived
                  )
                }
              }, label: {
                Label(
                  item.isArchived ? "Unarchive" : "Archive",
                  systemImage: item.isArchived ? "tray.and.arrow.down.fill" : "archivebox"
                )
              })
              Button(
                action: {
                  itemToRemove = item
                  confirmationShown = true
                },
                label: { Label("Delete", systemImage: "trash") }
              )
              if FeatureFlag.enableSnooze {
                Button {
                  viewModel.itemToSnoozeID = item.id
                  viewModel.snoozePresented = true
                } label: {
                  Label { Text("Snooze") } icon: { Image.moon }
                }
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              if !item.isArchived {
                Button {
                  withAnimation(.linear(duration: 0.4)) {
                    viewModel.setLinkArchived(dataService: dataService, objectID: item.objectID, archived: true)
                  }
                } label: {
                  Label("Archive", systemImage: "archivebox")
                }.tint(.green)
              } else {
                Button {
                  withAnimation(.linear(duration: 0.4)) {
                    viewModel.setLinkArchived(dataService: dataService, objectID: item.objectID, archived: false)
                  }
                } label: {
                  Label("Unarchive", systemImage: "tray.and.arrow.down.fill")
                }.tint(.indigo)
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(
                role: .destructive,
                action: {
                  itemToRemove = item
                  confirmationShown = true
                },
                label: {
                  Image(systemName: "trash")
                }
              )
            }.alert("Are you sure?", isPresented: $confirmationShown) {
              Button("Remove Link", role: .destructive) {
                if let itemToRemove = itemToRemove {
                  withAnimation {
                    viewModel.removeLink(dataService: dataService, objectID: itemToRemove.objectID)
                  }
                }
                self.itemToRemove = nil
              }
              Button("Cancel", role: .cancel) { self.itemToRemove = nil }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
              if FeatureFlag.enableSnooze {
                Button {
                  viewModel.itemToSnoozeID = item.id
                  viewModel.snoozePresented = true
                } label: {
                  Label { Text("Snooze") } icon: { Image.moon }
                }.tint(.appYellow48)
              }
            }
          }
        }

        if viewModel.isLoading {
          LoadingSection()
        }
      }
      .listStyle(PlainListStyle())
      .toolbar {
        ToolbarItem {
          if UIDevice.isIPad {
            Button(
              action: { prefersListLayout.toggle() },
              label: {
                Label("Toggle Feed Layout", systemImage: prefersListLayout ? "square.grid.2x2" : "list.bullet")
              }
            )
          }
        }
      }
    }
  }

  struct HomeFeedGridView: View {
    @EnvironmentObject var dataService: DataService

    @State private var itemToRemove: LinkedItem?
    @State private var confirmationShown = false
    @State var isContextMenuOpen = false

    @ObservedObject var viewModel: HomeFeedViewModel

    func contextMenuActionHandler(item: LinkedItem, action: GridCardAction) {
      switch action {
      case .toggleArchiveStatus:
        viewModel.setLinkArchived(dataService: dataService, objectID: item.objectID, archived: !item.isArchived)
      case .delete:
        itemToRemove = item
        confirmationShown = true
      case .editLabels:
        viewModel.itemUnderLabelEdit = item
      }
    }

    func loadItems(isRefresh: Bool) {
      Task { await viewModel.loadItems(dataService: dataService, isRefresh: isRefresh) }
    }

    var body: some View {
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 325), spacing: 24)], spacing: 24) {
          ForEach(viewModel.items) { item in
            GridCardNavigationLink(
              item: item,
              actionHandler: { contextMenuActionHandler(item: item, action: $0) },
              isContextMenuOpen: $isContextMenuOpen,
              viewModel: viewModel
            )
            .alert("Are you sure?", isPresented: $confirmationShown) {
              Button("Remove Link", role: .destructive) {
                if let itemToRemove = itemToRemove {
                  withAnimation {
                    viewModel.removeLink(dataService: dataService, objectID: itemToRemove.objectID)
                  }
                }
                self.itemToRemove = nil
              }
              Button("Cancel", role: .cancel) { self.itemToRemove = nil }
            }
          }
        }
        .padding()
        .background(
          GeometryReader {
            Color(.systemGroupedBackground).preference(
              key: ScrollViewOffsetPreferenceKey.self,
              value: $0.frame(in: .global).origin.y
            )
          }
        )
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
          DispatchQueue.main.async {
            if !viewModel.isLoading, offset > 240 {
              loadItems(isRefresh: true)
            }
          }
        }

        if viewModel.items.isEmpty, viewModel.isLoading {
          LoadingSection()
        }
      }
    }
  }

#endif

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
  typealias Value = CGFloat
  static var defaultValue = CGFloat.zero
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value += nextValue()
  }
}
