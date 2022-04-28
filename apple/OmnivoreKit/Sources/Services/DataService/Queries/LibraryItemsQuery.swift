import CoreData
import Foundation
import Models
import SwiftGraphQL

public extension DataService {
  func fetchLinkedItems(
    limit: Int,
    searchQuery: String?,
    cursor: String?
  ) async throws -> HomeFeedData {
    // Send offline changes to server before fetching items
    try? await syncOfflineItemsWithServerIfNeeded()

    struct InternalHomeFeedData {
      let items: [InternalLinkedItem]
      let cursor: String?
    }

    enum QueryResult {
      case success(result: InternalHomeFeedData)
      case error(error: String)
    }

    let selection = Selection<QueryResult, Unions.ArticlesResult> {
      try $0.on(
        articlesSuccess: .init {
          QueryResult.success(
            result: InternalHomeFeedData(
              items: try $0.edges(selection: articleEdgeSelection.list),
              cursor: try $0.pageInfo(selection: Selection.PageInfo {
                try $0.endCursor()
              })
            )
          )
        },
        articlesError: .init {
          QueryResult.error(error: try $0.errorCodes().description)
        }
      )
    }

    let query = Selection.Query {
      try $0.articles(
        sharedOnly: .present(false),
        sort: OptionalArgument(
          InputObjects.SortParams(
            order: .present(.descending),
            by: .updatedTime
          )
        ),
        after: OptionalArgument(cursor),
        first: OptionalArgument(limit),
        query: OptionalArgument(searchQuery),
        selection: selection
      )
    }

    let path = appEnvironment.graphqlPath
    let headers = networker.defaultHeaders

    return try await withCheckedThrowingContinuation { continuation in
      send(query, to: path, headers: headers) { [weak self] queryResult in
        guard let payload = try? queryResult.get() else {
          continuation.resume(throwing: BasicError.message(messageText: "network error"))
          return
        }

        switch payload.data {
        case let .success(result: result):
          if let context = self?.backgroundContext, let items = result.items.persist(context: context) {
            continuation.resume(returning: HomeFeedData(items: items.map(\.objectID), cursor: result.cursor))
          } else {
            continuation.resume(throwing: BasicError.message(messageText: "CoreData error"))
          }
        case .error:
          continuation.resume(throwing: BasicError.message(messageText: "LinkedItem fetch error"))
        }
      }
    }
  }
}

private let articleSelection = Selection.Article {
  InternalLinkedItem(
    id: try $0.id(),
    title: try $0.title(),
    createdAt: try $0.createdAt().value ?? Date(),
    savedAt: try $0.savedAt().value ?? Date(),
    readingProgress: try $0.readingProgressPercent(),
    readingProgressAnchor: try $0.readingProgressAnchorIndex(),
    imageURLString: try $0.image(),
    onDeviceImageURLString: nil,
    documentDirectoryPath: nil,
    pageURLString: try $0.url(),
    descriptionText: try $0.description(),
    publisherURLString: try $0.originalArticleUrl(),
    author: try $0.author(),
    publishDate: try $0.publishedAt()?.value,
    slug: try $0.slug(),
    isArchived: try $0.isArchived(),
    contentReader: try $0.contentReader().rawValue,
    labels: try $0.labels(selection: feedItemLabelSelection.list.nullable) ?? []
  )
}

private let articleEdgeSelection = Selection.ArticleEdge {
  try $0.node(selection: articleSelection)
}
