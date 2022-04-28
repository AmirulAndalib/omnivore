import Foundation
import Models
import Utils

struct WebReaderContent {
  let textFontSize: Int
  let htmlContent: String
  let highlightsJSONString: String
  let item: LinkedItem
  let themeKey: String

  init(
    htmlContent: String,
    highlightsJSONString: String,
    item: LinkedItem,
    isDark: Bool,
    fontSize: Int
  ) {
    self.textFontSize = fontSize
    self.htmlContent = htmlContent
    self.highlightsJSONString = highlightsJSONString
    self.item = item
    self.themeKey = isDark ? "Gray" : "LightGray"
  }

  // swiftlint:disable line_length
  var styledContent: String {
    let savedAt = "new Date(\(item.unwrappedSavedAt.timeIntervalSince1970 * 1000)).toISOString()"
    let createdAt = "new Date(\(item.unwrappedCreatedAt.timeIntervalSince1970 * 1000)).toISOString()"
    let publishedAt = item.publishDate != nil ? "new Date(\(item.publishDate!.timeIntervalSince1970 * 1000)).toISOString()" : "undefined"

    return """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no' />
          <style>
            @import url("highlight\(themeKey == "Gray" ? "-dark" : "").css");
          </style>
      </head>
      <body>
        <div id="root" />
        <div id='_omnivore-htmlContent' style="display: none;">
          \(htmlContent)
        </div>
        <script type="text/javascript">
          window.omnivoreEnv = {
            "NEXT_PUBLIC_APP_ENV": "prod",
            "NEXT_PUBLIC_BASE_URL": "unset",
            "NEXT_PUBLIC_SERVER_BASE_URL": "unset",
            "NEXT_PUBLIC_HIGHLIGHTS_BASE_URL": "unset"
          }

          window.omnivoreArticle = {
            id: "\(item.unwrappedID)",
            linkId: "\(item.unwrappedID)",
            slug: "\(item.unwrappedSlug)",
            createdAt: \(createdAt),
            savedAt: \(savedAt),
            publishedAt: \(publishedAt),
            url: `\(item.unwrappedPageURLString)`,
            title: `\(item.unwrappedTitle.replacingOccurrences(of: "`", with: "\\`"))`,
            content: document.getElementById('_omnivore-htmlContent').innerHTML,
            originalArticleUrl: "\(item.unwrappedPageURLString)",
            contentReader: "WEB",
            readingProgressPercent: \(item.readingProgress),
            readingProgressAnchorIndex: \(item.readingProgressAnchor),
            highlights: \(highlightsJSONString),
          }

          window.fontSize = \(textFontSize)
          window.localStorage.setItem("theme", "\(themeKey)")
        </script>
        <script src="bundle.js"></script>
        <script src="mathJaxConfiguration.js" id="MathJax-script"></script>
        <script src="mathjax.js" id="MathJax-script"></script>
      </body>
    </html>
    """
  }
}
