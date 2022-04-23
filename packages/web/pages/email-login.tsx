import { PrimaryLayout } from '../components/templates/PrimaryLayout'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import { StyledText } from '../components/elements/StyledText'
import { fetchEndpoint } from '../lib/appConfig'
import { parseErrorCodes } from '../lib/queryParamParser'
import { formatMessage } from '../locales/en/messages'

export default function EmailLogin(): JSX.Element {
  const [errorMessage, setErrorMessage] = useState<string | undefined>(
    undefined
  )
  const [message, setMessage] = useState<string | undefined>(undefined)
  const router = useRouter()

  useEffect(() => {
    if (!router.isReady) return
    const errorCode = parseErrorCodes(router.query)
    const errorMsg = errorCode
      ? formatMessage({ id: `error.${errorCode}` })
      : undefined
    setErrorMessage(errorMsg)

    const message = router.query.message
      ? formatMessage({ id: `login.${router.query.message}` })
      : undefined
    setMessage(message)
  }, [router.isReady, router.query])

  return (
    <PrimaryLayout pageTestId="email-login">
      {message && <StyledText style={'headline'}>{message}</StyledText>}
      <h1>Email Login</h1>
      <form action={`${fetchEndpoint}/auth/email-login`} method="POST">
        <div>
          <label>Email</label>
          <input type="email" name={'email'} required />
        </div>
        <div>
          <label>Password</label>
          <input type="password" name={'password'} required />
        </div>
        {errorMessage && <StyledText style="error">{errorMessage}</StyledText>}
        <button type="submit">Login</button>
      </form>
    </PrimaryLayout>
  )
}
