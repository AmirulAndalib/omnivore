import CoreData
import Foundation
import Models

struct InternalLinkedItemLabel {
  let id: String
  let name: String
  let color: String
  let createdAt: Date?
  let labelDescription: String?

  func persist(context: NSManagedObjectContext) -> NSManagedObjectID? {
    var objectID: NSManagedObjectID?

    context.performAndWait {
      let label = asManagedObject(inContext: context)

      do {
        try context.save()
        logger.debug("LinkedItemLabel saved succesfully")
        objectID = label.objectID
      } catch {
        context.rollback()
        logger.debug("Failed to save LinkedItemLabel: \(error.localizedDescription)")
      }
    }

    return objectID
  }

  func asManagedObject(inContext context: NSManagedObjectContext) -> LinkedItemLabel {
    let existingItem = LinkedItemLabel.lookup(byName: name, inContext: context)
    let label = existingItem ?? LinkedItemLabel(entity: LinkedItemLabel.entity(), insertInto: context)
    label.id = id
    label.name = name
    label.color = color
    label.createdAt = createdAt
    label.labelDescription = labelDescription
    return label
  }
}

extension LinkedItemLabel {
  public var unwrappedID: String { id ?? "" }
  public var unwrappedName: String { name ?? "" }

  static func lookup(byName name: String, inContext context: NSManagedObjectContext) -> LinkedItemLabel? {
    let fetchRequest: NSFetchRequest<Models.LinkedItemLabel> = LinkedItemLabel.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@", #keyPath(LinkedItemLabel.name), name
    )

    var label: LinkedItemLabel?

    context.performAndWait {
      label = (try? context.fetch(fetchRequest))?.first
    }

    return label
  }

  func update(
    inContext context: NSManagedObjectContext,
    newName: String? = nil,
    newColor: String? = nil,
    newLabelDescription: String? = nil
  ) {
    context.perform {
      if let newName = newName {
        self.name = newName
      }

      if let newColor = newColor {
        self.color = newColor
      }

      if let newLabelDescription = newLabelDescription {
        self.labelDescription = newLabelDescription
      }

      guard context.hasChanges else { return }

      do {
        try context.save()
        logger.debug("LinkedItemLabel updated succesfully")
      } catch {
        context.rollback()
        logger.debug("Failed to update LinkedItemLabel: \(error.localizedDescription)")
      }
    }
  }

  func remove(inContext context: NSManagedObjectContext) {
    context.perform {
      context.delete(self)

      do {
        try context.save()
        logger.debug("LinkedItemLabel removed")
      } catch {
        context.rollback()
        logger.debug("Failed to remove LinkedItemLabel: \(error.localizedDescription)")
      }
    }
  }
}

extension Sequence where Element == InternalLinkedItemLabel {
  func persist(context: NSManagedObjectContext) -> [NSManagedObjectID]? {
    var result: [NSManagedObjectID]?

    context.performAndWait {
      let labels = map { $0.asManagedObject(inContext: context) }
      do {
        try context.save()
        logger.debug("labels saved succesfully")
        result = labels.map(\.objectID)
      } catch {
        context.rollback()
        logger.debug("Failed to save labels: \(error.localizedDescription)")
      }
    }

    return result
  }
}
