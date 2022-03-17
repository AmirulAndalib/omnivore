import '../styles/globals.css'
import '../styles/articleInnerStyling.css'
import '../styles/sliderstyles.css'
import type { AppProps } from 'next/app'
import { IntlProvider } from 'react-intl'
import { IdProvider } from '@radix-ui/react-id'
import { englishTranslations } from './../locales/en/messages'
import { useRouter } from 'next/router'
import { useEffect, useState } from 'react'
import { Analytics, AnalyticsBrowser } from '@segment/analytics-next'
import { segmentApiKey } from '../lib/appConfig'
import { TooltipProvider } from '../components/elements/Tooltip'

function OmnivoreApp({ Component, pageProps }: AppProps): JSX.Element {
  const router = useRouter()
  const [analytics, setAnalytics] = useState<Analytics | undefined>(undefined)

  useEffect(() => {
    const loadAnalytics = async () => {
      const writeKey = segmentApiKey
      if (writeKey) {
        try {
          const [response] = await AnalyticsBrowser.load({ writeKey })
          window.analytics = response
          setAnalytics(response)
          analytics?.track('init_session')
        } catch (error) {
          console.log('error loading analytics', error)
        }
      }
    }
    loadAnalytics()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const handleRouteChange = (url: string) => {
      analytics?.page(url)
    }
    router.events.on('routeChangeComplete', handleRouteChange)
    return () => {
      router.events.off('routeChangeComplete', handleRouteChange)
    }
  }, [router.events, analytics])

  return (
    <IdProvider>
      <IntlProvider
        locale="en"
        defaultLocale="en"
        messages={englishTranslations}
      >
        <TooltipProvider delayDuration={200}>
          <Component {...pageProps} />
        </TooltipProvider>
      </IntlProvider>
    </IdProvider>
  )
}

export default OmnivoreApp
