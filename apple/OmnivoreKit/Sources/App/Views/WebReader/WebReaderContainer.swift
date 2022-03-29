import Combine
import Models
import Services
import SwiftUI
import Views
import WebKit

struct WebReaderContainerView: View {
  let item: FeedItem
  let homeFeedViewModel: HomeFeedViewModel

  @State private var showFontSizePopover = false
  @State var showHighlightAnnotationModal = false
  @State var safariWebLink: SafariWebLink?
  @State private var navBarVisibilityRatio = 1.0
  @State private var showDeleteConfirmation = false
  @State private var showOverlay = true
  @State var increaseFontActionID: UUID?
  @State var decreaseFontActionID: UUID?
  @State var annotationSaveTransactionID: UUID?
  @State var annotation = String()

  @EnvironmentObject var dataService: DataService
  @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
  @StateObject var viewModel = WebReaderViewModel()

  var fontAdjustmentPopoverView: some View {
    FontSizeAdjustmentPopoverView(
      increaseFontAction: { increaseFontActionID = UUID() },
      decreaseFontAction: { decreaseFontActionID = UUID() }
    )
  }

  func webViewActionHandler(message: WKScriptMessage, replyHandler: WKScriptMessageReplyHandler?) {
    if message.name == WebViewAction.readingProgressUpdate.rawValue {
      let messageBody = message.body as? [String: Double]

      if let messageBody = messageBody, let progress = messageBody["progress"] {
        homeFeedViewModel.updateProgress(itemID: item.id, progress: Double(progress))
      }
    }

    if let replyHandler = replyHandler {
      viewModel.webViewActionWithReplyHandler(
        message: message,
        replyHandler: replyHandler,
        dataService: dataService
      )
      return
    }

    if message.name == WebViewAction.highlightAction.rawValue {
      handleHighlightAction(message: message)
    }

    if message.name == WebViewAction.readingProgressUpdate.rawValue {
      guard let messageBody = message.body as? [String: Double] else { return }
      guard let progress = messageBody["progress"] else { return }
      homeFeedViewModel.updateProgress(itemID: item.id, progress: Double(progress))
    }
  }

  private func handleHighlightAction(message: WKScriptMessage) {
    guard let messageBody = message.body as? [String: String] else { return }
    guard let actionID = messageBody["actionID"] else { return }

    switch actionID {
    case "annotate":
      annotation = messageBody["annotation"] ?? ""
      showHighlightAnnotationModal = true
    default:
      break
    }
  }

  var navBariOS14: some View {
    HStack(alignment: .center) {
      Button(
        action: { self.presentationMode.wrappedValue.dismiss() },
        label: {
          Image(systemName: "chevron.backward")
            .font(.appTitleTwo)
            .foregroundColor(.appGrayTextContrast)
            .padding(.horizontal)
        }
      )
      .scaleEffect(navBarVisibilityRatio)
      Spacer()
      Button(
        action: { showFontSizePopover.toggle() },
        label: {
          Image(systemName: "textformat.size")
            .font(.appTitleTwo)
        }
      )
      .padding(.horizontal)
      .scaleEffect(navBarVisibilityRatio)
    }
    .frame(height: readerViewNavBarHeight * navBarVisibilityRatio)
    .opacity(navBarVisibilityRatio)
    .background(Color.systemBackground)
    .onTapGesture {
      showFontSizePopover = false
    }
  }

  @available(macOS 12.0, *)
  @available(iOS 15.0, *)
  var navBar: some View {
    HStack(alignment: .center) {
      Button(
        action: { self.presentationMode.wrappedValue.dismiss() },
        label: {
          Image(systemName: "chevron.backward")
            .font(.appTitleTwo)
            .foregroundColor(.appGrayTextContrast)
            .padding(.horizontal)
        }
      )
      .scaleEffect(navBarVisibilityRatio)
      Spacer()
      Button(
        action: { showFontSizePopover.toggle() },
        label: {
          Image(systemName: "textformat.size")
            .font(.appTitleTwo)
        }
      )
      .padding(.horizontal)
      .scaleEffect(navBarVisibilityRatio)
      Menu(
        content: {
          Group {
            Button(
              action: {
                homeFeedViewModel.setLinkArchived(
                  dataService: dataService,
                  linkId: item.id,
                  archived: !item.isArchived
                )
              },
              label: {
                Label(
                  item.isArchived ? "Unarchive" : "Archive",
                  systemImage: item.isArchived ? "tray.and.arrow.down.fill" : "archivebox"
                )
              }
            )
            Button(
              action: { showDeleteConfirmation = true },
              label: { Label("Delete", systemImage: "trash") }
            )
          }
        },
        label: {
          Image.profile
            .padding(.horizontal)
            .scaleEffect(navBarVisibilityRatio)
        }
      )
    }
    .frame(height: readerViewNavBarHeight * navBarVisibilityRatio)
    .opacity(navBarVisibilityRatio)
    .background(Color.systemBackground)
    .onTapGesture {
      showFontSizePopover = false
    }
    .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
      Button("Remove Link", role: .destructive) {
        homeFeedViewModel.removeLink(dataService: dataService, linkId: item.id)
      }
      Button("Cancel", role: .cancel, action: {})
    }
  }

  var body: some View {
    ZStack {
      if let articleContent = viewModel.articleContent {
        WebReader(
          articleContent: articleContent,
          item: item,
          openLinkAction: {
            #if os(macOS)
              NSWorkspace.shared.open($0)
            #elseif os(iOS)
              safariWebLink = SafariWebLink(id: UUID(), url: $0)
            #endif
          },
          webViewActionHandler: webViewActionHandler,
          navBarVisibilityRatioUpdater: {
            if $0 < 1 {
              showFontSizePopover = false
            }
            navBarVisibilityRatio = $0
          },
          increaseFontActionID: $increaseFontActionID,
          decreaseFontActionID: $decreaseFontActionID,
          annotationSaveTransactionID: $annotationSaveTransactionID,
          annotation: $annotation
        )
        .overlay(
          Group {
            if showOverlay {
              Color.systemBackground
                .transition(.opacity)
                .onAppear {
                  DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                    withAnimation(.linear(duration: 0.2)) {
                      showOverlay = false
                    }
                  }
                }
            }
          }
        )
        .sheet(item: $safariWebLink) {
          SafariView(url: $0.url)
        }
        .sheet(isPresented: $showHighlightAnnotationModal) {
          HighlightAnnotationSheet(
            annotation: $annotation,
            onSave: {
              annotationSaveTransactionID = UUID()
              showHighlightAnnotationModal = false
            },
            onCancel: {
              showHighlightAnnotationModal = false
            }
          )
        }
      } else {
        Color.clear
          .contentShape(Rectangle())
          .onAppear {
            if !viewModel.isLoading {
              viewModel.loadContent(dataService: dataService, slug: item.slug)
            }
          }
      }
      if showFontSizePopover {
        VStack {
          Color.clear
            .contentShape(Rectangle())
            .frame(height: LinkItemDetailView.navBarHeight)
          HStack {
            Spacer()
            fontAdjustmentPopoverView
              .background(Color.appButtonBackground)
              .cornerRadius(8)
              .padding(.trailing, 44)
          }
          Spacer()
        }
        .background(
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              showFontSizePopover = false
            }
        )
      }
      if #available(iOS 15.0, *) {
        VStack(spacing: 0) {
          navBar
          Spacer()
        }
        .navigationBarHidden(true)
      } else {
        VStack(spacing: 0) {
          navBariOS14
          Spacer()
        }
        .navigationBarHidden(true)
      }

    }.onDisappear {
      // Clear the shared webview content when exiting
      WebViewManager.shared().loadHTMLString("<html></html>", baseURL: nil)
    }
    .navigationBarHidden(true)
  }
}
