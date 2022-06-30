import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/router'
import { Toaster } from 'react-hot-toast'

import { showErrorToast, showSuccessToast } from '../../lib/toastHelpers'
import { applyStoredTheme } from '../../lib/themeUpdater'
import { useGetApiKeysQuery } from '../../lib/networking/queries/useGetApiKeysQuery'
import { generateApiKeyMutation } from '../../lib/networking/mutations/generateApiKeyMutation'
import { revokeApiKeyMutation } from '../../lib/networking/mutations/revokeApiKeyMutation'

import { PrimaryLayout } from '../../components/templates/PrimaryLayout'
import { Table } from '../../components/elements/Table'
import { FormInputProps } from '../../components/elements/FormElements'
import { FormModal } from '../../components/patterns/FormModal'
import { ConfirmationModal } from '../../components/patterns/ConfirmationModal'

interface ApiKey {
  name: string
  scopes: string
  expiresAt: string
  usedAt: string
}

export default function Api(): JSX.Element {
  const router = useRouter()

  const { apiKeys, revalidate } = useGetApiKeysQuery()
  const [onDeleteId, setOnDeleteId] = useState<string>('')
  const [addModalOpen, setAddModalOpen] = useState(false)
  const [name, setName] = useState<string>('')
  const [value, setValue] = useState<string>('')
  const [expiresAt, setExpiresAt] = useState<Date>(new Date())
  const [formInputs, setFormInputs] = useState<FormInputProps[]>([])
  const [apiKeyGenerated, setApiKeyGenerated] = useState('')
  const [dropdownValue, setDropdownValue] = useState<string>('30 days')
  const dropdownMap = new Map([
    ['7', 'in 7 days'],
    ['30', 'in 30 days'],
    ['90', 'in 90 days'],
    ['365', 'in 1 year'],
    ['never', 'Never'],
  ])
  // default expiry date is 1 year from now
  const defaultExpiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365)
    .toISOString()
    .split('T')[0]
  const neverExpiresDate = new Date(8640000000000000)

  useEffect(() => {
    if (Object.keys(router.query).length) {
      setValue(`${router.query?.create}`)
      setDropdownValue(`${dropdownMap.get(`${router.query?.expire}`)}`)
      setExpiresAt(new Date(defaultExpiresAt))
      onAdd()
      setAddModalOpen(true)
    }
  }, [router.query])

  const headers = ['Name', 'Scopes', 'Used at', 'Expires on']
  const rows = useMemo(() => {
    const rows = new Map<string, ApiKey>()
    apiKeys.forEach((apiKey) =>
      rows.set(apiKey.id, {
        name: apiKey.name,
        scopes: apiKey.scopes.join(', ') || 'All',
        usedAt: apiKey.usedAt
          ? new Date(apiKey.usedAt).toISOString()
          : 'Never used',
        expiresAt:
          new Date(apiKey.expiresAt).getTime() != neverExpiresDate.getTime()
            ? new Date(apiKey.expiresAt).toDateString()
            : 'Never',
      })
    )
    return rows
  }, [apiKeys])

  applyStoredTheme(false)

  async function onDelete(id: string): Promise<void> {
    const result = await revokeApiKeyMutation(id)
    if (result) {
      showSuccessToast('API Key deleted', { position: 'bottom-right' })
    } else {
      showErrorToast('Failed to delete', { position: 'bottom-right' })
    }
    revalidate()
  }

  async function onCreate(): Promise<void> {
    const result = await generateApiKeyMutation({ name, expiresAt })
    if (result) {
      setApiKeyGenerated(result)
      showSuccessToast('API key generated', { position: 'bottom-right' })
    } else {
      showErrorToast('Failed to add', { position: 'bottom-right' })
    }
    revalidate()
  }

  function onAdd() {
    return setFormInputs([
      {
        label: 'Name',
        onChange: setName,
        name: 'name',
        value: `${router.query?.create ? router.query?.create : value}`,
        required: true,
      },
      {
        label: 'Expires',
        name: 'expiredAt',
        required: true,
        onChange: (e) => {
          let additionalDays = 0
          switch (e.target.value) {
            case 'in 7 days':
              additionalDays = 7
              break
            case 'in 30 days':
              additionalDays = 30
              break
            case 'in 90 days':
              additionalDays = 90
              break
            case 'in 1 year':
              additionalDays = 365
              break
            case 'Never':
              break
          }
          const newExpires = additionalDays ? new Date() : neverExpiresDate
          if (additionalDays) {
            newExpires.setDate(newExpires.getDate() + additionalDays)
          }
          setExpiresAt(newExpires)
        },
        type: 'select',
        options: [...Array.from(dropdownMap.values())],
        value: `${
          router.query?.expire
            ? dropdownMap.get(`${router.query.expire}`)
            : dropdownValue
        }`,
      },
    ])
  }
  return (
    <PrimaryLayout pageTestId={'api-keys'}>
      <Toaster
        containerStyle={{
          top: '5rem',
        }}
      />

      {addModalOpen && (
        <FormModal
          title={'Generate API Key'}
          onSubmit={onCreate}
          onOpenChange={setAddModalOpen}
          inputs={formInputs}
          acceptButtonLabel={'Generate'}
        />
      )}

      {apiKeyGenerated && (
        <ConfirmationModal
          message={`API key generated. Copy the key and use it in your application.
                    You won’t be able to see it again!
                    Key: ${apiKeyGenerated}`}
          acceptButtonLabel={'Copy'}
          onAccept={async () => {
            await navigator.clipboard.writeText(apiKeyGenerated)
            setApiKeyGenerated('')
          }}
          onOpenChange={() => setApiKeyGenerated('')}
        />
      )}

      {onDeleteId && (
        <ConfirmationModal
          message={'API key would be revoked. This action cannot be undone.'}
          onAccept={async () => {
            await onDelete(onDeleteId)
            setOnDeleteId('')
          }}
          onOpenChange={() => setOnDeleteId('')}
        />
      )}

      <Table
        heading={'API Keys'}
        headers={headers}
        rows={rows}
        onDelete={setOnDeleteId}
        onAdd={() => {
          onAdd()
          setName('')
          setExpiresAt(new Date(defaultExpiresAt))
          setAddModalOpen(true)
        }}
      />
    </PrimaryLayout>
  )
}
