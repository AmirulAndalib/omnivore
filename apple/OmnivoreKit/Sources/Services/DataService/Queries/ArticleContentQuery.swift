import Combine
import Foundation
import Models
import SwiftGraphQL

// swiftlint:disable:next function_body_length
public extension DataService {
  func articleContentPublisher(username: String, slug: String) -> AnyPublisher<ArticleContent, ServerError> {
    enum QueryResult {
      case success(result: ArticleContent)
      case error(error: String)
    }

    let articleSelection = Selection.Article {
      ArticleContent(
        htmlContent: try $0.content(),
        highlights: try $0.highlights(selection: highlightSelection.list)
      )
    }

    let selection = Selection<QueryResult, Unions.ArticleResult> {
      try $0.on(
        articleSuccess: .init {
          QueryResult.success(result: try $0.article(selection: articleSelection))
        },
        articleError: .init {
          QueryResult.error(error: try $0.errorCodes().description)
        }
      )
    }

    let query = Selection.Query {
      try $0.article(username: username, slug: slug, selection: selection)
    }

    let path = appEnvironment.graphqlPath
    let headers = networker.defaultHeaders

    return Deferred {
      Future { promise in
        send(query, to: path, headers: headers) { result in
          switch result {
          case let .success(payload):
            switch payload.data {
            case let .success(result: result):
              promise(.success(result))
            case .error:
              promise(.failure(.unknown))
            }
          case .failure:
            promise(.failure(.unknown))
          }
        }
      }
    }
    .receive(on: DispatchQueue.main)
    .eraseToAnyPublisher()
  }
}
