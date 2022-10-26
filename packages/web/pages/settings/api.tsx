import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/router'
import { Toaster } from 'react-hot-toast'

import { showErrorToast, showSuccessToast } from '../../lib/toastHelpers'
import { applyStoredTheme } from '../../lib/themeUpdater'
import { useGetApiKeysQuery } from '../../lib/networking/queries/useGetApiKeysQuery'
import { generateApiKeyMutation } from '../../lib/networking/mutations/generateApiKeyMutation'
import { revokeApiKeyMutation } from '../../lib/networking/mutations/revokeApiKeyMutation'

import { PrimaryLayout } from '../../components/templates/PrimaryLayout'
// import { Table } from '../../components/elements/Table'

import { FormInputProps } from '../../components/elements/FormElements'
import { FormModal } from '../../components/patterns/FormModal'
import { ConfirmationModal } from '../../components/patterns/ConfirmationModal'

import { Breadcrumb, Button, Space, Table } from 'antd'

import 'antd/dist/antd.dark.css'
// import 'antd/dist/antd.compact.css'

import { Box, HStack } from '../../components/elements/LayoutPrimitives'

interface ApiKey {
  name: string
  scopes: string
  expiresAt: string
  usedAt: string
}

export default function Api(): JSX.Element {
  const { apiKeys, revalidate } = useGetApiKeysQuery()
  const [onDeleteId, setOnDeleteId] = useState<string>('')
  const [addModalOpen, setAddModalOpen] = useState(false)
  const [name, setName] = useState<string>('')
  const [value, setValue] = useState<string>('')
  // const [scopes, setScopes] = useState<string[] | undefined>(undefined)
  const [expiresAt, setExpiresAt] = useState<Date>(new Date())
  const [formInputs, setFormInputs] = useState<FormInputProps[]>([])
  const [apiKeyGenerated, setApiKeyGenerated] = useState('')
  // default expiry date is 1 year from now
  const defaultExpiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365)
    .toISOString()
    .split('T')[0]
  const neverExpiresDate = new Date(8640000000000000)

  const router = useRouter()
  useEffect(() => {
    if (Object.keys(router.query).length) {
      setValue(`${router.query?.create}`)
      setExpiresAt(new Date(defaultExpiresAt))
      onAdd()
      setAddModalOpen(true)
    }
  }, [router.query])

  const headers = ['Name', 'Scopes', 'Used at', 'Expires on']

  const dataSource = useMemo(() => {
    return apiKeys.map((apiKey: any) => {
      console.log('key: ', apiKey)
      return {
        name: apiKey.name.length > 0 ? apiKey.name : 'Test Key',
        scopes: apiKey.scopes.join(', ') || 'All',
        usedAt: apiKey.usedAt
          ? new Date(apiKey.usedAt).toISOString()
          : 'Never used',
        expiresAt:
          new Date(apiKey.expiresAt).getTime() != neverExpiresDate.getTime()
          ? new Date(apiKey.expiresAt).toDateString()
          : 'Never',
      }
    })
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
        options: [
          'in 7 days',
          'in 30 days',
          'in 90 days',
          'in 1 year',
          'Never',
        ],
        value: defaultExpiresAt,
      },
    ])
  }

  // const dataSource = [
  //   {
  //     key: '1',
  //     name: 'Mike',
  //     expiresOn: Date(),
  //     usedAt: Date(),
  //   },
  //   {
  //     key: '2',
  //     name: 'John',
  //     usedAt: Date(),
  //     expiresOn: Date(),
  //   },
  // ];
  
  const columns = [
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
    },
    {
      title: 'Last Used',
      dataIndex: 'usedAt',
      key: 'usedAt',
    },
    {
      title: 'Expires On',
      dataIndex: 'expiresAt',
      key: 'expiresAt',
    },
    {
      title: 'Action',
      key: 'action',
      render: (_: any, record: any) => (
        <a>Delete</a>
      ),
    },
  ];
 
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

<Box css={{ pt: '44px', px: '10%', '@smDown': { px: '0' } }}>

    <Breadcrumb>
        <Breadcrumb.Item>Home</Breadcrumb.Item>
        <Breadcrumb.Item>
          <a href="">Settings</a>
        </Breadcrumb.Item>
        <Breadcrumb.Item>API Keys</Breadcrumb.Item>
      </Breadcrumb>

      <HStack css={{ py: '16px' }} distribution="end">
        <Button onClick={() => { setAddModalOpen(true) }} type="primary">
          Create a new API Key
        </Button>
      </HStack>

      <Table dataSource={dataSource} columns={columns} />
      </Box>
      {/* <Table
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
      /> */}
    </PrimaryLayout>
  )
}
