import { styled } from '@stitches/react'
import { VStack, HStack } from '../../elements/LayoutPrimitives'
import { StyledMark, StyledText } from '../../elements/StyledText'
import { LinkedItemCardAction, LinkedItemCardProps } from './CardTypes'

export interface HighlightItemCardProps
  extends Pick<LinkedItemCardProps, 'item'> {
  handleAction: (action: LinkedItemCardAction) => void
}

export const PreviewImage = styled('img', {
  objectFit: 'cover',
  cursor: 'pointer',
})

export function HighlightItemCard(props: HighlightItemCardProps): JSX.Element {
  return (
    <VStack
      css={{
        p: '$2',
        maxWidth: '498px',
        borderRadius: '6px',
        cursor: 'pointer',
        wordBreak: 'break-word',
        overflow: 'clip',
        border: '1px solid $grayBorder',
        boxShadow: '0px 3px 11px rgba(32, 31, 29, 0.04)',
        bg: '$grayBg',
        '&:focus': {
          bg: '$grayBgActive',
        },
        '&:hover': {
          bg: '$grayBgActive',
        },
      }}
      alignment="start"
      distribution="start"
      onClick={() => {
        props.handleAction('showDetail')
      }}
    >
      <StyledText
        css={{
          lineHeight: '20px',
        }}
      >
        <StyledMark
          css={{
            background: '$highlightBackground',
            color: '$highlightText',
          }}
        >
          {props.item.description}
        </StyledMark>
      </StyledText>
      <HStack
        css={{
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        {props.item.image && (
          <PreviewImage
            src={props.item.image}
            alt="Preview Image"
            width={16}
            height={16}
            css={{ borderRadius: '50%' }}
            onError={(e) => {
              ;(e.target as HTMLElement).style.display = 'none'
            }}
          />
        )}
        <StyledText
          css={{
            marginLeft: '$2',
            fontWeight: '700',
          }}
        >
          {props.item.title
            .substring(0, 50)
            .concat(props.item.title.length > 50 ? '...' : '')}
        </StyledText>
      </HStack>
    </VStack>
  )
}
