import React from 'react'
import ReactDOM from 'react-dom'
import { Box, VStack } from '@omnivore/web/components/elements/LayoutPrimitives'
import { ArticleContainer } from '@omnivore/web/components/templates/article/ArticleContainer'
import { applyStoredTheme } from '@omnivore/web/lib/themeUpdater'
import '@omnivore/web/styles/globals.css'
import '@omnivore/web/styles/articleInnerStyling.css'

const mutation = async (name, input) => {
  const result = await window?.webkit?.messageHandlers.articleAction?.postMessage({
    actionID: name,
    ...input
  })
  console.log('action result', result, result.result)
  return result.result
}

const App = () => {
  applyStoredTheme(false)

  return (
    <>
      <Box
        css={{
          overflowY: 'auto',
          height: '100%',
          width: '100vw',
        }}
      >
        <VStack
          alignment="center"
          distribution="center"
          className="disable-webkit-callout"
        >
          <ArticleContainer
            article={window.omnivoreArticle}
            scrollElementRef={React.createRef()}
            isAppleAppEmbed={true}
            highlightBarDisabled={true}
            highlightsBaseURL="https://example.com"
            fontSize={window.fontSize ?? 18}
            margin={0}
            articleMutations={{
              createHighlightMutation: (input) => mutation('createHighlight', input),
              deleteHighlightMutation: (highlightId) => mutation('deleteHighlight', { highlightId }),
              mergeHighlightMutation: (input) => mutation('mergeHighlight', input),
              updateHighlightMutation: (input) => mutation('updateHighlight', input),
              articleReadingProgressMutation: (input) => mutation('articleReadingProgress', input),
            }}
          />
        </VStack>
      </Box>
    </>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
