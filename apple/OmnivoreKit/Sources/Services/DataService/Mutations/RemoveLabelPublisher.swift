import Combine
import Foundation
import Models
import SwiftGraphQL

extension DataService {
  public func removeLabel(labelID: String, name: String) {
    // Update CoreData
    backgroundContext.perform { [weak self] in
      guard let self = self else { return }
      guard let label = LinkedItemLabel.lookup(byName: name, inContext: self.backgroundContext) else { return }
      label.remove(inContext: self.backgroundContext)

      // Send update to server
      self.syncLabelDeletion(labelID: labelID, labelName: name)
    }
  }

  func syncLabelDeletion(labelID: String, labelName: String) {
    enum MutationResult {
      case success(labelID: String)
      case error(errorCode: Enums.DeleteLabelErrorCode)
    }

    let selection = Selection<MutationResult, Unions.DeleteLabelResult> {
      try $0.on(
        deleteLabelSuccess: .init {
          .success(labelID: try $0.label(selection: Selection.Label { try $0.id() }))
        },
        deleteLabelError: .init { .error(errorCode: try $0.errorCodes().first ?? .badRequest) }
      )
    }

    let mutation = Selection.Mutation {
      try $0.deleteLabel(id: labelID, selection: selection)
    }

    let path = appEnvironment.graphqlPath
    let headers = networker.defaultHeaders
    let context = backgroundContext

    send(mutation, to: path, headers: headers) { result in
      let data = try? result.get()
      let isSyncSuccess = data != nil

      context.perform {
        let label = LinkedItemLabel.lookup(byName: labelName, inContext: context)
        guard let label = label else { return }

        if isSyncSuccess {
          label.remove(inContext: context)
        } else {
          label.serverSyncStatus = Int64(ServerSyncStatus.needsDeletion.rawValue)
        }

        do {
          try context.save()
          logger.debug("LinkedItem deleted succesfully")
        } catch {
          context.rollback()
          logger.debug("Failed to delete LinkedItem: \(error.localizedDescription)")
        }
      }
    }
  }
}
