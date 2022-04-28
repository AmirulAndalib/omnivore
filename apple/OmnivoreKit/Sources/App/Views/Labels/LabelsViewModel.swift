import Models
import Services
import SwiftUI
import Views

@MainActor final class LabelsViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var selectedLabels = [LinkedItemLabel]()
  @Published var unselectedLabels = [LinkedItemLabel]()
  @Published var labels = [LinkedItemLabel]()
  @Published var showCreateEmailModal = false
  @Published var labelSearchFilter = ""

  func loadLabels(
    dataService: DataService,
    item: LinkedItem? = nil,
    initiallySelectedLabels: [LinkedItemLabel]? = nil
  ) async {
    isLoading = true

    if let labelIDs = try? await dataService.labels() {
      dataService.viewContext.performAndWait {
        self.labels = labelIDs.compactMap { dataService.viewContext.object(with: $0) as? LinkedItemLabel }
      }
      let selLabels = initiallySelectedLabels ?? item?.labels.asArray(of: LinkedItemLabel.self) ?? []
      for label in labels {
        if selLabels.contains(label) {
          selectedLabels.append(label)
        } else {
          unselectedLabels.append(label)
        }
      }
    }

    isLoading = false
  }

  func createLabel(dataService: DataService, name: String, color: Color, description: String?) {
    isLoading = true

    guard let labelObjectID = try? dataService.createLabel(
      name: name,
      color: color.hex ?? "",
      description: description
    ) else {
      return
    }

    if let label = dataService.viewContext.object(with: labelObjectID) as? LinkedItemLabel {
      labels.insert(label, at: 0)
      unselectedLabels.insert(label, at: 0)
    }

    showCreateEmailModal = false
  }

  func deleteLabel(dataService: DataService, labelID: String, name: String) {
    dataService.removeLabel(labelID: labelID, name: name)
    labels.removeAll { $0.name == name }
    selectedLabels.removeAll { $0.name == name }
    unselectedLabels.removeAll { $0.name == name }
  }

  func saveItemLabelChanges(itemID: String, dataService: DataService) {
    dataService.updateItemLabels(itemID: itemID, labelNames: selectedLabels.map(\.unwrappedName))
  }

  func addLabelToItem(_ label: LinkedItemLabel) {
    selectedLabels.insert(label, at: 0)
    unselectedLabels.removeAll { $0.name == label.name }
  }

  func removeLabelFromItem(_ label: LinkedItemLabel) {
    unselectedLabels.insert(label, at: 0)
    selectedLabels.removeAll { $0.name == label.name }
  }
}
